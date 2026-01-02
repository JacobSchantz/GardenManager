import SwiftUI

struct RootView: View {
    @StateObject private var audioPlayer = AudioPlayerService()
    
    var body: some View {
        VStack(spacing: 0) {
            PodcastListView()
                .environmentObject(audioPlayer)
            
            MiniPlayerView()
                .environmentObject(audioPlayer)
        }
    }
}
