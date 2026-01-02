import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @EnvironmentObject var podcastViewModel: PodcastListViewModel
    
    var downloadingEpisodes: [(podcast: Podcast, episode: Episode)] {
        var result: [(Podcast, Episode)] = []
        for podcast in podcastViewModel.podcasts {
            for episode in podcast.episodes {
                if downloadManager.downloadingEpisodes[episode.id] != nil {
                    result.append((podcast, episode))
                }
            }
        }
        return result
    }
    
    var downloadedEpisodes: [(podcast: Podcast, episode: Episode)] {
        var result: [(Podcast, Episode)] = []
        for podcast in podcastViewModel.podcasts {
            for episode in podcast.episodes {
                if downloadManager.isDownloaded(episode) {
                    result.append((podcast, episode))
                }
            }
        }
        return result.sorted { (a: (podcast: Podcast, episode: Episode), b: (podcast: Podcast, episode: Episode)) in
            a.episode.publishDate > b.episode.publishDate
        }
    }
    
    var hasContent: Bool {
        !downloadingEpisodes.isEmpty || !downloadedEpisodes.isEmpty
    }
    
    var body: some View {
        NavigationView {
            List {
                if !hasContent {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Downloaded Episodes")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Download episodes to listen offline")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    if !downloadingEpisodes.isEmpty {
                        Section("Downloading") {
                            ForEach(downloadingEpisodes, id: \.episode.id) { item in
                                PodcastItemView(
                                    podcast: item.podcast,
                                    episode: item.episode,
                                    showCancelButton: true
                                )
                            }
                        }
                    }
                    
                    if !downloadedEpisodes.isEmpty {
                        Section("Downloaded") {
                            ForEach(downloadedEpisodes, id: \.episode.id) { item in
                                PodcastItemView(
                                    podcast: item.podcast,
                                    episode: item.episode,
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
        }
    }
}

