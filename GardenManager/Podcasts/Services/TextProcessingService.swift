import Foundation

@MainActor
class TextProcessingService: ObservableObject {
    private let podcastSearchService = PodcastSearchService()
    
    func extractPodcastNames(from textLines: [String]) async -> [String] {
        // Filter out very short lines (likely not podcast names)
        let filteredLines = textLines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count >= 3 && trimmed.count <= 100
        }
        
        // Remove common non-podcast text patterns
        let podcastCandidates = filteredLines.filter { line in
            !isLikelyNonPodcastText(line)
        }
        
        // Remove duplicates while preserving order
        var seen = Set<String>()
        let uniqueCandidates = podcastCandidates.filter { candidate in
            let lowercased = candidate.lowercased()
            if seen.contains(lowercased) {
                return false
            }
            seen.insert(lowercased)
            return true
        }
        
        return uniqueCandidates
    }
    
    func findMatchingPodcasts(for podcastNames: [String], progressHandler: @escaping @Sendable (Int, Int) -> Void) async -> [(name: String, podcast: Podcast?)] {
        var results: [(String, Podcast?)] = []
        
        for (index, name) in podcastNames.enumerated() {
            progressHandler(index, podcastNames.count)
            
            // Search for podcasts
            await podcastSearchService.search(query: name)
            
            // Take the best match (first result if available)
            if let firstResult = podcastSearchService.results.first,
               let feedUrlString = firstResult.feedUrl,
               let feedUrl = URL(string: feedUrlString) {
                let podcast = Podcast(
                    id: UUID(),
                    title: firstResult.trackName,
                    author: firstResult.artistName,
                    description: "",
                    imageURL: firstResult.artworkUrl600.flatMap { URL(string: $0) },
                    feedURL: feedUrl,
                    episodes: []
                )
                results.append((name, podcast))
            } else {
                results.append((name, nil))
            }
        }
        
        return results
    }
    
    private func isLikelyNonPodcastText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Common patterns that are unlikely to be podcast names
        let nonPodcastPatterns = [
            "^\\d+$",                    // Just numbers
            "^\\d+:\\d+",               // Time formats
            "^https?://",               // URLs
            "^www\\.",                  // Web addresses
            "episode",                  // Episode mentions
            "season",                   // Season mentions
            "subscribe",                // Subscription text
            "download",                 // Download text
            "listen",                   // Listen text
            "podcast",                  // Generic podcast text
            "by ",                      // Attribution patterns
            "with ",                    // Guest patterns
            "feat\\.",                  // Featuring
            "ft\\.",                    // Featuring abbreviation
            "part \\d+",               // Part numbers
            "chapter \\d+",            // Chapter numbers
            "^\\s*$",                   // Empty lines
            "^[-=+*•]$",               // Just symbols
            "minutes?",                // Duration text
            "hours?",                  // Duration text
            "seconds?",                // Duration text
        ]
        
        for pattern in nonPodcastPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                if regex.firstMatch(in: lowercased, options: [], range: NSRange(location: 0, length: lowercased.count)) != nil {
                    return true
                }
            }
        }
        
        return false
    }
}

