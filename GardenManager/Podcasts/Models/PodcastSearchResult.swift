import Foundation

struct PodcastSearchResult: Identifiable, Codable {
    let id: String
    let title: String
    let publisher: String
    let image: String?
    let thumbnail: String?
    let listennotesURL: String?
    let totalEpisodes: Int
    let explicitContent: Bool
    let description: String?
    let itunesID: Int?
    let rss: String
    let latestPubDateMs: Int?
    let earliestPubDateMs: Int?
    let language: String
    let country: String
    let website: String?
    let isClaimed: Bool
    let type: String
    let genreIds: [Int]
    let email: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case publisher
        case image
        case thumbnail
        case listennotesURL = "listennotes_url"
        case totalEpisodes = "total_episodes"
        case explicitContent = "explicit_content"
        case description
        case itunesID = "itunes_id"
        case rss
        case latestPubDateMs = "latest_pub_date_ms"
        case earliestPubDateMs = "earliest_pub_date_ms"
        case language
        case country
        case website
        case isClaimed = "is_claimed"
        case type
        case genreIds = "genre_ids"
        case email
    }
}

struct PodcastSearchResponse: Codable {
    let took: Double
    let count: Int
    let total: Int
    let results: [PodcastSearchResult]
    let nextOffset: Int?
    
    enum CodingKeys: String, CodingKey {
        case took
        case count
        case total
        case results
        case nextOffset = "next_offset"
    }
}
