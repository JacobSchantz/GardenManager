import Foundation
import CoreMotion

final class MotionTracker: ObservableObject {
    @Published private(set) var hasMovedRecently: Bool = true
    @Published private(set) var lastMovementDate: Date?
    @Published private(set) var totalVelocityLast5Seconds: Double = 0
    
    private var motionEvents: [MotionEvent] = []

    var recentWindow: TimeInterval {
        didSet {
            updateHasMovedRecently()
        }
    }

    var movementThreshold: Double

    private let motionManager = CMMotionManager()
    private var timer: Timer?
    private var lastUpdateTime: Date?
    private var lastAcceleration: (x: Double, y: Double, z: Double) = (0, 0, 0)
    private var lastMagnitude: Double?
    private let maxEvents = 50
    private var accelerationHistory: [(acceleration: Double, timestamp: Date)] = []
    private let velocityWindow: TimeInterval = 5
    private var lastVelocityResetTime: Date?
    private var lastCalculationTime: Date?

    init(recentWindow: TimeInterval = 10, movementThreshold: Double = 0.03) {
        self.recentWindow = recentWindow
        self.movementThreshold = movementThreshold
        start()
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            hasMovedRecently = true
            return
        }
        

        // Reset tracking variables
        lastUpdateTime = nil
        lastAcceleration = (0, 0, 0)
        accelerationHistory.removeAll()
        totalVelocityLast5Seconds = 0
        lastMagnitude = nil
        motionEvents.removeAll()
        lastVelocityResetTime = Date()
        lastCalculationTime = nil

        // Start motion updates
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            self?.handleDeviceMotion(motion)
        }
        setupTimer()
        updateHasMovedRecently()
    }
 
    
    private func handleDeviceMotion(_ motion: CMDeviceMotion?) {
        guard let self = self as MotionTracker?, let motion = motion else { return }
        let a = motion.userAcceleration
        let currentTime = Date()
        
        // Create and store event
        let event = MotionEvent(acceleration: (a.x, a.y, a.z), timestamp: currentTime)
        self.motionEvents.append(event)
    }
    
    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let cutoff = Date().addingTimeInterval(-5)
            
            // Filter events from the last 5 seconds
            let recentEvents = self.motionEvents.filter { $0.timestamp >= cutoff }
            if recentEvents.count < 2 {
                return
            } 
            // Calculate total velocity
            var totalVelocity: Double = 0
            for i in 1..<recentEvents.count {
                let dt = recentEvents[i].timestamp.timeIntervalSince(recentEvents[i-1].timestamp)
                let magnitude = sqrt(
                    pow(recentEvents[i].acceleration.x, 2) +
                    pow(recentEvents[i].acceleration.y, 2) +
                    pow(recentEvents[i].acceleration.z, 2)
                )
                totalVelocity += magnitude * dt
            }
            self.totalVelocityLast5Seconds = totalVelocity
            
            // Update motionEvents to only keep recent events
            self.motionEvents = recentEvents
            self.lastCalculationTime = Date()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        motionManager.stopDeviceMotionUpdates()
    }
    
 
    
    private func updateHasMovedRecently() {
        guard let lastMovementDate = lastMovementDate else {
            hasMovedRecently = true
            return
        }

        hasMovedRecently = Date().timeIntervalSince(lastMovementDate) <= recentWindow
    }

    deinit {
        timer?.invalidate()
        motionManager.stopDeviceMotionUpdates()
    }
}
