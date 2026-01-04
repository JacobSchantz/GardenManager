import Foundation
import CoreMotion

final class MotionTracker: ObservableObject {
    @Published private(set) var hasMovedRecently: Bool = true
    @Published private(set) var lastMovementDate: Date?
    @Published private(set) var totalVelocity: Double = 0
    @Published private(set) var secondsBetweenCalculations: Int = 10
    @Published private(set) var minimumVelocity: Double = 3.0
    @Published private(set) var motionEvents: [MotionEvent] = []
    private let motionManager = CMMotionManager()
    private var timer: Timer?
    private let maxEvents = 100
    private var lastCalculationTime: Date?

    init(secondsBetweenCalculations: Int = 10, minimumVelocity: Double = 0.03) {
        self.secondsBetweenCalculations = secondsBetweenCalculations
        self.minimumVelocity = minimumVelocity
        start()
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            hasMovedRecently = false
            return
        }
        
        // Reset tracking variables
        totalVelocity = 0
        motionEvents.removeAll()
        lastCalculationTime = nil

        // Start motion updates
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            self?.handleDeviceMotion(motion)
        }
        setupTimer()
    }
 
    
    private func handleDeviceMotion(_ motion: CMDeviceMotion?) {
        guard let self = self as MotionTracker?, let motion = motion else { return }
        let a = motion.userAcceleration
        let currentTime = Date()
        
        // Create and store event
        let event = MotionEvent(acceleration: (a.x, a.y, a.z), timestamp: currentTime)
        self.motionEvents.insert(event, at: 0)
        if self.motionEvents.count > 100 {
            self.motionEvents.removeLast()
        }
    }
    
    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let cutoff = Date().addingTimeInterval(-Double(self.secondsBetweenCalculations))
            
            let recentEvents = self.motionEvents.filter { $0.timestamp >= cutoff }
            if recentEvents.count < 2 {
                return
            } 
            // Calculate total velocity
            var totalVelocity: Double = 0
            for i in 1..<recentEvents.count {
                let magnitude = sqrt(
                    pow(recentEvents[i].acceleration.x, 2) +
                    pow(recentEvents[i].acceleration.y, 2) +
                    pow(recentEvents[i].acceleration.z, 2)
                )
                totalVelocity += magnitude * 0.1
            }
            self.totalVelocity = totalVelocity
            if (self.lastCalculationTime == nil || Int(Date().timeIntervalSince(self.lastCalculationTime!)) > secondsBetweenCalculations) {
                self.lastCalculationTime = Date()
                hasMovedRecently = totalVelocity > minimumVelocity
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        motionManager.stopDeviceMotionUpdates()
    }


    deinit {
        timer?.invalidate()
        motionManager.stopDeviceMotionUpdates()
    }
}
