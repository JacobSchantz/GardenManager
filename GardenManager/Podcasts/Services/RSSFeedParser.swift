import Foundation

class RSSFeedParser: NSObject, XMLParserDelegate {
    private var podcast: Podcast?
    private var episodes: [Episode] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentAudioURL: URL?
    private var currentPubDate: Date?
    private var currentImageURL: URL?
    private var currentDuration: TimeInterval = 0
    private var podcastTitle = ""
    private var podcastAuthor = ""
    private var podcastDescription = ""
    private var podcastImageURL: URL?
    private var isInItem = false
    private var isInImage = false
    private var currentImageURLString = ""
    private let feedURL: URL
    
    init(feedURL: URL) {
        self.feedURL = feedURL
    }
    
    func parse() async throws -> Podcast {
        let (data, _) = try await URLSession.shared.data(from: feedURL)
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        if parser.parse() {
            return Podcast(
                title: podcastTitle,
                author: podcastAuthor,
                description: podcastDescription,
                imageURL: podcastImageURL,
                feedURL: feedURL,
                episodes: episodes
            )
        } else {
            throw NSError(domain: "RSSFeedParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse RSS feed"])
        }
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "item" {
            isInItem = true
            currentTitle = ""
            currentDescription = ""
            currentAudioURL = nil
            currentPubDate = nil
            currentImageURL = nil
            currentDuration = 0
        }
        
        // Handle <image><url> structure (non-itunes feeds)
        if elementName == "image" && !isInItem {
            isInImage = true
            currentImageURLString = ""
        }
        
        if elementName == "enclosure" {
            if let urlString = attributeDict["url"], let url = URL(string: urlString) {
                currentAudioURL = url
            }
        }
        
        // Handle itunes:image with href attribute
        if elementName == "itunes:image" {
            if let urlString = attributeDict["href"], let url = URL(string: urlString) {
                if isInItem {
                    currentImageURL = url
                } else {
                    podcastImageURL = url
                }
            }
        }
        
        // Handle standard RSS <image> with url attribute
        if elementName == "image" {
            if let urlString = attributeDict["url"], let url = URL(string: urlString) {
                if isInItem {
                    currentImageURL = url
                } else {
                    podcastImageURL = url
                }
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Handle <image><url>text</url></image> structure
        if isInImage && currentElement == "url" {
            currentImageURLString += trimmed
            return
        }
        
        switch currentElement {
        case "title":
            if isInItem {
                currentTitle += trimmed
            } else {
                podcastTitle += trimmed
            }
        case "description", "itunes:summary":
            if isInItem {
                currentDescription += trimmed
            } else {
                podcastDescription += trimmed
            }
        case "itunes:author", "author":
            if !isInItem {
                podcastAuthor += trimmed
            }
        case "pubDate":
            if isInItem {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                if let date = dateFormatter.date(from: trimmed) {
                    currentPubDate = date
                } else {
                    // Try alternative format
                    dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                    if let date = dateFormatter.date(from: trimmed) {
                        currentPubDate = date
                    }
                }
            }
        case "itunes:duration":
            if isInItem {
                if let duration = TimeInterval(trimmed) {
                    currentDuration = duration
                } else {
                    let components = trimmed.split(separator: ":")
                    if components.count == 3 {
                        let hours = Double(components[0]) ?? 0
                        let minutes = Double(components[1]) ?? 0
                        let seconds = Double(components[2]) ?? 0
                        currentDuration = hours * 3600 + minutes * 60 + seconds
                    } else if components.count == 2 {
                        let minutes = Double(components[0]) ?? 0
                        let seconds = Double(components[1]) ?? 0
                        currentDuration = minutes * 60 + seconds
                    }
                }
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        // Handle closing of <image><url> structure
        if elementName == "image" && isInImage {
            isInImage = false
            if !currentImageURLString.isEmpty, let url = URL(string: currentImageURLString) {
                if !isInItem {
                    podcastImageURL = url
                }
            }
            currentImageURLString = ""
        }
        
        if elementName == "item" {
            isInItem = false
            if let audioURL = currentAudioURL {
                // Use episode image if available, otherwise fallback to podcast image
                let episodeImageURL = currentImageURL ?? podcastImageURL
                let episode = Episode(
                    title: currentTitle,
                    description: currentDescription,
                    audioURL: audioURL,
                    duration: currentDuration,
                    publishDate: currentPubDate ?? Date(),
                    imageURL: episodeImageURL
                )
                episodes.append(episode)
            }
        }
    }
}