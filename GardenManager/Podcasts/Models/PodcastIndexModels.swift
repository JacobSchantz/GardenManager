import Foundation

// PodcastIndex API Response Models

struct PodcastIndexSearchResponse: Codable {
    let status: String
    let feeds: [PodcastIndexPodcast]
    let count: Int
    let query: String?
    let description: String?
}

struct PodcastIndexPodcast: Identifiable, Codable {
    let id: Int
    let title: String
    let url: String
    let originalUrl: String?
    let link: String?
    let description: String?
    let author: String?
    let ownerName: String?
    let image: String?
    let artwork: String?
    let lastUpdateTime: Int?
    let lastCrawlTime: Int?
    let lastParseTime: Int?
    let lastGoodHttpStatusTime: Int?
    let lastHttpStatus: Int?
    let contentType: String?
    let itunesId: Int?
    let generator: String?
    let language: String?
    let type: Int?
    let dead: Int?
    let crawlErrors: Int?
    let parseErrors: Int?
    let categories: [String: String]?
    let locked: Int?
    let imageUrlHash: Int?
    let value: PodcastIndexValue?
    let funding: PodcastIndexFunding?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case originalUrl = "originalUrl"
        case link
        case description
        case author
        case ownerName
        case image
        case artwork
        case lastUpdateTime
        case lastCrawlTime
        case lastParseTime
        case lastGoodHttpStatusTime
        case lastHttpStatus
        case contentType
        case itunesId
        case generator
        case language
        case type
        case dead
        case crawlErrors
        case parseErrors
        case categories
        case locked
        case imageUrlHash
        case value
        case funding
    }

    var rssURL: String {
        return originalUrl ?? url
    }

    var displayTitle: String {
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayAuthor: String {
        return author?.trimmingCharacters(in: .whitespacesAndNewlines) ??
               ownerName?.trimmingCharacters(in: .whitespacesAndNewlines) ??
               "Unknown Author"
    }

    var imageURL: URL? {
        if let image = image {
            return URL(string: image)
        }
        if let artwork = artwork {
            return URL(string: artwork)
        }
        return nil
    }
}

struct PodcastIndexValue: Codable {
    let model: PodcastIndexValueModel
    let destinations: [PodcastIndexValueDestination]
}

struct PodcastIndexValueModel: Codable {
    let type: String
    let method: String
    let suggested: String
}

struct PodcastIndexValueDestination: Codable {
    let name: String
    let type: String
    let address: String
    let split: Int?
}

struct PodcastIndexFunding: Codable {
    let url: String
    let message: String?
}

struct PodcastIndexPodcastResponse: Codable {
    let status: String
    let feed: PodcastIndexPodcast
    let description: String?
    let items: [PodcastIndexEpisode]?
}

struct PodcastIndexEpisode: Codable {
    let id: Int
    let title: String
    let link: String?
    let description: String?
    let guid: String?
    let datePublished: Int?
    let datePublishedPretty: String?
    let dateCrawled: Int?
    let enclosureUrl: String?
    let enclosureType: String?
    let enclosureLength: Int?
    let duration: Int?
    let explicit: Int?
    let episode: Int?
    let episodeType: String?
    let season: Int?
    let image: String?
    let feedItunesId: Int?
    let feedImage: String?
    let feedId: Int
    let feedLanguage: String?
    let feedDead: Int?
    let feedDuplicateOf: Int?
    let chaptersUrl: String?
    let transcriptUrl: String?
    let soundbite: PodcastIndexSoundbite?
}

struct PodcastIndexSoundbite: Codable {
    let startTime: Int
    let duration: Int
    let title: String?
}

// Conversion extensions to work with existing Podcast model
extension PodcastIndexPodcast {
    func toPodcast() -> Podcast {
        return Podcast(
            title: displayTitle,
            author: displayAuthor,
            description: description ?? "No description available",
            imageURL: imageURL,
            feedURL: URL(string: rssURL)!,
            episodes: [] // Episodes will be loaded separately if needed
        )
    }
}
