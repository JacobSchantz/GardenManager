import SwiftUI
import UIKit

struct GrokVoiceView: View {
    @StateObject private var service = GrokVoiceService()
    @State private var apiKey: String = ""
    @State private var showSettings = false
    @State private var copiedText: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Status and Connect Button
                statusSection
                
                // Voice Selection
                voiceSection
                
                // Output Section
                outputSection
                
                // Error Section
                if let error = service.errorMessage {
                    errorSection(error)
                }
                
                // Debug Logs (collapsible)
                debugSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Grok Voice")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 16) {
            // State indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 12, height: 12)
                Text(stateText)
                    .font(.headline)
            }
            
            // Connect/Disconnect button
            Button(action: toggleConnection) {
                HStack {
                    Image(systemName: buttonIcon)
                    Text(buttonText)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(buttonColor)
                .cornerRadius(12)
            }
            .disabled(service.state == .connecting)
        }
    }
    
    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voice")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("Voice", selection: $service.selectedVoice) {
                ForEach(service.voices, id: \.self) { voice in
                    Text(voice).tag(voice)
                }
            }
            .pickerStyle(.segmented)
            .disabled(service.state != .disconnected)
        }
    }
    
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Output")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !service.currentOutput.isEmpty {
                    Button(action: copyOutput) {
                        HStack(spacing: 4) {
                            Image(systemName: copiedText == "output" ? "checkmark" : "doc.on.doc")
                            Text(copiedText == "output" ? "Copied!" : "Copy")
                        }
                        .font(.caption)
                    }
                }
            }
            
            if service.currentOutput.isEmpty {
                Text("No output yet. Press the button above to start a conversation.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                ScrollView {
                    Text(service.currentOutput)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 100, maxHeight: 200)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private func errorSection(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Error")
                    .font(.subheadline)
                    .foregroundColor(.red)
                
                Spacer()
                
                Button(action: copyError) {
                    HStack(spacing: 4) {
                        Image(systemName: copiedText == "error" ? "checkmark" : "doc.on.doc")
                        Text(copiedText == "error" ? "Copied!" : "Copy")
                    }
                    .font(.caption)
                }
            }
            
            Text(error)
                .font(.body)
                .foregroundColor(.red)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
        }
    }
    
    private var debugSection: some View {
        DisclosureGroup("Debug Logs") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(service.debugLogs.indices, id: \.self) { index in
                        Text(service.debugLogs[index])
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
    }
    
    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("API Key") {
                    SecureField("xAI API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    Button("Save API Key") {
                        service.setAPIKey(apiKey)
                        showSettings = false
                    }
                    .disabled(apiKey.isEmpty)
                }
                
                Section("System Instructions") {
                    TextEditor(text: $service.systemInstructions)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showSettings = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Helpers
    
    private var stateColor: Color {
        switch service.state {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .listening: return .green
        case .processing: return .blue
        case .speaking: return .purple
        case .error: return .red
        }
    }

    private var stateText: String {
        switch service.state {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .listening: return "Listening"
        case .processing: return "Processing..."
        case .speaking: return "Speaking"
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    private var buttonIcon: String {
        switch service.state {
        case .disconnected: return "mic.fill"
        case .connecting: return "hourglass"
        case .listening, .processing, .speaking: return "stop.fill"
        case .error: return "arrow.clockwise"
        }
    }
    
    private var buttonText: String {
        switch service.state {
        case .disconnected: return "Connect"
        case .connecting: return "Connecting..."
        case .listening, .processing, .speaking: return "Disconnect"
        case .error: return "Retry"
        }
    }
    
    private var buttonColor: Color {
        switch service.state {
        case .disconnected, .error: return .blue
        case .connecting: return .gray
        case .listening, .processing, .speaking: return .red
        }
    }
    
    private func toggleConnection() {
        Task {
            if service.state == .disconnected || isErrorState {
                do {
                    try await service.connect()
                } catch {
                    // Error is already handled in service
                }
            } else {
                service.disconnect()
            }
        }
    }
    
    private var isErrorState: Bool {
        if case .error = service.state { return true }
        return false
    }
    
    private func copyOutput() {
        UIPasteboard.general.string = service.currentOutput
        copiedText = "output"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedText = nil
        }
    }
    
    private func copyError() {
        if let error = service.errorMessage {
            UIPasteboard.general.string = error
            copiedText = "error"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copiedText = nil
            }
        }
    }
}
