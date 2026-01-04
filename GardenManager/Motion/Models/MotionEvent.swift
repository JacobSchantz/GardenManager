import Foundation

typealias Acceleration = (x: Double, y: Double, z: Double)

struct MotionEvent: Identifiable {
    let id = UUID()
    let type: MotionEventType
    let value: Double
    let date: Date
    let acceleration: Acceleration
    
    init(type: MotionEventType, value: Double, date: Date, acceleration: Acceleration = (x: 0, y: 0, z: 0)) {
        self.type = type
        self.value = value
        self.date = date
        self.acceleration = acceleration
    }
}

enum MotionEventType {
    case movementDetected
    case initialReading
    case statusUpdate
    case thresholdChanged
    
    var displayName: String {
        switch self {
        case .movementDetected:
            return "Movement Detected"
        case .initialReading:
            return "Initial Reading"
        case .statusUpdate:
            return "Status Update"
        case .thresholdChanged:
            return "Threshold Changed"
        }
    }
    
    var icon: String {
        switch self {
        case .movementDetected:
            return "figure.walk"
        case .initialReading:
            return "play.circle"
        case .statusUpdate:
            return "clock"
        case .thresholdChanged:
            return "slider.horizontal.3"
        }
    }
    
    var color: String {
        switch self {
        case .movementDetected:
            return "green"
        case .initialReading:
            return "blue"
        case .statusUpdate:
            return "gray"
        case .thresholdChanged:
            return "orange"
        }
    }
}
