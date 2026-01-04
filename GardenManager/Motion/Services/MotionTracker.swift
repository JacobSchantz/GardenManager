import Foundation
import CoreMotion

final class MotionTracker: ObservableObject {
    @Published private(set) var hasMovedRecently: Bool = true
    @Published private(set) var lastMovementDate: Date?
    @Published private(set) var currentAcceleration: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published private(set) var currentVelocity: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published private(set) var currentPosition: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published private(set) var currentMagnitude: Double = 0
    
    private var positionHistory: [(x: Double, y: Double, z: Double, timestamp: Date)] = []
    private let maxHistoryPoints = 1000  // Store last 1000 position updates
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

    init(recentWindow: TimeInterval = 10, movementThreshold: Double = 0.03) {
        self.recentWindow = recentWindow
        self.movementThreshold = movementThreshold
        start()
    }

    func start() {
        guard motionManager.isAccelerometerAvailable else {
            hasMovedRecently = true
            return
        }
        
        // Reset tracking variables
        lastUpdateTime = nil
        lastAcceleration = (0, 0, 0)
        currentVelocity = (0, 0, 0)

        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            let a = data.acceleration
            let threshold = 0.009
            if abs(a.x) < threshold && abs(a.y) < threshold && abs(a.z) < threshold {
                return
            }
            let currentTime = Date()
            
            // Calculate time delta in seconds
            let dt = self.lastUpdateTime.map { currentTime.timeIntervalSince($0) } ?? 0
            self.lastUpdateTime = currentTime
            
            // Update acceleration
            self.currentAcceleration = (a.x, a.y, a.z)
            
            // Only calculate velocity if we have a valid time delta
            if dt > 0 {
                // Integrate acceleration to get velocity (v = v0 + a*dt)
                self.currentVelocity = (
                    self.currentVelocity.x + (a.x + self.lastAcceleration.x) * 0.5 * dt,
                    self.currentVelocity.y + (a.y + self.lastAcceleration.y) * 0.5 * dt,
                    self.currentVelocity.z + (a.z + self.lastAcceleration.z - 1.0) * 0.5 * dt  // Subtract 1g from z for gravity
                )
                
                // Update position (x = x0 + v*dt)
                self.currentPosition = (
                    self.currentPosition.x + self.currentVelocity.x * dt,
                    self.currentPosition.y + self.currentVelocity.y * dt,
                    self.currentPosition.z + self.currentVelocity.z * dt
                )
                
                // Add to history
                self.positionHistory.append((
                    x: self.currentPosition.x,
                    y: self.currentPosition.y,
                    z: self.currentPosition.z,
                    timestamp: currentTime
                ))
                
                // Trim history if needed
                if self.positionHistory.count > self.maxHistoryPoints {
                    self.positionHistory.removeFirst()
                }
            }
            
            // Store current acceleration for next update
            self.lastAcceleration = (a.x, a.y, a.z)
            
            // Calculate magnitude of acceleration
            let magnitude = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            self.currentMagnitude = magnitude
            
            if let last = self.lastMagnitude {
                let change = abs(magnitude - last)
                self.lastMagnitudeChange = change
                
                if change > self.movementThreshold {
                    self.lastMovementDate = Date()
                    self.updateHasMovedRecently()
                    
                    let event = MotionEvent(
                        type: .movementDetected,
                        value: change,
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

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateHasMovedRecently()
            // Add periodic status events
            if let self = self {
                let event = MotionEvent(
                    type: .statusUpdate,
                    value: self.currentMagnitude,
                    date: Date(),
                    acceleration: self.currentAcceleration
                )
                self.motionEvents.append(event)
                if self.motionEvents.count > self.maxEvents {
                    self.motionEvents.removeFirst()
                }
            }
        }
        updateHasMovedRecently()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        motionManager.stopAccelerometerUpdates()
    }
    
    func resetVelocity() {
        currentVelocity = (0, 0, 0)
        lastUpdateTime = nil
        lastAcceleration = (0, 0, 0)
    }
    
    func resetPosition() {
        currentPosition = (0, 0, 0)
        positionHistory.removeAll()
    }
    
    func getPositionHistory() -> [(x: Double, y: Double, z: Double, timestamp: Date)] {
        return positionHistory
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
        motionManager.stopAccelerometerUpdates()
    }
}
