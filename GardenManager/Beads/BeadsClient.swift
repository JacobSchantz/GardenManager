import Foundation

@Observable
@MainActor
final class BeadsClient {
    var beads: [Bead] = []
    var isLoading = false
    var errorMessage: String?

    private var refreshTimer: Timer?

    func fetchBeads() async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try loadBeadsData()
            // issues.jsonl is JSON Lines — one JSON object per line
            let lines = String(data: data, encoding: .utf8)?
                .split(separator: "\n")
                .map(String.init) ?? []
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            var decoded: [Bead] = []
            for line in lines {
                guard let lineData = line.data(using: .utf8), !line.isEmpty else { continue }
                if let bead = try? decoder.decode(Bead.self, from: lineData) {
                    decoded.append(bead)
                }
            }
            beads = decoded
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchBeadDetail(id: String) async -> Bead? {
        beads.first { $0.id == id }
    }

    func startAutoRefresh(interval: TimeInterval = 60) {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchBeads()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Load beads from the bundled issues.jsonl file.
    /// The file lives at .beads/issues.jsonl in the repo and gets
    /// included in the app bundle via the xcodegen sources path.
    private func loadBeadsData() throws -> Data {
        // Try the app bundle first (works on device)
        if let url = Bundle.main.url(forResource: "issues", withExtension: "jsonl", subdirectory: ".beads") {
            return try Data(contentsOf: url)
        }
        
        // Try without subdirectory (in case xcodegen flattens it)
        if let url = Bundle.main.url(forResource: "issues", withExtension: "jsonl") {
            return try Data(contentsOf: url)
        }
        
        // Try the shared app group container (for live sync from OpenClaw)
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gardenmanager.beads") {
            let fileURL = containerURL.appendingPathComponent(".beads/issues.jsonl")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return try Data(contentsOf: fileURL)
            }
        }
        
        throw BeadsError.fileNotFound
    }
}

enum BeadsError: LocalizedError {
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Could not find issues.jsonl in app bundle or shared container"
        }
    }
}
