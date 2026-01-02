import SwiftUI

@main
@available(iOS 26.0, *)
struct GardenManagerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @StateObject private var audioPlayer = AudioPlayerService()
    @StateObject private var downloadManager = DownloadManager()
    @StateObject private var podcastViewModel = PodcastListViewModel()
    
    var body: some View {
        TabView {
            VStack(spacing: 0) {
                PodcastListView()
                    .environmentObject(audioPlayer)
                    .environmentObject(downloadManager)
                    .environmentObject(podcastViewModel)
                
                MiniPlayerView()
                    .environmentObject(audioPlayer)
            }
            .tabItem {
                Label("Podcasts", systemImage: "mic.fill")
            }
            
            VStack(spacing: 0) {
                DownloadsView()
                    .environmentObject(audioPlayer)
                    .environmentObject(downloadManager)
                    .environmentObject(podcastViewModel)
                
                MiniPlayerView()
                    .environmentObject(audioPlayer)
            }
            .tabItem {
                Label("Downloads", systemImage: "arrow.down.circle")
            }
        }
    }
}
