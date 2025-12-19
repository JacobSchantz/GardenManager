import SwiftUI

struct ContentView: View {
    @StateObject private var toolService = ToolService()
    @State private var showingToolSheet = false
    @State private var selectedTool: ToolType?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
