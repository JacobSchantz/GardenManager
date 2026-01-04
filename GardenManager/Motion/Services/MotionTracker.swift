import Foundation
import CoreMotion

final class MotionTracker: ObservableObject {
    @Published private(set) var hasMovedRecently: Bool = true
    @Published private(set) var lastMovementDate: Date?
    @Published private(set) var currentAcceleration: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published private(set) var currentMagnitude: Double = 0
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

        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            let a = data.acceleration
            let magnitude = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            
            self.currentAcceleration = (a.x, a.y, a.z)
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
