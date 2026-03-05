import Foundation

struct Podcast: Identifiable, Codable {
    let id: UUID
    var title: String
    var author: String
    var description: String
    var imageURL: URL?
    var feedURL: URL
    var episodes: [Episode]
    
    init(id: UUID = UUID(), title: String, author: String, description: String, imageURL: URL?, feedURL: URL, episodes: [Episode] = []) {
        self.id = id
        self.title = title
        self.author = author
        self.description = description
        self.imageURL = imageURL
        self.feedURL = feedURL
        self.episodes = episodes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case description
        case imageURL
        case feedURL
        case episodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        feedURL = try container.decode(URL.self, forKey: .feedURL)
        episodes = try container.decodeIfPresent([Episode].self, forKey: .episodes) ?? []
    }
}

struct Episode: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var audioURL: URL
    var duration: TimeInterval
    var publishDate: Date
    var imageURL: URL?
    var podcastImageURL: URL?  // Fallback image from parent podcast
    var isDownloaded: Bool
    var localFileURL: URL?
    var downloadProgress: Double
    var isPlayed: Bool  // Marked as played when within 2 minutes of end
    
    init(id: UUID = UUID(), title: String, description: String, audioURL: URL, duration: TimeInterval = 0, publishDate: Date, imageURL: URL? = nil, podcastImageURL: URL? = nil, isDownloaded: Bool = false, localFileURL: URL? = nil, downloadProgress: Double = 0, isPlayed: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.audioURL = audioURL
        self.duration = duration
        self.publishDate = publishDate
        self.imageURL = imageURL
        self.podcastImageURL = podcastImageURL
        self.isDownloaded = isDownloaded
        self.localFileURL = localFileURL
        self.downloadProgress = downloadProgress
        self.isPlayed = isPlayed
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case audioURL
        case duration
        case publishDate
        case imageURL
        case podcastImageURL
        case isDownloaded
        case localFileURL
        case downloadProgress
        case isPlayed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        audioURL = try container.decode(URL.self, forKey: .audioURL)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        publishDate = try container.decodeIfPresent(Date.self, forKey: .publishDate) ?? Date()
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        podcastImageURL = try container.decodeIfPresent(URL.self, forKey: .podcastImageURL)
        isDownloaded = try container.decodeIfPresent(Bool.self, forKey: .isDownloaded) ?? false
        localFileURL = try container.decodeIfPresent(URL.self, forKey: .localFileURL)
        downloadProgress = try container.decodeIfPresent(Double.self, forKey: .downloadProgress) ?? 0
        isPlayed = try container.decodeIfPresent(Bool.self, forKey: .isPlayed) ?? false
    }
    
    // Computed property for display - episode image with podcast fallback
    var displayImageURL: URL? {
        imageURL ?? podcastImageURL
    }
    
    // Local image URL if episode is downloaded
    var localImageURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagePath = documentsPath.appendingPathComponent("Downloads").appendingPathComponent("\(id.uuidString).jpg")
        return FileManager.default.fileExists(atPath: imagePath.path) ? imagePath : nil
    }
}
