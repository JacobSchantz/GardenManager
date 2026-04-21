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
            var allBeads: [Bead] = []
            
            // Load beads from all bundled repos
            for repo in Repo.allCases {
                if let data = loadBeadsData(for: repo) {
                    let decoded = parseJSONL(data, repo: repo)
                    allBeads.append(contentsOf: decoded)
                }
            }
            
            beads = allBeads.sorted { $0.priority < $1.priority }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchBeadDetail(id: String) async -> Bead? {
        beads.first { $0.id == id }
    }

    func beadsForRepo(_ repo: Repo) -> [Bead] {
        beads.filter { $0.repo == repo }
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

    // MARK: - Data Loading

    private func loadBeadsData(for repo: Repo) -> Data? {
        // Try the app bundle (resources added via project.yml)
        if let url = Bundle.main.url(forResource: "\(repo.rawValue)_issues", withExtension: "jsonl") {
            if let data = try? Data(contentsOf: url) { return data }
        }

        // Try shared app group container for live sync
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gardenmanager.beads") {
            let fileURL = containerURL.appendingPathComponent("\(repo.rawValue)/.beads/issues.jsonl")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let data = try? Data(contentsOf: fileURL) { return data }
            }
        }

        return nil
    }

    private func parseJSONL(_ data: Data, repo: Repo) -> [Bead] {
        let lines = String(data: data, encoding: .utf8)?
            .split(separator: "\n")
            .map(String.init) ?? []

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var decoded: [Bead] = []
        for line in lines {
            guard let lineData = line.data(using: .utf8), !line.isEmpty else { continue }
            if var bead = try? decoder.decode(Bead.self, from: lineData) {
                bead.repo = repo
                decoded.append(bead)
            }
        }
        return decoded
    }
}

// MARK: - Repos

enum Repo: String, CaseIterable, Identifiable {
    case gardenManager = "GardenManager"
    case buyAHabit = "BuyAHabit"
    case keepMovin = "keepMovin"
    case atg = "ATG"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gardenManager: return "Garden Manager"
        case .buyAHabit: return "BuyAHabit"
        case .keepMovin: return "KeepMovin"
        case .atg: return "ATG"
        }
    }

    var icon: String {
        switch self {
        case .gardenManager: return "leaf.fill"
        case .buyAHabit: return "carrot.fill"
        case .keepMovin: return "figure.run"
        case .atg: return "sportscourt.fill"
        }
    }

    var color: String {
        switch self {
        case .gardenManager: return "green"
        case .buyAHabit: return "orange"
        case .keepMovin: return "blue"
        case .atg: return "purple"
        }
    }
}

enum BeadsError: LocalizedError {
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Could not find any issues.jsonl files in app bundle"
        }
    }
}
