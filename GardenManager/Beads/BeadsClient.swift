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

        // On iOS, we can't shell out to `bd` CLI directly.
        // In a production app, this would call a backend API.
        // For now, load from the bundled mock data or use live data via a helper.
        do {
            let data = try await fetchBeadsData()
            let decoded = try JSONDecoder().decode([Bead].self, from: data)
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

    /// Fetch beads data. On macOS this could shell out to `bd`;
    /// on iOS we read from a bundled JSON or use mock data.
    private func fetchBeadsData() async throws -> Data {
        // Try to read from the app's shared directory (populated by an external process)
        // Fall back to mock data if unavailable
        let mockBeads: [Bead] = [
            Bead(id: "GardenManager-bxg", title: "View and reorder beads in GardenManager UI", status: "in_progress", priority: 1, issue_type: "feature", assignee: "JacobSchantz", owner: "Butterber347@gmail.com", created_at: "2026-04-20T23:46:53Z", created_by: "JacobSchantz", updated_at: "2026-04-21T01:35:06Z", started_at: "2026-04-21T01:35:06Z", dependency_count: 0, dependent_count: 0, comment_count: 0),
            Bead(id: "GardenManager-2qy", title: "Build Garden Interface game from combined plan", status: "open", priority: 0, issue_type: "epic", assignee: nil, owner: "Butterber347@gmail.com", created_at: "2026-04-20T23:38:04Z", created_by: "JacobSchantz", updated_at: "2026-04-20T23:38:04Z", started_at: nil, dependency_count: 0, dependent_count: 0, comment_count: 0),
            Bead(id: "GardenManager-hb2", title: "Implement GUUF local models", status: "open", priority: 1, issue_type: "feature", assignee: nil, owner: "Butterber347@gmail.com", created_at: "2026-04-20T23:42:36Z", created_by: "JacobSchantz", updated_at: "2026-04-20T23:42:36Z", started_at: nil, dependency_count: 0, dependent_count: 0, comment_count: 0),
            Bead(id: "GardenManager-5ju", title: "Integrate Beads as task data layer for garden", status: "open", priority: 1, issue_type: "feature", assignee: nil, owner: "Butterber347@gmail.com", created_at: "2026-04-20T23:38:12Z", created_by: "JacobSchantz", updated_at: "2026-04-20T23:38:12Z", started_at: nil, dependency_count: 0, dependent_count: 0, comment_count: 0),
            Bead(id: "GardenManager-40k", title: "Implement SwiftUI garden scene with plant visuals", status: "open", priority: 1, issue_type: "feature", assignee: nil, owner: "Butterber347@gmail.com", created_at: "2026-04-20T23:38:11Z", created_by: "JacobSchantz", updated_at: "2026-04-20T23:38:11Z", started_at: nil, dependency_count: 0, dependent_count: 0, comment_count: 0),
        ]
        return try JSONEncoder().encode(mockBeads)
    }
}
