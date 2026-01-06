import Foundation

actor PodcastSearchService {
    private let baseURL = "https://listen-api.listennotes.com/api/v2"
    private let apiKey: String
    
    init(apiKey: String = "") {
        // For now, we'll use the test API if no key is provided
        // In production, this should come from a secure configuration
        self.apiKey = apiKey.isEmpty ? "" : apiKey
    }
    
    func searchPodcasts(query: String, offset: Int = 0, limit: Int = 20) async throws -> PodcastSearchResponse {
        let endpoint = "/search"
        var components = URLComponents(string: baseURL + endpoint)!
        
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "podcast"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        // Add safe mode for content filtering
        queryItems.append(URLQueryItem(name: "safe_mode", value: "1"))
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Use test API if no key provided, otherwise use production
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-ListenAPI-Key")
        } else {
            // Use test API - change base URL
            let testURL = URL(string: "https://listen-api-test.listennotes.com/api/v2/search")!
            var testComponents = URLComponents(url: testURL, resolvingAgainstBaseURL: false)!
            testComponents.queryItems = queryItems
            guard let testURLWithQuery = testComponents.url else {
                throw URLError(.badURL)
            }
            request.url = testURLWithQuery
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(PodcastSearchResponse.self, from: data)
    }
    
    func getPodcastDetails(podcastID: String) async throws -> PodcastSearchResult {
        let endpoint = "/podcasts/\(podcastID)"
        let urlString = apiKey.isEmpty ?
            "https://listen-api-test.listennotes.com/api/v2\(endpoint)" :
            "\(baseURL)\(endpoint)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-ListenAPI-Key")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(PodcastSearchResult.self, from: data)
    }
}
