import SwiftUI

struct BuildStatusTabView: View {
    @State private var buildStatus: BuildStatus?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastRefresh = Date()
    
    private let listenerURL = "http://192.168.0.242:8765/status"
    
    var body: some View {
        NavigationStack {
            List {
                if let status = buildStatus {
                    statusSection(status)
                    commitSection(status)
                    if status.isBuilding {
                        buildingSection
                    }
                } else if isLoading {
                    loadingSection
                } else if let error = errorMessage {
                    errorSection(error)
                }
            }
            .navigationTitle("Build Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: fetchStatus) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                fetchStatus()
            }
        }
    }
    
    // MARK: - Sections
    
    private func statusSection(_ status: BuildStatus) -> some View {
        Section("Status") {
            HStack {
                Image(systemName: status.isBuilding ? "hammer.fill" : (status.lastBuild == "success" ? "checkmark.circle.fill" : "questionmark.circle.fill"))
                    .foregroundStyle(status.isBuilding ? .orange : (status.lastBuild == "success" ? .green : .secondary))
                Text(status.isBuilding ? "Building..." : (status.lastBuild == "success" ? "Last build succeeded" : (status.lastBuild == "failed" ? "Last build failed" : "No builds yet")))
                    .foregroundStyle(status.isBuilding ? .orange : .primary)
                Spacer()
                if status.isBuilding {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let lastBuildTime = status.lastBuildTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text("Last build: \(formatDate(lastBuildTime))")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func commitSection(_ status: BuildStatus) -> some View {
        Section("Latest Commit") {
            if let repo = status.lastRepo, let branch = status.lastBranch {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(.blue)
                    Text("\(repo)/\(branch)")
                        .font(.headline)
                }
            }
            
            if let commitMessage = status.lastCommitMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(commitMessage)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
            
            if let commitHash = status.lastCommit {
                HStack {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                    Text(String(commitHash.prefix(7)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }
    
    private var buildingSection: some View {
        Section {
            HStack {
                ProgressView()
                    .padding(.trailing, 8)
                Text("Build in progress...")
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private var loadingSection: some View {
        Section {
            HStack {
                ProgressView()
                Text("Loading build status...")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
        }
    }
    
    private func errorSection(_ error: String) -> some View {
        Section("Error") {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }
    
    // MARK: - Actions
    
    private func fetchStatus() {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: listenerURL) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    isLoading = false
                    lastRefresh = Date()
                    
                    do {
                        let decoder = JSONDecoder()
                        buildStatus = try decoder.decode(BuildStatus.self, from: data)
                    } catch {
                        errorMessage = "Failed to parse response"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    lastRefresh = Date()
                    errorMessage = "Cannot connect to listener"
                }
            }
        }
    }
    
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: isoString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: isoString) else {
                return isoString
            }
            return relativeFormat(date)
        }
        return relativeFormat(date)
    }
    
    private func relativeFormat(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Model

struct BuildStatus: Codable {
    let lastBuild: String?
    let lastCommit: String?
    let lastCommitMessage: String?
    let lastRepo: String?
    let lastBranch: String?
    let isBuilding: Bool
    let lastBuildTime: String?
}

#Preview {
    BuildStatusTabView()
}
