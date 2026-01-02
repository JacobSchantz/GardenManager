import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

@available(iOS 26.0, *)
struct ContentView: View {
    @StateObject private var toolService = ToolService()
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var commandParser: CommandParser
    @State private var showingToolSheet = false
    @State private var selectedTool: ToolType?
    
    init() {
        let service = ToolService()
        _toolService = StateObject(wrappedValue: service)
        _speechRecognizer = StateObject(wrappedValue: SpeechRecognizer())
        _commandParser = StateObject(wrappedValue: CommandParser(toolService: service))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Voice Input Section
                voiceInputSection
                
                Divider()
                
                // Tool Buttons
                toolButtonsSection
                
                Divider()
                
                // Tool Call History
                toolHistorySection
            }
            .navigationTitle("Garden Manager")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        toolService.clearHistory()
                    }
                    .disabled(toolService.toolCalls.isEmpty)
                }
            }
            .sheet(item: $selectedTool) { tool in
                ToolParameterSheet(tool: tool, toolService: toolService)
            }
        }
    }
    
    private var voiceInputSection: some View {
        VStack(spacing: 12) {
            // Microphone Button
            Button(action: toggleListening) {
                ZStack {
                    Circle()
                        .fill(speechRecognizer.isListening ? Color.red : Color.green)
                        .frame(width: 80, height: 80)
                        .shadow(color: speechRecognizer.isListening ? .red.opacity(0.4) : .green.opacity(0.4), radius: 10)
                    
                    Image(systemName: speechRecognizer.isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
            }
            
            // Status Text
            if speechRecognizer.isListening {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Listening...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Tap to speak a command")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Transcript Display
            if !speechRecognizer.transcript.isEmpty {
                VStack(spacing: 8) {
                    Text("\"\(speechRecognizer.transcript)\"")
                        .font(.body)
                        .italic()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if commandParser.isProcessing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing with Apple Intelligence...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Error Display
            if let error = speechRecognizer.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if let error = commandParser.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private func toggleListening() {
        print("ContentView: toggleListening called, isListening=\(speechRecognizer.isListening)")
        if speechRecognizer.isListening {
            speechRecognizer.stopListening()
            // Process the command after stopping
            Task {
                await processVoiceCommand()
            }
        } else {
            print("ContentView: Calling startListening...")
            speechRecognizer.startListening()
        }
    }
    
    private func processVoiceCommand() async {
        guard !speechRecognizer.transcript.isEmpty else { return }
        await commandParser.processCommand(speechRecognizer.transcript)
    }
    
    private var toolButtonsSection: some View {
        VStack(spacing: 16) {
            Text("Available Tools")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                ForEach(ToolType.allCases) { tool in
                    ToolButton(tool: tool) {
                        selectedTool = tool
                    }
                    .disabled(toolService.isExecuting)
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private var toolHistorySection: some View {
        Group {
            if toolService.toolCalls.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "leaf.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.green.opacity(0.5))
                    Text("No tool calls yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Tap a tool above to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(toolService.toolCalls) { call in
                        ToolCallRow(call: call)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct ToolButton: View {
    let tool: ToolType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: tool.icon)
                    .font(.system(size: 28))
                Text(tool.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(width: 80, height: 80)
            .background(toolColor.opacity(0.15))
            .foregroundColor(toolColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(toolColor.opacity(0.3), lineWidth: 2)
            )
        }
    }
    
    private var toolColor: Color {
        switch tool {
        case .dig: return .brown
        case .plant: return .green
        case .walk: return .blue
        }
    }
}

struct ToolCallRow: View {
    let call: ToolCall
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: call.tool.icon)
                    .foregroundColor(toolColor)
                Text(call.tool.rawValue)
                    .font(.headline)
                Spacer()
                StatusBadge(status: call.status)
            }
            
            if !call.parameters.isEmpty {
                Text(parametersText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let result = call.result {
                Text(result)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            Text(call.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var toolColor: Color {
        switch call.tool {
        case .dig: return .brown
        case .plant: return .green
        case .walk: return .blue
        }
    }
    
    private var parametersText: String {
        call.parameters.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}

struct StatusBadge: View {
    let status: ToolCallStatus
    
    var body: some View {
        HStack(spacing: 4) {
            if status == .executing {
                ProgressView()
                    .scaleEffect(0.7)
            }
            Text(status.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .executing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    ContentView()
}
