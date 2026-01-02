import SwiftUI

struct PodcastItemView: View {
    let episode: Episode
    let podcastTitle: String?
    let podcastImageURL: URL?
    var isPlaying: Bool = false
    var isDownloaded: Bool = false
    var isDownloading: Bool = false
    var downloadProgress: Double = 0
    var onTap: (() -> Void)? = nil
    var trailingContent: (() -> AnyView)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: episode.imageURL ?? podcastImageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: isPlaying ? "waveform" : "mic.fill")
                            .foregroundColor(isPlaying ? .blue : .gray)
                    )
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(isPlaying ? .blue : .primary)
                
                if let podcastTitle = podcastTitle {
                    Text(podcastTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    if isDownloading {
                        ProgressView(value: downloadProgress)
                            .frame(width: 80)
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
            
            if let trailingContent = trailingContent {
                trailingContent()
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
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
