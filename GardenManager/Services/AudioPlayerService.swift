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
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func play(episode: Episode) {
        if currentEpisode?.id != episode.id {
            currentEpisode = episode
            let playerItem = AVPlayerItem(url: episode.audioURL)
            player = AVPlayer(playerItem: playerItem)
            setupTimeObserver()
            setupNowPlaying(episode: episode)
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem
            )
        }
        
        player?.play()
        isPlaying = true
        updateNowPlayingPlaybackState()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingPlaybackState()
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
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        isPlaying = false
        currentTime = 0
        player?.seek(to: .zero)
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
    
    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        NotificationCenter.default.removeObserver(self)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
