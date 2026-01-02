import SwiftUI

struct EpisodeListView: View {
    let podcast: Podcast
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        List(podcast.episodes) { episode in
            PodcastItemView(
                podcast: nil,
                episode: episode,
                style: .compact
            )
        }
        .navigationTitle(podcast.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}


struct PlayerControlsView: View {
    @ObservedObject var audioPlayer: AudioPlayerService
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 12) {
                if let episode = audioPlayer.currentEpisode {
                    HStack(spacing: 12) {
                        AsyncImage(url: episode.imageURL) { image in
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
                        .frame(width: 50, height: 50)
                        .cornerRadius(6)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(episode.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            
                            HStack(spacing: 4) {
                                Text(formatTime(audioPlayer.currentTime))
                                Text("/")
                                Text(formatTime(audioPlayer.duration))
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
                
                Slider(value: Binding(
                    get: { audioPlayer.currentTime },
                    set: { audioPlayer.debouncedSeek(to: $0) }
                ), in: 0...max(audioPlayer.duration, 1))
                    .padding(.horizontal)
                
                HStack(spacing: 40) {
                    Button(action: { audioPlayer.skipBackward() }) {
                        Image(systemName: "gobackward.15")
                            .font(.title2)
                    }
                    
                    Button(action: { audioPlayer.togglePlayPause() }) {
                        Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 50))
                    }
                    
                    Button(action: { audioPlayer.skipForward() }) {
                        Image(systemName: "goforward.15")
                            .font(.title2)
                    }
                }
                .padding(.bottom, 12)
            }
            .background(Color(UIColor.systemBackground))
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

