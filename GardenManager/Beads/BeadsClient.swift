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

        var allBeads: [Bead] = []
        var errors: [String] = []

        // Fetch beads from all repos in parallel
        await withTaskGroup(of: (Repo, [Bead]).self) { group in
            for repo in Repo.allCases {
                group.addTask {
                    let beads = await self.fetchBeadsForRepo(repo)
                    return (repo, beads)
                }
            }
            for await (repo, repoBeads) in group {
                allBeads.append(contentsOf: repoBeads)
                if repoBeads.isEmpty {
                    errors.append(repo.displayName)
                }
            }
        }

        beads = allBeads.sorted { $0.priority < $1.priority }

        if beads.isEmpty && !errors.isEmpty {
            errorMessage = "Could not load beads from: \(errors.joined(separator: ", "))"
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

    // MARK: - Remote Fetching

    private func fetchBeadsForRepo(_ repo: Repo) async -> [Bead] {
        // Try the bundled file first (for offline / fast load)
        if let url = Bundle.main.url(forResource: "\(repo.rawValue)_issues", withExtension: "jsonl"),
           let data = try? Data(contentsOf: url) {
            return parseJSONL(data, repo: repo)
        }

        // Fetch from GitHub raw
        guard let remoteURL = repo.remoteURL else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            return parseJSONL(data, repo: repo)
        } catch {
            return []
        }
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

    /// GitHub raw URL for the repo's issues.jsonl
    var remoteURL: URL? {
        switch self {
        case .gardenManager:
            return URL(string: "https://raw.githubusercontent.com/JacobSchantz/GardenManager/main/.beads/issues.jsonl")
        case .buyAHabit:
            return URL(string: "https://raw.githubusercontent.com/JacobSchantz/buyahabit/main/.beads/issues.jsonl")
        case .keepMovin:
            return URL(string: "https://raw.githubusercontent.com/JacobSchantz/keepMovin/main/.beads/issues.jsonl")
        case .atg:
            // ATG is on a different org — adjust if needed
            return nil
        }
    }
}
