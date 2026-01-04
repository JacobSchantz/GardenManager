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
                        ForEach(downloadingEpisodes, id: \.episode.id) { item in
                            PodcastItemView(
                                podcast: item.podcast,
                                episode: item.episode,
                                showCancelButton: true
                            )
                        }
                        .onDelete(perform: deleteDownloadingEpisodes)
                    }
                    
                    if !downloadedEpisodes.isEmpty {
                        ForEach(downloadedEpisodes, id: \.episode.id) { item in
                            PodcastItemView(
                                podcast: item.podcast,
                                episode: item.episode,
                            )
                        }
                        .onDelete(perform: deleteDownloadedEpisodes)
                    }
                }
            }
            .navigationTitle("Downloads")
        }
    }

    private func deleteDownloadingEpisodes(at offsets: IndexSet) {
        let itemsToDelete = offsets.compactMap { idx in
            downloadingEpisodes.indices.contains(idx) ? downloadingEpisodes[idx] : nil
        }

        for item in itemsToDelete {
            downloadManager.cancelDownload(item.episode)
            downloadManager.deleteDownload(item.episode)
            if audioPlayer.currentEpisode?.id == item.episode.id {
                audioPlayer.pause()
            }
            podcastViewModel.deleteEpisode(podcastID: item.podcast.id, episodeID: item.episode.id)
        }
    }

    private func deleteDownloadedEpisodes(at offsets: IndexSet) {
        let itemsToDelete = offsets.compactMap { idx in
            downloadedEpisodes.indices.contains(idx) ? downloadedEpisodes[idx] : nil
        }

        for item in itemsToDelete {
            downloadManager.cancelDownload(item.episode)
            downloadManager.deleteDownload(item.episode)
            if audioPlayer.currentEpisode?.id == item.episode.id {
                audioPlayer.pause()
            }
            podcastViewModel.deleteEpisode(podcastID: item.podcast.id, episodeID: item.episode.id)
        }
    }
}

