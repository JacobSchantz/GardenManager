import Foundation
import UIKit
import AVFoundation
import Combine
import MediaPlayer

class AudioPlayerService: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentEpisode: Episode?
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var seekWorkItem: DispatchWorkItem?
    private var isSeeking = false
    private var isAudioSessionConfigured = false
    private var lastSavedTime: TimeInterval = 0
    private var wasPlayingBeforeBackground = false
    private var isInBackground = false
    
    private let playbackPositionsKey = "PlaybackPositions"
    private let lastPlayedEpisodeIDKey = "LastPlayedEpisodeID"
    
    override init() {
        super.init()
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
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowAirPlay, AVAudioSession.CategoryOptions.allowBluetoothHFP]
            )
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
    
    func play(episode: Episode) {
        print("[AudioPlayerService] play() called for: \(episode.title)")
        configureAudioSession()
        activateAudioSession()
        
        saveLastPlayedEpisodeID(episode.id)
        
        let isNewEpisode = currentEpisode?.id != episode.id
        
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
            }
            
            currentTime = 0
            duration = 0
            currentEpisode = episode
            let audioURL = episode.localFileURL ?? episode.audioURL
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
            
            // Restore saved position for this episode
            let savedPosition = getPlaybackPosition(for: episode.id)
            if savedPosition > 0 {
                let cmTime = CMTime(seconds: savedPosition, preferredTimescale: 600)
                player?.seek(to: cmTime)
                currentTime = savedPosition
                print("[AudioPlayerService] Restored position: \(savedPosition)s")
            }
        }
        
        player?.play()
        isPlaying = true
        updateNowPlayingPlaybackState()
        print("[AudioPlayerService] Playing: \(episode.title)")
    }
    
    func resume() {
        activateAudioSession()
        player?.play()
        isPlaying = true
        updateNowPlayingPlaybackState()
    }
    
    func pause(reason: String = "manual") {
        // Don't pause from remote/UI commands while in background (except for real interruptions)
        let allowedBackgroundPauses = ["interruption_began", "route_change_old_device_unavailable"]
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
            
            // Save position every 10 seconds during playback
            if let episode = self.currentEpisode,
               abs(time.seconds - self.lastSavedTime) >= 10 {
                self.savePlaybackPosition(for: episode.id)
                self.lastSavedTime = time.seconds
            }
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        isPlaying = false
        currentTime = 0
        player?.seek(to: .zero)
        
        // Clear saved position when episode finishes
        if let episode = currentEpisode {
            clearPlaybackPosition(for: episode.id)
        }
    }
    
    private func setupNowPlaying(episode: Episode) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = episode.title
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = episode.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        
        if let imageURL = episode.imageURL {
            Task {
                if let data = try? Data(contentsOf: imageURL),
                   let image = UIImage(data: data) {
                    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        setupRemoteCommandCenter()
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
        var positions = getPlaybackPositions()
        positions[episodeID.uuidString] = currentTime
        UserDefaults.standard.set(positions, forKey: playbackPositionsKey)
        print("[AudioPlayerService] Saved position: \(currentTime)s for episode \(episodeID)")
    }
    
    private func getPlaybackPosition(for episodeID: UUID) -> TimeInterval {
        let positions = getPlaybackPositions()
        return positions[episodeID.uuidString] ?? 0
    }
    
    private func getPlaybackPositions() -> [String: TimeInterval] {
        return UserDefaults.standard.dictionary(forKey: playbackPositionsKey) as? [String: TimeInterval] ?? [:]
    }
    
    func clearPlaybackPosition(for episodeID: UUID) {
        var positions = getPlaybackPositions()
        positions.removeValue(forKey: episodeID.uuidString)
        UserDefaults.standard.set(positions, forKey: playbackPositionsKey)
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
                currentEpisode = episode
                currentTime = getPlaybackPosition(for: episodeID)
                print("[AudioPlayerService] Restored last played episode: \(episode.title)")
                return
            }
        }
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
