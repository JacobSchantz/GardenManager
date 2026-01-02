import Foundation
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
    
    private let playbackPositionsKey = "PlaybackPositions"
    
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
    }
    
    private func configureAudioSession() {
        guard !isAudioSessionConfigured else { return }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowAirPlay, .allowBluetooth]
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
            pause()
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
            pause()
        default:
            break
        }
    }
    
    func play(episode: Episode) {
        configureAudioSession()
        activateAudioSession()
        
        let isNewEpisode = currentEpisode?.id != episode.id
        
        if isNewEpisode {
            // Save position of previous episode before switching
            if let prevEpisode = currentEpisode {
                savePlaybackPosition(for: prevEpisode.id)
            }
            
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
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingPlaybackState()
        
        // Save playback position when pausing
        if let episode = currentEpisode {
            savePlaybackPosition(for: episode.id)
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
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
            self?.play(episode: self?.currentEpisode ?? Episode(title: "", description: "", audioURL: URL(string: "https://example.com")!, publishDate: Date()))
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
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
        }
    }
    
    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        
        // Save position before cleanup
        if let episode = currentEpisode {
            savePlaybackPosition(for: episode.id)
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
