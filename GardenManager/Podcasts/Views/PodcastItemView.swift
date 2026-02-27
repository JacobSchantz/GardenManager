import SwiftUI
import UIKit

enum EpisodeRowStyle {
    case standard
    case compact
}

enum ItemOptionsType {
    case podcast(Podcast)
    case episode(Episode, Podcast?)
}

struct PodcastItemView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @EnvironmentObject var downloadManager: DownloadManager
    
    let podcast: Podcast?
    let episode: Episode
    var style: EpisodeRowStyle = .standard
    var showDownloadButton: Bool = true
    var showCancelButton: Bool = false
    
    @State private var showEpisodeOptions = false
    
    private var imageSize: CGFloat {
        style == .compact ? 50 : 60
    }
    
    private var cornerRadius: CGFloat {
        style == .compact ? 6 : 8
    }
    
    private var isPlaying: Bool {
        audioPlayer.currentEpisode?.id == episode.id && audioPlayer.isPlaying
    }
    
    private var isDownloaded: Bool {
        downloadManager.isDownloaded(episode)
    }
    
    private var isDownloading: Bool {
        downloadManager.downloadingEpisodes[episode.id] != nil
    }
    
    private var downloadProgress: Double {
        downloadManager.downloadingEpisodes[episode.id] ?? 0
    }
    
    // Image URL with multiple fallbacks: episode image -> episode podcastImageURL -> podcast.imageURL
    private var resolvedImageURL: URL? {
        episode.imageURL ?? episode.podcastImageURL ?? podcast?.imageURL
    }
    
    private func handleTap() {
        print("[PodcastItemView] Tapped episode: \(episode.title), isDownloaded: \(isDownloaded)")
        
        if isDownloaded, let localURL = downloadManager.getLocalURL(for: episode) {
            print("[PodcastItemView] Playing from local URL: \(localURL)")
            var localEpisode = episode
            localEpisode.localFileURL = localURL
            audioPlayer.play(episode: localEpisode)
        } else {
            print("[PodcastItemView] Playing from remote URL: \(episode.audioURL)")
            audioPlayer.play(episode: episode)
        }
    }
    
    private func handleDownload() {
        downloadManager.downloadEpisode(episode)
    }
    
    private func handleDelete() {
        downloadManager.deleteDownload(episode)
    }
    
    private func handleCancel() {
        downloadManager.cancelDownload(episode)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(
                url: resolvedImageURL,
                localURL: episode.localImageURL
            ) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: isPlaying ? "waveform" : "mic.fill")
                            .foregroundColor(isPlaying ? .blue : .gray)
                    )
            }
            .frame(width: imageSize, height: imageSize)
            .cornerRadius(cornerRadius)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(isPlaying ? .blue : .primary)
                
                if let podcast = podcast {
                    Text(podcast.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    if isDownloading {
                        ProgressView(value: downloadProgress)
                            .frame(width: style == .compact ? 100 : 80)
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Downloaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(episode.publishDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if episode.duration > 0 {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(formatDuration(episode.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
            }
            
            if showCancelButton {
                Button(action: handleCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
        
            }
            DownloadButtonView(
                isDownloaded: isDownloaded,
                isDownloading: isDownloading,
                downloadProgress: downloadProgress,
                onDownload: handleDownload
            )
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        .onLongPressGesture {
            showEpisodeOptions = true
        }
        .sheet(isPresented: $showEpisodeOptions) {
            ItemOptionsSheet(
                type: .episode(episode, podcast)
            )
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct DownloadButtonView: View {
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onDownload: (() -> Void)?
    
    var body: some View {
        Group {
            if isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            } else if isDownloading {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .trim(from: 0, to: downloadProgress)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                }
            } else {
                Button(action: {
                    onDownload?()
                }) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct EpisodeOptionsSheet: View {
    let episode: Episode
    let podcast: Podcast?
    
    @Environment(\.dismiss) var dismiss
    @State private var showCopied = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: copyEpisodeURL) {
                        Label(showCopied ? "Copied!" : "Copy Episode URL", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                    }
                    
                    Button(action: copyAudioURL) {
                        Label("Copy Audio URL", systemImage: "doc.on.doc")
                    }
                    
                    if let podcast = podcast {
                        Button(action: copyPodcastURL) {
                            Label("Copy Podcast RSS", systemImage: "doc.on.doc")
                        }
                    }
                }
                
                Section {
                    ShareLink(item: episode.audioURL) {
                        Label("Share Episode", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle(episode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func copyEpisodeURL() {
        UIPasteboard.general.string = episode.audioURL.absoluteString
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }
    
    private func copyAudioURL() {
        UIPasteboard.general.string = episode.audioURL.absoluteString
    }
    
    private func copyPodcastURL() {
        if let podcast = podcast {
            UIPasteboard.general.string = podcast.feedURL.absoluteString
        }
    }
}
