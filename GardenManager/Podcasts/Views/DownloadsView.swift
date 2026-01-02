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
                                DownloadingEpisodeRow(
                                    podcast: item.podcast,
                                    episode: item.episode
                                )
                            }
                        }
                    }
                    
                    if !downloadedEpisodes.isEmpty {
                        Section("Downloaded") {
                            ForEach(downloadedEpisodes, id: \.episode.id) { item in
                                DownloadedEpisodeRow(
                                    podcast: item.podcast,
                                    episode: item.episode
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

struct DownloadedEpisodeRow: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var audioPlayer: AudioPlayerService
    let podcast: Podcast
    let episode: Episode
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: episode.imageURL ?? podcast.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "mic.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(podcast.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Downloaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Menu {
                Button(action: {
                    if let localURL = downloadManager.getLocalURL(for: episode) {
                        var localEpisode = episode
                        localEpisode.localFileURL = localURL
                        audioPlayer.play(episode: localEpisode)
                    }
                }) {
                    Label("Play", systemImage: "play.fill")
                }
                
                Button(role: .destructive, action: {
                    downloadManager.deleteDownload(episode)
                }) {
                    Label("Delete Download", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DownloadingEpisodeRow: View {
    @EnvironmentObject var downloadManager: DownloadManager
    let podcast: Podcast
    let episode: Episode
    
    var progress: Double {
        downloadManager.downloadingEpisodes[episode.id] ?? 0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: episode.imageURL ?? podcast.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "mic.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(podcast.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .frame(width: 100)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                downloadManager.cancelDownload(episode)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}
