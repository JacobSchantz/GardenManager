import SwiftUI

struct ToolParameterSheet: View {
    let tool: ToolType
    @ObservedObject var toolService: ToolService
    @Environment(\.dismiss) private var dismiss
    
    @State private var parameters: [String: String] = [:]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: tool.icon)
                            .font(.title)
                            .foregroundColor(toolColor)
                        VStack(alignment: .leading) {
                            Text(tool.rawValue)
                                .font(.headline)
                            Text(tool.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Parameters (Optional)") {
                    parameterFields
                }
                
                Section {
                    Button(action: executeTool) {
                        HStack {
                            Spacer()
                            Image(systemName: "play.fill")
                            Text("Execute \(tool.rawValue)")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(toolColor)
                }
            }
            .navigationTitle("Call Tool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var parameterFields: some View {
        switch tool {
        case .dig:
            TextField("Depth (e.g., 6 inches)", text: binding(for: "depth"))
            TextField("Location (e.g., garden bed)", text: binding(for: "location"))
            
        case .plant:
            TextField("Seed Type (e.g., tomato)", text: binding(for: "seedType"))
            TextField("Quantity (e.g., 3)", text: binding(for: "quantity"))
            
        case .walk:
            TextField("Duration (e.g., 10 minutes)", text: binding(for: "duration"))
            TextField("Area (e.g., vegetable section)", text: binding(for: "area"))
        }
    }
    
    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { parameters[key] ?? "" },
            set: { parameters[key] = $0.isEmpty ? nil : $0 }
        )
    }
    
    private func executeTool() {
        toolService.callTool(tool, parameters: parameters)
        dismiss()
    }
    
    private var toolColor: Color {
        switch tool {
        case .dig: return .brown
        case .plant: return .green
        case .walk: return .blue
        }
    }
}

#Preview {
    ToolParameterSheet(tool: .plant, toolService: ToolService())
}
