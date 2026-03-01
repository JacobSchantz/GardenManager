import Foundation

struct PodcastSearchResult: Identifiable, Codable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let artworkUrl600: String?
    let feedUrl: String?
    let trackCount: Int?
    
    var id: Int { trackId }
}

@MainActor
class PodcastSearchService: ObservableObject {
    @Published var results: [PodcastSearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    func search(query: String) async {
        guard !query.isEmpty else {
            results = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        results = []
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://itunes.apple.com/search?term=\(encodedQuery)&media=podcast&entity=podcast&limit=25"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                isLoading = false
                return
            }
            
            if httpResponse.statusCode != 200 {
                errorMessage = "Server error: \(httpResponse.statusCode)"
                isLoading = false
                return
            }
            
            let searchResponse = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
            results = searchResponse.results.filter { $0.feedUrl != nil }
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func clear() {
        results = []
        errorMessage = nil
    }
}

struct iTunesSearchResponse: Codable {
    let resultCount: Int
    let results: [PodcastSearchResult]
}
