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
    
    init(id: UUID = UUID(), title: String, description: String, audioURL: URL, duration: TimeInterval = 0, publishDate: Date, imageURL: URL? = nil, podcastImageURL: URL? = nil, isDownloaded: Bool = false, localFileURL: URL? = nil, downloadProgress: Double = 0) {
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
    }
    
    // Computed property for display - episode image with podcast fallback
    var displayImageURL: URL? {
        imageURL ?? podcastImageURL
    }
}
