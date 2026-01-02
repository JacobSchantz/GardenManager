import Foundation

enum ToolType: String, CaseIterable, Identifiable {
    case dig = "Dig"
    case plant = "Plant"
    case walk = "Walk"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .dig: return "shovel.fill"
        case .plant: return "leaf.fill"
        case .walk: return "figure.walk"
        }
    }
    
    var description: String {
        switch self {
        case .dig: return "Dig a hole in the garden"
        case .plant: return "Plant a seed or seedling"
        case .walk: return "Walk through the garden"
        }
    }
    
    var color: String {
        switch self {
        case .dig: return "brown"
        case .plant: return "green"
        case .walk: return "blue"
        }
    }
}

struct ToolCall: Identifiable {
    let id = UUID()
    let tool: ToolType
    let parameters: [String: String]
    let timestamp: Date
    var result: String?
    var status: ToolCallStatus
    
    init(tool: ToolType, parameters: [String: String] = [:]) {
        self.tool = tool
        self.parameters = parameters
        self.timestamp = Date()
        self.result = nil
        self.status = .pending
    }
}

enum ToolCallStatus: String {
    case pending = "Pending"
    case executing = "Executing"
    case completed = "Completed"
    case failed = "Failed"
}
