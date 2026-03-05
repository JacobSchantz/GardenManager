import Foundation

struct ITunesPodcastResult: Identifiable, Codable, Hashable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let artworkUrl600: String?
    let feedUrl: String?
    let trackCount: Int?
    
    var id: Int { trackId }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(trackId)
    }
    
    static func == (lhs: ITunesPodcastResult, rhs: ITunesPodcastResult) -> Bool {
        lhs.trackId == rhs.trackId
    }
}

@MainActor
final class PodcastSearchService: ObservableObject {
    @Published var results: [ITunesPodcastResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    private var latestSearchID = UUID()

    private enum SearchError: LocalizedError {
        case invalidURL
        case invalidResponse
        case serverError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response"
            case .serverError(let code):
                return "Server error: \(code)"
            }
        }
    }
    
    func search(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedQuery.count >= 2 else {
            latestSearchID = UUID()
            results = []
            errorMessage = nil
            isLoading = false
            return
        }

        let searchID = UUID()
        latestSearchID = searchID
        isLoading = true
        errorMessage = nil

        do {
            let fetchedResults = try await Self.fetchResults(for: trimmedQuery)

            guard searchID == latestSearchID else {
                return
            }

            results = fetchedResults
        } catch is CancellationError {
            guard searchID == latestSearchID else {
                return
            }
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }

        if searchID == latestSearchID {
            isLoading = false
        }
    }
    
    func clear() {
        latestSearchID = UUID()
        results = []
        errorMessage = nil
        isLoading = false
    }

    nonisolated private static func fetchResults(for query: String) async throws -> [ITunesPodcastResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://itunes.apple.com/search?term=\(encodedQuery)&media=podcast&entity=podcast&limit=25"

        guard let url = URL(string: urlString) else {
            throw SearchError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SearchError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw SearchError.serverError(httpResponse.statusCode)
        }

        let searchResponse = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
        return searchResponse.results.filter { $0.feedUrl != nil }
    }
}

struct iTunesSearchResponse: Codable {
    let resultCount: Int
    let results: [ITunesPodcastResult]
}
