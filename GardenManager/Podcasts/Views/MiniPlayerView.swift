import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @State private var showFullPlayer = false
    
    var body: some View {
        if let episode = audioPlayer.currentEpisode {
            VStack(spacing: 0) {
                Divider()
                
                Button(action: {
                    showFullPlayer = true
                }) {
                    HStack(spacing: 12) {
                        CachedAsyncImage(
                            url: episode.displayImageURL,
                            localURL: episode.localImageURL
                        ) {
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
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 4) {
                                Text(formatTime(audioPlayer.currentTime))
                                Text("/")
                                Text(formatTime(audioPlayer.duration))
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { audioPlayer.togglePlayPause() }) {
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(Color(UIColor.systemBackground))
            .sheet(isPresented: $showFullPlayer) {
                FullPlayerView()
                    .environmentObject(audioPlayer)
            }
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

struct FullPlayerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                    
                    if let episode = audioPlayer.currentEpisode {
                        CachedAsyncImage(
                            url: episode.displayImageURL,
                            localURL: episode.localImageURL
                        ) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                )
                        }
                        .frame(width: 300, height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                        
                        Text(episode.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal)
                    }
                    
                    // Controls
                    VStack(spacing: 8) {
                        Slider(value: Binding(
                            get: { audioPlayer.currentTime },
                            set: { audioPlayer.debouncedSeek(to: $0) }
                        ), in: 0...max(audioPlayer.duration, 1))
                            .padding(.horizontal)
                        
                        HStack {
                            Text(formatTime(audioPlayer.currentTime))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatTime(audioPlayer.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    
                    HStack(spacing: 60) {
                        Button(action: { audioPlayer.skipBackward() }) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 32))
                        }
                        
                        Button(action: { audioPlayer.togglePlayPause() }) {
                            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 70))
                        }
                        
                        Button(action: { audioPlayer.skipForward() }) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 32))
                        }
                    }
                    
                    // Description - below controls, scrollable
                    if let episode = audioPlayer.currentEpisode {
                        let cleanDescription = episode.description
                            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        
                        Text(cleanDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal)
                            .padding(.top, 16)
                    }
                    
                    Spacer()
                }
                .padding()
            }
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
