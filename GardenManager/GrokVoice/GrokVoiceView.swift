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

                // Permission Status
                permissionSection
                
                // Voice Selection
                voiceSection
                
                // Output Section
                outputSection
                
                // Error Section
                if let error = service.errorMessage {
                    errorSection(error)
                }
                
                // API Messages (debug)
                apiMessagesSection
                
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
                SettingsSheet(apiKey: $apiKey, service: service)
            }
            .onAppear {
                service.refreshPermissionStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                service.refreshPermissionStatus()
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
            .disabled(service.state == .connecting || service.microphonePermissionStatus == .denied)
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Image(systemName: microphonePermissionIcon)
                    .foregroundColor(microphonePermissionColor)
                Text("Microphone: \(service.microphonePermissionStatus.label)")
                    .font(.body)
            }

            if service.microphonePermissionStatus == .denied {
                Text("Microphone access is denied. Enable it in iOS Settings to use voice mode.")
                    .font(.caption)
                    .foregroundColor(.red)
            } else if service.microphonePermissionStatus == .notDetermined || service.microphonePermissionStatus == .unknown {
                Button("Request Microphone Access") {
                    Task {
                        _ = await service.requestPermission(.microphone)
                    }
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                Text("Responses")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !service.responses.isEmpty {
                    Button(action: copyAllResponses) {
                        HStack(spacing: 4) {
                            Image(systemName: copiedText == "all" ? "checkmark" : "doc.on.doc")
                            Text(copiedText == "all" ? "Copied!" : "Copy All")
                        }
                        .font(.caption)
                    }
                }
            }
            
            if service.responses.isEmpty && service.currentOutput.isEmpty {
                Text("No output yet. Press the button above to start a conversation.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                // Current (live) output
                if !service.currentOutput.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(service.currentOutput)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Past responses
                if !service.responses.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(service.responses.enumerated()), id: \.offset) { index, response in
                                responseItem(response, index: index)
                            }
                        }
                    }
                    .frame(minHeight: 100, maxHeight: 250)
                }
            }
        }
    }
    
    private func responseItem(_ response: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(response)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: { copyResponse(index) }) {
                Image(systemName: copiedText == "response-\(index)" ? "checkmark" : "doc.on.doc")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
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
    
    private var apiMessagesSection: some View {
        DisclosureGroup("API Messages (\(service.apiMessages.count))") {
            if service.apiMessages.isEmpty {
                Text("No messages yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(service.apiMessages.enumerated()), id: \.offset) { index, msg in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatAPIType(msg))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Text(msg)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(10)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }
    
    private func formatAPIType(_ msg: String) -> String {
        guard let data = msg.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return "raw"
        }
        return type
    }
    
    private var settingsSheet: some View {
        SettingsSheet(apiKey: $apiKey, service: service)
    }
    
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

    private var microphonePermissionIcon: String {
        switch service.microphonePermissionStatus {
        case .granted: return "mic.fill"
        case .denied: return "mic.slash.fill"
        case .notDetermined, .unknown: return "questionmark.circle"
        }
    }

    private var microphonePermissionColor: Color {
        switch service.microphonePermissionStatus {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined, .unknown: return .orange
        }
    }
    
    private func toggleConnection() {
        if service.state == .disconnected || isErrorState {
            Task {
                await service.connect()
            }
        } else {
            service.disconnect()
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
    
    private func copyAllResponses() {
        UIPasteboard.general.string = service.responses.joined(separator: "\n\n---\n\n")
        copiedText = "all"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedText = nil
        }
    }
    
    private func copyResponse(_ index: Int) {
        guard index < service.responses.count else { return }
        UIPasteboard.general.string = service.responses[index]
        copiedText = "response-\(index)"
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

struct SettingsSheet: View {
    @Binding var apiKey: String
    @ObservedObject var service: GrokVoiceService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("API Key") {
                    SecureField("xAI API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    Button("Save API Key") {
                        service.setAPIKey(apiKey)
                        dismiss()
                    }
                    .disabled(apiKey.isEmpty)
                    
                    if UserDefaults.standard.string(forKey: "xAI_API_Key") != nil {
                        Button("Clear Cached Key") {
                            UserDefaults.standard.removeObject(forKey: "xAI_API_Key")
                            service.setAPIKey("")
                            apiKey = ""
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
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
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            // Load cached key if field is empty
            if apiKey.isEmpty, let cached = UserDefaults.standard.string(forKey: "xAI_API_Key") {
                apiKey = cached
            }
        }
    }
}
