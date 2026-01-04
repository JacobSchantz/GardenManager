import Foundation
import Combine

class MotionAudioCoordinator: ObservableObject {
    private let motionTracker: MotionTracker
    private let audioPlayerService: AudioPlayerService
    private var cancellables = Set<AnyCancellable>()
    private var wasPlayingBeforeMotionPause = false
    
    init(motionTracker: MotionTracker, audioPlayerService: AudioPlayerService) {
        self.motionTracker = motionTracker
        self.audioPlayerService = audioPlayerService
        setupMotionObserver()
        setupAudioObserver()
    }
    
    private func setupMotionObserver() {
        motionTracker.$hasMovedRecently
            .removeDuplicates()
            .sink { [weak self] hasMovedRecently in
                guard let self = self else { return }
                
                if !hasMovedRecently && self.audioPlayerService.isPlaying {
                    self.wasPlayingBeforeMotionPause = true
                    self.audioPlayerService.pause()
                } else if hasMovedRecently && self.wasPlayingBeforeMotionPause && !self.audioPlayerService.isPlaying {
                    self.wasPlayingBeforeMotionPause = false
                    self.audioPlayerService.resume()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAudioObserver() {
        // Reset motion pause tracking when user manually pauses/plays
        audioPlayerService.$isPlaying
            .removeDuplicates()
            .sink { [weak self] isPlaying in
                guard let self = self else { return }
                if !isPlaying {
                    self.wasPlayingBeforeMotionPause = false
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.removeAll()
    }
}
