import SwiftUI

struct EpisodeListView: View {
    let podcast: Podcast
    @StateObject private var audioPlayer = AudioPlayerService()
    
    var body: some View {
        VStack(spacing: 0) {
            List(podcast.episodes) { episode in
                Button(action: {
                    audioPlayer.play(episode: episode)
                }) {
                    EpisodeRow(episode: episode, isPlaying: audioPlayer.currentEpisode?.id == episode.id && audioPlayer.isPlaying)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if audioPlayer.currentEpisode != nil {
                PlayerControlsView(audioPlayer: audioPlayer)
            }
        }
        .navigationTitle(podcast.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EpisodeRow: View {
    let episode: Episode
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: episode.imageURL) { image in
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
            .frame(width: 50, height: 50)
            .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(isPlaying ? .blue : .primary)
                
                Text(episode.publishDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if episode.duration > 0 {
                    Text(formatDuration(episode.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
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
                    set: { audioPlayer.seek(to: $0) }
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
