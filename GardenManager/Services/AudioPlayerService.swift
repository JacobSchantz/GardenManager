import Foundation
import AVFoundation
import Combine

class AudioPlayerService: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentEpisode: Episode?
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
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
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem
            )
        }
        
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
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
            self?.currentTime = time.seconds
            if let duration = self?.player?.currentItem?.duration.seconds, !duration.isNaN {
                self?.duration = duration
            }
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        isPlaying = false
        currentTime = 0
        player?.seek(to: .zero)
    }
    
    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        NotificationCenter.default.removeObserver(self)
    }
}
