import Foundation

class ToolService: ObservableObject {
    @Published var toolCalls: [ToolCall] = []
    @Published var isExecuting: Bool = false
    
    func callTool(_ tool: ToolType, parameters: [String: String] = [:]) {
        var call = ToolCall(tool: tool, parameters: parameters)
        call.status = .executing
        toolCalls.insert(call, at: 0)
        isExecuting = true
        
        // Simulate async tool execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.executeToolCall(call)
        }
    }
    
    private func executeToolCall(_ call: ToolCall) {
        guard let index = toolCalls.firstIndex(where: { $0.id == call.id }) else { return }
        
        let result = executeTool(call.tool, parameters: call.parameters)
        
        toolCalls[index].result = result
        toolCalls[index].status = .completed
        isExecuting = false
    }
    
    private func executeTool(_ tool: ToolType, parameters: [String: String]) -> String {
        switch tool {
        case .dig:
            let depth = parameters["depth"] ?? "6 inches"
            let location = parameters["location"] ?? "garden bed"
            return "Successfully dug a hole \(depth) deep at \(location). Ready for planting!"
            
        case .plant:
            let seedType = parameters["seedType"] ?? "tomato"
            let quantity = parameters["quantity"] ?? "1"
            return "Planted \(quantity) \(seedType) seed(s). Water regularly and expect sprouts in 7-14 days."
            
        case .walk:
            let duration = parameters["duration"] ?? "10 minutes"
            let area = parameters["area"] ?? "entire garden"
            return "Walked through \(area) for \(duration). Observed healthy growth and no pest issues."
        }
    }
    
    func clearHistory() {
        toolCalls.removeAll()
    }
}
