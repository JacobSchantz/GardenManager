import Foundation
import CoreMotion

final class MotionTracker: ObservableObject {
    @Published private(set) var hasMovedRecently: Bool = true
    @Published private(set) var lastMovementDate: Date?
    @Published private(set) var currentAcceleration: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published private(set) var currentVelocity: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published private(set) var currentMagnitude: Double = 0
    @Published private(set) var totalVelocityLast5Seconds: Double = 0
    @Published private(set) var timeUntilNextReset: TimeInterval = 0
    
    @Published private(set) var lastMagnitudeChange: Double = 0
    @Published private(set) var motionEvents: [MotionEvent] = []

    var recentWindow: TimeInterval {
        didSet {
            updateHasMovedRecently()
        }
    }

    var movementThreshold: Double {
        didSet {
            motionEvents.append(MotionEvent(type: .thresholdChanged, value: movementThreshold, date: Date()))
            if motionEvents.count > 50 {
                motionEvents.removeFirst()
            }
        }
    }

    private let motionManager = CMMotionManager()
    private var timer: Timer?
    private var lastUpdateTime: Date?
    private var lastAcceleration: (x: Double, y: Double, z: Double) = (0, 0, 0)
    private var lastMagnitude: Double?
    private let maxEvents = 50
    private var accelerationHistory: [(acceleration: Double, timestamp: Date)] = []
    private let velocityWindow: TimeInterval = 5
    private var lastVelocityResetTime: Date?

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
        currentVelocity = (0, 0, 0)
        accelerationHistory.removeAll()
        totalVelocityLast5Seconds = 0
        currentMagnitude = 0
        lastMagnitude = nil
        lastMagnitudeChange = 0
        motionEvents.removeAll()
        lastVelocityResetTime = Date()

        // Start motion updates
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            self?.handleDeviceMotion(motion)
        }
        setupTimer()
        updateHasMovedRecently()
    }
 
    
    private func handleDeviceMotion(_ motion: CMDeviceMotion?) {
        guard let self = self as MotionTracker?, let motion = motion else { return }
        let a = motion.userAcceleration  // User acceleration without gravity
        let currentTime = Date()
        
        // Calculate time delta in seconds
        let dt = self.lastUpdateTime.map { currentTime.timeIntervalSince($0) } ?? 0
        self.lastUpdateTime = currentTime
        let ax = abs(a.x) > 0.01 ? abs(a.x) : 0.0
        let ay = abs(a.y) > 0.01 ? abs(a.y) : 0.0
        let az = abs(a.z) > 0.01 ? abs(a.z) : 0.0
        self.currentAcceleration = (ax, ay, az)

        if ax < 0.01 && ay < 0.01 && az < 0.01 {
            return
        }
        
        // Only calculate velocity if we have a valid time delta
        if dt > 0 {
            // Calculate absolute acceleration magnitude for velocity calculation
            let absMagnitude = abs(ax) + abs(ay) + abs(az)
        }
        
        // Store current acceleration for next update
        self.lastAcceleration = (ax, ay, az)
        
        // Calculate magnitude of acceleration
        let magnitude = sqrt(ax * ax + ay * ay + az * az)
        self.currentMagnitude = magnitude
        
        // Store in history
        self.accelerationHistory.append((magnitude, currentTime))
        
        if let last = self.lastMagnitude {
            let change = abs(magnitude - last)
            self.lastMagnitudeChange = change
            
            if self.totalVelocityLast5Seconds > self.movementThreshold {
                self.lastMovementDate = Date()
                self.updateHasMovedRecently()
                
                let event = MotionEvent(
                    type: .movementDetected,
                    value: self.totalVelocityLast5Seconds,
                    date: Date(),
                    acceleration: (a.x, a.y, a.z)
                )
                self.motionEvents.append(event)
                if self.motionEvents.count > self.maxEvents {
                    self.motionEvents.removeFirst()
                }
            }
        } else {
            self.lastMagnitude = magnitude
            // Initial reading event
            let event = MotionEvent(
                type: .initialReading,
                value: magnitude,
                date: Date(),
                acceleration: (a.x, a.y, a.z)
            )
            self.motionEvents.append(event)
        }
        
        self.lastMagnitude = magnitude
    }
    
    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            
            // Check if it's time to reset velocity (every 5 seconds)
            if let lastReset = self.lastVelocityResetTime, now.timeIntervalSince(lastReset) >= 5 {
                self.resetVelocity()
                self.lastVelocityResetTime = now
                
                // Log velocity reset event
                let event = MotionEvent(
                    type: .velocityReset,
                    value: self.totalVelocityLast5Seconds,
                    date: now,
                    acceleration: self.currentAcceleration
                )
                self.motionEvents.append(event)
                if self.motionEvents.count > self.maxEvents {
                    self.motionEvents.removeFirst()
                }
            }
            
            self.updateHasMovedRecently()
            
            // Add periodic status events
            let event = MotionEvent(
                type: .statusUpdate,
                value: self.currentMagnitude,
                date: now,
                acceleration: self.currentAcceleration
            )
            self.motionEvents.append(event)
            if self.motionEvents.count > self.maxEvents {
                self.motionEvents.removeFirst()
            }
            
            // Update time until next reset
            if let lastReset = self.lastVelocityResetTime {
                self.timeUntilNextReset = max(0, lastReset.addingTimeInterval(5).timeIntervalSince(now))
            }
            
            // Compute total velocity for the last 5 seconds
            let cutoff = now.addingTimeInterval(-5)
            var totalVelocity: Double = 0
            
            // Trim old entries
            self.accelerationHistory = self.accelerationHistory.filter { $0.timestamp >= cutoff }
            
            if self.accelerationHistory.count > 1 {
                for i in 1..<self.accelerationHistory.count {
                    let dt = self.accelerationHistory[i].timestamp.timeIntervalSince(self.accelerationHistory[i-1].timestamp)
                    totalVelocity += self.accelerationHistory[i].acceleration * dt
                }
            }
            self.totalVelocityLast5Seconds = totalVelocity
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        motionManager.stopDeviceMotionUpdates()
    }
    
    func resetVelocity() {
        currentVelocity = (0, 0, 0)
        lastUpdateTime = nil
        lastAcceleration = (0, 0, 0)
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
