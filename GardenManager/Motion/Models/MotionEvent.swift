import Foundation

typealias Acceleration = (x: Double, y: Double, z: Double)

struct MotionEvent: Identifiable {
    let id = UUID()
    let acceleration: Acceleration
    let timestamp: Date
}

enum MotionEventType {
    case movementDetected
    case initialReading
    case statusUpdate
    case thresholdChanged
    case velocityReset
    
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
        case .velocityReset:
            return "Velocity Reset"
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
        case .velocityReset:
            return "arrow.counterclockwise"
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
        case .velocityReset:
            return "purple"
        }
    }
}
