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
    var isPlayed: Bool  // Marked as played when within 1 minute of end
    
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
