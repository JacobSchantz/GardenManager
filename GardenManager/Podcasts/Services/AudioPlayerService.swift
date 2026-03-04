import Foundation
import UIKit
import AVFoundation
import Combine
import MediaPlayer

// Notification for when an episode is marked as played
extension Notification.Name {
    static let episodeMarkedAsPlayed = Notification.Name("episodeMarkedAsPlayed")
}

class AudioPlayerService: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentEpisode: Episode?
    
    // Threshold: if within 2 minutes of end, mark as played
    private let playedThreshold: TimeInterval = 120
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var seekWorkItem: DispatchWorkItem?
    private var isSeeking = false
    private var isAudioSessionConfigured = false
    private var lastSavedTime: TimeInterval = 0
    private var wasPlayingBeforeBackground = false
    private var isInBackground = false
    private var cancellables = Set<AnyCancellable>()
    
    private let legacyPlaybackPositionsKey = "PlaybackPositions"
    private let lastPlayedEpisodeIDKey = "LastPlayedEpisodeID"
    private let playbackPositionsFileName = "playback_positions.json"
    private let maxStoredPlaybackPositions = 2000
    private var playbackPodcasts: [Podcast] = []
    private var playbackPositions: [String: TimeInterval] = [:]
    private var playedStatusByEpisodeID: [UUID: Bool] = [:]
    
    override init() {
        super.init()
        loadPlaybackPositionsFromDisk()
        setupRemoteCommandCenter()
        setupInterruptionHandling()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(savePositionOnBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    
    private func configureAudioSession() {
        guard !isAudioSessionConfigured else { return }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio)
            isAudioSessionConfigured = true
            print("[AudioPlayerService] Audio session configured for background playback")
        } catch {
            print("[AudioPlayerService] Failed to configure audio session: \(error)")
        }
    }
    
    private func activateAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true, options: [])
            print("[AudioPlayerService] Audio session activated")
        } catch {
            print("[AudioPlayerService] Failed to activate audio session: \(error)")
        }
    }
    
    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("[AudioPlayerService] Audio interruption began")
            pause(reason: "interruption_began")
        case .ended:
            print("[AudioPlayerService] Audio interruption ended")
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                activateAudioSession()
                if let episode = currentEpisode {
                    play(episode: episode)
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            print("[AudioPlayerService] Audio route changed - old device unavailable, pausing")
            pause(reason: "route_change_old_device_unavailable")
        default:
            break
        }
    }
    
    func play(episode: Episode, restoredFromPosition: TimeInterval? = nil) {
        print("[AudioPlayerService] play() called for: \(episode.title), URL: \(episode.localFileURL ?? episode.audioURL)")
        configureAudioSession()
        activateAudioSession()
        
        saveLastPlayedEpisodeID(episode.id)
        
        let isNewEpisode = currentEpisode?.id != episode.id || player == nil
        
        if isNewEpisode {
            seekWorkItem?.cancel()
            seekWorkItem = nil
            isSeeking = false
            lastSavedTime = 0

            if let timeObserver = timeObserver {
                player?.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }

            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: nil
            )

            // Save position of previous episode before switching
            if let prevEpisode = currentEpisode {
                savePlaybackPosition(for: prevEpisode.id)
                syncPlayedStatus(for: prevEpisode, progress: currentTime, duration: duration)
            }
            
            currentTime = 0
            duration = 0
            currentEpisode = episode
            let audioURL = episode.localFileURL ?? episode.audioURL
            print("[AudioPlayerService] Creating player with URL: \(audioURL)")
            let playerItem = AVPlayerItem(url: audioURL)
            player = AVPlayer(playerItem: playerItem)
            player?.automaticallyWaitsToMinimizeStalling = true
            
            // Observe when player item is ready
            playerItem.publisher(for: \.status)
                .sink { [weak self] status in
                    print("[AudioPlayerService] PlayerItem status: \(status.rawValue)")
                    if status == .readyToPlay {
                        print("[AudioPlayerService] PlayerItem ready to play")
                    } else if status == .failed {
                        print("[AudioPlayerService] PlayerItem failed: \(playerItem.error?.localizedDescription ?? "unknown")")
                    }
                }
                .store(in: &cancellables)
            
            setupTimeObserver()
            setupNowPlaying(episode: episode)
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem
            )
            
            // Restore saved position - either from parameter or from storage
            let savedPosition = restoredFromPosition ?? getPlaybackPosition(for: episode.id)
            let resumePosition = resumePositionIfUnplayed(savedPosition, for: episode)
            if resumePosition > 0 {
                let cmTime = CMTime(seconds: resumePosition, preferredTimescale: 600)
                player?.seek(to: cmTime)
                currentTime = resumePosition
                print("[AudioPlayerService] Restored position: \(resumePosition)s")
            }
        }
        
        print("[AudioPlayerService] Calling player.play(), isPlaying will be set to true")
        player?.play()
        isPlaying = true
        updateNowPlayingPlaybackState()
        print("[AudioPlayerService] Playing: \(episode.title), player rate: \(player?.rate ?? 0)")
    }
    
    func resume() {
        activateAudioSession()
        player?.play()
        isPlaying = true
        updateNowPlayingPlaybackState()
    }
    
    func pause(reason: String = "manual") {
        // Allow remote commands to pause in background
        let allowedBackgroundPauses = ["interruption_began", "route_change_old_device_unavailable", "remote_command", "togglePlayPause"]
        if isInBackground && reason != "manual" && !allowedBackgroundPauses.contains(reason) {
            print("[AudioPlayerService] Skipping pause in background - reason: \(reason)")
            return
        }
        
        print("[AudioPlayerService] pause() called - reason: \(reason), isPlaying: \(isPlaying), currentTime: \(currentTime)")
        player?.pause()
        isPlaying = false
        updateNowPlayingPlaybackState()
        
        // Save playback position when pausing
        if let episode = currentEpisode {
            savePlaybackPosition(for: episode.id)
            saveLastPlayedEpisodeID(episode.id)
            syncPlayedStatus(for: episode)
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause(reason: "togglePlayPause")
        } else if let episode = currentEpisode {
            play(episode: episode)
        }
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
        updateNowPlayingElapsedTime()
    }
    
    func updateSeekPosition(_ time: TimeInterval) {
        currentTime = time
    }
    
    func debouncedSeek(to time: TimeInterval) {
        seekWorkItem?.cancel()
        
        currentTime = time
        isSeeking = true
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            self.player?.seek(to: cmTime) { _ in
                DispatchQueue.main.async {
                    self.isSeeking = false
                    self.updateNowPlayingElapsedTime()
                }
            }
        }
        
        seekWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    func skipForward(_ seconds: TimeInterval = 15) {
        guard let player = player else { return }
        let newTime = player.currentTime().seconds + seconds
        seek(to: min(newTime, duration))
    }
    
    func skipBackward(_ seconds: TimeInterval = 15) {
        guard let player = player else { return }
        let newTime = player.currentTime().seconds - seconds
        seek(to: max(newTime, 0))
    }

    func updatePlaybackPodcasts(_ podcasts: [Podcast]) {
        playbackPodcasts = podcasts
        prunePlaybackPositionsToKnownEpisodes()
        syncPlayedStatusesForKnownEpisodes()
    }

    private func syncPlayedStatusesForKnownEpisodes() {
        for episode in playbackPodcasts.flatMap(\.episodes) {
            let isPlayed = playedStatus(for: episode)
            postPlayedStatusIfChanged(episodeID: episode.id, isPlayed: isPlayed)
        }
    }
    
    private func setupTimeObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            if !self.isSeeking {
                self.currentTime = time.seconds
            }
            if let duration = self.player?.currentItem?.duration.seconds, !duration.isNaN {
                self.duration = duration
            }
            if !self.isSeeking {
                self.updateNowPlayingElapsedTime()
            }

            if let episode = self.currentEpisode {
                self.syncPlayedStatus(for: episode)
            }
            
            // Save position every 10 seconds during playback
            if let episode = self.currentEpisode,
               abs(time.seconds - self.lastSavedTime) >= 10 {
                self.savePlaybackPosition(for: episode.id)
                self.lastSavedTime = time.seconds
            }
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        guard let finishedEpisode = currentEpisode else {
            isPlaying = false
            updateNowPlayingPlaybackState()
            return
        }

        // Persist near-end progress so played state is derived from progress.
        let finishedDuration = player?.currentItem?.duration.seconds ?? duration
        if finishedDuration.isFinite && finishedDuration > 0 {
            duration = finishedDuration
            currentTime = finishedDuration
        }
        savePlaybackPosition(for: finishedEpisode.id)
        syncPlayedStatus(for: finishedEpisode)

        if playNextUnplayedDownloadedEpisode(after: finishedEpisode) {
            return
        }

        isPlaying = false
        currentTime = 0
        player?.seek(to: .zero)
        updateNowPlayingPlaybackState()
    }
    
    private func resumePositionIfUnplayed(_ progress: TimeInterval, for episode: Episode) -> TimeInterval {
        guard progress > 0 else {
            return 0
        }
        return isProgressPlayed(progress, duration: episode.duration) ? 0 : progress
    }

    private func isProgressPlayed(_ progress: TimeInterval, duration: TimeInterval) -> Bool {
        guard progress.isFinite, duration.isFinite, duration > 0 else {
            return false
        }
        return (duration - progress) <= playedThreshold
    }

    private func playedStatus(for episode: Episode, progress: TimeInterval? = nil, duration overrideDuration: TimeInterval? = nil) -> Bool {
        let episodeProgress: TimeInterval
        if let progress {
            episodeProgress = progress
        } else if currentEpisode?.id == episode.id {
            episodeProgress = currentTime
        } else {
            episodeProgress = getPlaybackPosition(for: episode.id)
        }

        let episodeDuration: TimeInterval
        if let overrideDuration {
            episodeDuration = overrideDuration
        } else if currentEpisode?.id == episode.id && duration > 0 {
            episodeDuration = duration
        } else {
            episodeDuration = episode.duration
        }

        return isProgressPlayed(episodeProgress, duration: episodeDuration)
    }

    private func syncPlayedStatus(for episode: Episode, progress: TimeInterval? = nil, duration overrideDuration: TimeInterval? = nil) {
        let isPlayed = playedStatus(for: episode, progress: progress, duration: overrideDuration)
        postPlayedStatusIfChanged(episodeID: episode.id, isPlayed: isPlayed)
    }

    private func postPlayedStatusIfChanged(episodeID: UUID, isPlayed: Bool) {
        if playedStatusByEpisodeID[episodeID] == isPlayed {
            return
        }

        playedStatusByEpisodeID[episodeID] = isPlayed
        if currentEpisode?.id == episodeID {
            currentEpisode?.isPlayed = isPlayed
        }

        NotificationCenter.default.post(
            name: .episodeMarkedAsPlayed,
            object: nil,
            userInfo: [
                "episodeId": episodeID,
                "isPlayed": isPlayed
            ]
        )
    }

    private func playNextUnplayedDownloadedEpisode(after finishedEpisode: Episode) -> Bool {
        let allDownloaded = playbackPodcasts
            .flatMap(\.episodes)
            .filter { localAudioURL(for: $0.id) != nil }
            .sorted { $0.publishDate > $1.publishDate }

        guard !allDownloaded.isEmpty else {
            return false
        }

        let orderedCandidates: [Episode]
        if let finishedIndex = allDownloaded.firstIndex(where: { $0.id == finishedEpisode.id }) {
            let head = Array(allDownloaded[(finishedIndex + 1)...])
            let tail = Array(allDownloaded[..<finishedIndex])
            orderedCandidates = head + tail
        } else {
            orderedCandidates = allDownloaded
        }

        for candidate in orderedCandidates where !playedStatus(for: candidate) {
            guard let localURL = localAudioURL(for: candidate.id) else {
                continue
            }

            var nextEpisode = candidate
            nextEpisode.localFileURL = localURL
            print("[AudioPlayerService] Auto-playing next unplayed downloaded episode: \(nextEpisode.title)")
            play(episode: nextEpisode)
            return true
        }

        return false
    }

    private func localAudioURL(for episodeID: UUID) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath
            .appendingPathComponent("Downloads")
            .appendingPathComponent("\(episodeID.uuidString).mp3")

        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    private func setupNowPlaying(episode: Episode) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = episode.title
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = episode.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        
        if let artworkURL = episode.localImageURL ?? episode.displayImageURL {
            loadNowPlayingArtwork(from: artworkURL)
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        setupRemoteCommandCenter()
    }

    private func loadNowPlayingArtwork(from artworkURL: URL) {
        Task.detached(priority: .utility) {
            let data: Data?

            if artworkURL.isFileURL {
                data = try? Data(contentsOf: artworkURL)
            } else {
                guard let (remoteData, response) = try? await URLSession.shared.data(from: artworkURL),
                      let httpResponse = response as? HTTPURLResponse,
                      200..<300 ~= httpResponse.statusCode else {
                    return
                }
                data = remoteData
            }

            guard let data,
                  let image = UIImage(data: data) else {
                return
            }

            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            await MainActor.run {
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }
    
    private func updateNowPlayingPlaybackState() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingElapsedTime() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            if let episode = self?.currentEpisode {
                self?.play(episode: episode)
            } else {
                self?.resume()
            }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause(reason: "remote_command")
            return .success
        }
        
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward()
            return .success
        }
        
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: event.positionTime)
            return .success
        }
    }
    
    // MARK: - Playback Position Persistence
    
    private func savePlaybackPosition(for episodeID: UUID) {
        guard currentTime.isFinite && currentTime >= 0 else {
            return
        }

        playbackPositions[episodeID.uuidString] = currentTime
        prunePlaybackPositionsToKnownEpisodes()
        trimPlaybackPositionsIfNeeded()
        persistPlaybackPositionsToDisk()
        print("[AudioPlayerService] Saved position: \(currentTime)s for episode \(episodeID)")
    }
    
    private func getPlaybackPosition(for episodeID: UUID) -> TimeInterval {
        playbackPositions[episodeID.uuidString] ?? 0
    }
    
    func clearPlaybackPosition(for episodeID: UUID) {
        playbackPositions.removeValue(forKey: episodeID.uuidString)
        persistPlaybackPositionsToDisk()
        postPlayedStatusIfChanged(episodeID: episodeID, isPlayed: false)
    }

    private func playbackPositionsFileURL() -> URL {
        let supportURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GardenManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        return supportURL.appendingPathComponent(playbackPositionsFileName)
    }

    private func loadPlaybackPositionsFromDisk() {
        let fileURL = playbackPositionsFileURL()

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data) {
            playbackPositions = decoded
            UserDefaults.standard.removeObject(forKey: legacyPlaybackPositionsKey)
            return
        }

        if let legacyPositions = UserDefaults.standard.dictionary(forKey: legacyPlaybackPositionsKey) {
            var migrated: [String: TimeInterval] = [:]
            for (key, value) in legacyPositions {
                if let number = value as? NSNumber {
                    migrated[key] = number.doubleValue
                }
            }
            playbackPositions = migrated
            trimPlaybackPositionsIfNeeded()
            persistPlaybackPositionsToDisk()
        }

        UserDefaults.standard.removeObject(forKey: legacyPlaybackPositionsKey)
    }

    private func persistPlaybackPositionsToDisk() {
        let fileURL = playbackPositionsFileURL()
        guard let data = try? JSONEncoder().encode(playbackPositions) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func prunePlaybackPositionsToKnownEpisodes() {
        let validIDs = Set(playbackPodcasts.flatMap(\.episodes).map { $0.id.uuidString })
        guard !validIDs.isEmpty else {
            return
        }
        playbackPositions = playbackPositions.filter { validIDs.contains($0.key) }
        let validUUIDs = Set(playbackPodcasts.flatMap(\.episodes).map(\.id))
        playedStatusByEpisodeID = playedStatusByEpisodeID.filter { validUUIDs.contains($0.key) }
    }

    private func trimPlaybackPositionsIfNeeded() {
        guard playbackPositions.count > maxStoredPlaybackPositions else {
            return
        }

        let overflowCount = playbackPositions.count - maxStoredPlaybackPositions
        for key in playbackPositions.keys.sorted().prefix(overflowCount) {
            playbackPositions.removeValue(forKey: key)
        }
    }
    
    @objc private func savePositionOnBackground() {
        if let episode = currentEpisode {
            savePlaybackPosition(for: episode.id)
            saveLastPlayedEpisodeID(episode.id)
        }
    }
    
    @objc private func handleAppDidBecomeActive() {
        isInBackground = false
        // Check if player stopped unexpectedly while we were playing
        if let player = player, wasPlayingBeforeBackground {
            if player.rate == 0 && currentEpisode != nil {
                print("[AudioPlayerService] Player stopped in background, attempting to resume")
                activateAudioSession()
                player.play()
                isPlaying = true
                updateNowPlayingPlaybackState()
            }
        }
        wasPlayingBeforeBackground = false
    }
    
    @objc private func handleAppDidEnterBackground() {
        isInBackground = true
        // Track that we were playing before going to background
        if isPlaying {
            wasPlayingBeforeBackground = true
        }
    }
    
    private func saveLastPlayedEpisodeID(_ episodeID: UUID) {
        UserDefaults.standard.set(episodeID.uuidString, forKey: lastPlayedEpisodeIDKey)
    }
    
    private func getLastPlayedEpisodeID() -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: lastPlayedEpisodeIDKey) else {
            return nil
        }
        return UUID(uuidString: raw)
    }
    
    func restoreLastPlayedEpisode(
        podcasts: [Podcast],
        resolveLocalURL: ((Episode) -> URL?)? = nil
    ) {
        guard currentEpisode == nil else { return }
        guard let episodeID = getLastPlayedEpisodeID() else { return }
        
        for podcast in podcasts {
            if let found = podcast.episodes.first(where: { $0.id == episodeID }) {
                var episode = found
                if let resolveLocalURL = resolveLocalURL {
                    episode.localFileURL = resolveLocalURL(episode)
                }
                currentTime = getPlaybackPosition(for: episodeID)
                print("[AudioPlayerService] Restoring episode: \(found.title), position: \(currentTime)")
                
                // Load the episode and set up player, but don't auto-play
                loadEpisode(episode: episode, restoredFromPosition: currentTime)
                return
            }
        }
    }
    
    func loadEpisode(episode: Episode, restoredFromPosition: TimeInterval? = nil) {
        print("[AudioPlayerService] loadEpisode() called for: \(episode.title)")
        configureAudioSession()
        
        saveLastPlayedEpisodeID(episode.id)
        
        // Always create a new player on restore
        seekWorkItem?.cancel()
        seekWorkItem = nil
        isSeeking = false
        lastSavedTime = 0

        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        // Save position of previous episode before switching
        if let prevEpisode = currentEpisode {
            savePlaybackPosition(for: prevEpisode.id)
        }
        
        currentTime = 0
        duration = 0
        currentEpisode = episode
        let audioURL = episode.localFileURL ?? episode.audioURL
        print("[AudioPlayerService] Creating player with URL: \(audioURL)")
        let playerItem = AVPlayerItem(url: audioURL)
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
        
        setupTimeObserver()
        setupNowPlaying(episode: episode)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // Restore saved position
        let savedPosition = restoredFromPosition ?? getPlaybackPosition(for: episode.id)
        let resumePosition = resumePositionIfUnplayed(savedPosition, for: episode)
        if resumePosition > 0 {
            let cmTime = CMTime(seconds: resumePosition, preferredTimescale: 600)
            player?.seek(to: cmTime)
            currentTime = resumePosition
            print("[AudioPlayerService] Restored position: \(resumePosition)s")
        }
        
        // Don't auto-play - just ready to play
        isPlaying = false
        print("[AudioPlayerService] Episode loaded, ready to play: \(episode.title)")
    }
    
    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        
        NotificationCenter.default.removeObserver(self)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[AudioPlayerService] Failed to deactivate audio session: \(error)")
        }
    }
}
