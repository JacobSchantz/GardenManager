import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Tool Definitions for Foundation Models

@available(iOS 26.0, macOS 26.0, *)
struct DigTool: Tool {
    let name = "dig"
    let description = "Dig a hole in the garden. Use this when the user wants to dig, excavate, or prepare the soil."
    
    let toolService: ToolService
    
    @Generable
    struct Arguments {
        @Guide(description: "The depth to dig, e.g. '6 inches' or '1 foot'")
        var depth: String?
        
        @Guide(description: "The location in the garden to dig, e.g. 'garden bed' or 'near the fence'")
        var location: String?
    }
    
    func call(arguments: Arguments) async throws -> String {
        var params: [String: String] = [:]
        if let depth = arguments.depth { params["depth"] = depth }
        if let location = arguments.location { params["location"] = location }
        
        await MainActor.run {
            toolService.callTool(.dig, parameters: params)
        }
        return "Digging initiated at \(arguments.location ?? "garden bed") with depth \(arguments.depth ?? "6 inches")"
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct PlantTool: Tool {
    let name = "plant"
    let description = "Plant seeds or seedlings in the garden. Use this when the user wants to plant, sow, or grow something."
    
    let toolService: ToolService
    
    @Generable
    struct Arguments {
        @Guide(description: "The type of seed or plant to plant, e.g. 'tomato', 'carrot', 'basil'")
        var seedType: String?
        
        @Guide(description: "The number of seeds or plants to plant")
        var quantity: String?
    }
    
    func call(arguments: Arguments) async throws -> String {
        var params: [String: String] = [:]
        if let seedType = arguments.seedType { params["seedType"] = seedType }
        if let quantity = arguments.quantity { params["quantity"] = quantity }
        
        await MainActor.run {
            toolService.callTool(.plant, parameters: params)
        }
        return "Planted \(arguments.quantity ?? "1") \(arguments.seedType ?? "seed")(s)"
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct WalkTool: Tool {
    let name = "walk"
    let description = "Walk through and inspect the garden. Use this when the user wants to walk, stroll, inspect, check, or survey the garden."
    
    let toolService: ToolService
    
    @Generable
    struct Arguments {
        @Guide(description: "How long to walk through the garden, e.g. '10 minutes' or '1 hour'")
        var duration: String?
        
        @Guide(description: "The area of the garden to walk through, e.g. 'vegetable section' or 'entire garden'")
        var area: String?
    }
    
    func call(arguments: Arguments) async throws -> String {
        var params: [String: String] = [:]
        if let duration = arguments.duration { params["duration"] = duration }
        if let area = arguments.area { params["area"] = area }
        
        await MainActor.run {
            toolService.callTool(.walk, parameters: params)
        }
        return "Walking through \(arguments.area ?? "entire garden") for \(arguments.duration ?? "10 minutes")"
    }
}

// MARK: - AI-Powered Command Parser

@available(iOS 26.0, macOS 26.0, *)
@MainActor
class CommandParser: ObservableObject {
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    private var session: LanguageModelSession?
    private let toolService: ToolService
    
    init(toolService: ToolService) {
        self.toolService = toolService
    }
    
    func processCommand(_ text: String) async {
        guard !text.isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            guard SystemLanguageModel.default.availability == .available else {
                errorMessage = "Apple Intelligence is not available on this device"
                isProcessing = false
                return
            }
            
            session = LanguageModelSession(tools: [
                DigTool(toolService: toolService),
                PlantTool(toolService: toolService),
                WalkTool(toolService: toolService)
            ]) {
                """
                You are a garden assistant. When the user gives you a command about gardening,
                use the appropriate tool to help them. Available actions are:
                - Digging holes in the garden
                - Planting seeds or seedlings
                - Walking through and inspecting the garden
                
                Parse the user's natural language and call the appropriate tool with the right parameters.
                """
            }
            
            let response = try await session?.respond(to: text)
            
            // The tool will have been called automatically by the session
            print("AI Response: \(response?.content ?? "No response")")
            
        } catch {
            errorMessage = "Failed to process command: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
}

#endif
