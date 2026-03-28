import SwiftUI
import UIKit

struct OpenClawVoiceView: View {
    @StateObject private var service = OpenClawVoiceService()
    @State private var apiKey: String = ""
    @State private var chatId: String = ""
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status and Connect Button
                    statusSection

                    // Permission Status
                    permissionSection
                    
                    // Transcription Display
                    transcriptionSection
                    
                    // Response Display
                    responseSection
                    
                    // Error Section
                    if let error = service.errorMessage {
                        errorSection(error)
                    }
                    
                    // Debug Logs
                    debugLogsSection
                }
                .padding()
            }
            .navigationTitle("OpenClaw Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(service: service, apiKey: $apiKey, chatId: $chatId)
            }
            .onAppear {
                loadSettings()
                service.checkPermissions()
            }
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(spacing: 16) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 4)
                        .scaleEffect(service.isPlaying ? 1.5 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: service.isPlaying)
                )
            
            Text(statusText)
                .font(.headline)
                .foregroundStyle(.primary)
            
            // Large Start/End Call Button
            Button(action: toggleCall) {
                Circle()
                    .fill(callButtonColor)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: service.state == .disconnected ? "phone.fill" : "phone.down.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var statusColor: Color {
        switch service.state {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .listening: return .green
        case .processing: return .blue
        case .speaking: return .purple
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch service.state {
        case .disconnected: return "Tap to start call"
        case .connecting: return "Connecting..."
        case .listening: return "Listening..."
        case .processing: return "Processing..."
        case .speaking: return "Speaking..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    private var callButtonColor: Color {
        switch service.state {
        case .disconnected, .error: return .green
        default: return .red
        }
    }
    
    // MARK: - Permission Section
    
    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mic.circle.fill")
                    .foregroundStyle(.blue)
                Text("Microphone Permission")
                    .font(.headline)
                Spacer()
                Text(service.microphonePermissionStatus.label)
                    .foregroundStyle(.secondary)
            }
            
            if service.microphonePermissionStatus != .granted {
                Button("Request Permission") {
                    Task {
                        await service.requestPermissions()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Transcription Section
    
    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundStyle(.blue)
                Text("Your Speech")
                    .font(.headline)
                Spacer()
                if !service.transcribedText.isEmpty {
                    Button("Clear") {
                        service.clearTranscription()
                    }
                    .font(.caption)
                }
            }
            
            Text(service.transcribedText.isEmpty ? "Speak and your text will appear here..." : service.transcribedText)
                .foregroundStyle(service.transcribedText.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Response Section
    
    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(.purple)
                Text("Response")
                    .font(.headline)
                Spacer()
                if !service.responseText.isEmpty {
                    Button("Speak") {
                        service.speak(service.responseText)
                    }
                    .font(.caption)
                }
            }
            
            Text(service.responseText.isEmpty ? "OpenClaw's response will appear here..." : service.responseText)
                .foregroundStyle(service.responseText.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Error Section
    
    private func errorSection(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Error")
                    .font(.headline)
                    .foregroundStyle(.red)
            }
            
            Text(error)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Debug Logs Section
    
    private var debugLogsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.secondary)
                Text("Debug Logs")
                    .font(.headline)
                Spacer()
                if !service.debugLogs.isEmpty {
                    Button("Clear") {
                        service.clearLogs()
                    }
                    .font(.caption)
                }
            }
            
            if service.debugLogs.isEmpty {
                Text("No logs yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(service.debugLogs.suffix(10).reversed(), id: \.self) { log in
                    Text(log)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Actions
    
    private func toggleCall() {
        Task {
            if service.state == .disconnected || service.state.isError {
                do {
                    try await service.connect()
                } catch {
                    // Error already handled in service
                }
            } else {
                service.disconnect()
            }
        }
    }
    
    private func loadSettings() {
        apiKey = service.telegramBotToken
        chatId = service.telegramChatId
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @ObservedObject var service: OpenClawVoiceService
    @Binding var apiKey: String
    @Binding var chatId: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Telegram Configuration") {
                    TextField("Bot Token", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    TextField("Chat ID", text: $chatId)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                Section {
                    Text("To get a bot token, message @BotFather on Telegram and create a new bot.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("To get your chat ID, forward a message from your chat to @userinfobot or use @getidsbot.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        service.telegramBotToken = apiKey
                        service.telegramChatId = chatId
                        service.saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Helper Extension

extension OpenClawVoiceState {
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

#Preview {
    OpenClawVoiceView()
}