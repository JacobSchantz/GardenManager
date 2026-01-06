import Foundation
import CommonCrypto

actor PodcastSearchService {
    private let baseURL = "https://api.podcastindex.org/api/1.0"
    private let apiKey: String
    private let apiSecret: String
    
    init(apiKey: String = "", apiSecret: String = "") {
        // For now, we'll use test/demo mode if no keys are provided
        // In production, this should come from secure configuration
        self.apiKey = apiKey.isEmpty ? "" : apiKey
        self.apiSecret = apiSecret.isEmpty ? "" : apiSecret
    }
    
    func searchPodcasts(query: String, offset: Int = 0, limit: Int = 20) async throws -> PodcastIndexSearchResponse {
        let endpoint = "/search/byterm"
        guard let url = URL(string: baseURL + endpoint) else {
            throw URLError(.badURL)
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "max", value: String(limit))
        ]
        
        guard let finalURL = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add authentication headers if we have API keys
        if !apiKey.isEmpty && !apiSecret.isEmpty {
            let unixTime = String(Int(Date().timeIntervalSince1970))
            let authString = apiKey + apiSecret + unixTime
            let authHash = sha1Hash(authString)
            
            request.setValue("GardenManager/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue(unixTime, forHTTPHeaderField: "X-Auth-Date")
            request.setValue(apiKey, forHTTPHeaderField: "X-Auth-Key")
            request.setValue(authHash, forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // PodcastIndex returns 200 even for no results, so we just check for success range
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(PodcastIndexSearchResponse.self, from: data)
    }
    
    func getPodcastDetails(podcastID: String) async throws -> PodcastIndexPodcast {
        let endpoint = "/podcasts/byfeedid"
        guard let url = URL(string: baseURL + endpoint) else {
            throw URLError(.badURL)
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "id", value: podcastID)
        ]
        
        guard let finalURL = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if !apiKey.isEmpty && !apiSecret.isEmpty {
            let unixTime = String(Int(Date().timeIntervalSince1970))
            let authString = apiKey + apiSecret + unixTime
            let authHash = sha1Hash(authString)
            
            request.setValue("GardenManager/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue(unixTime, forHTTPHeaderField: "X-Auth-Date")
            request.setValue(apiKey, forHTTPHeaderField: "X-Auth-Key")
            request.setValue(authHash, forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(PodcastIndexPodcastResponse.self, from: data).feed
    }
    
    private func sha1Hash(_ input: String) -> String {
        let data = Data(input.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA1(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
