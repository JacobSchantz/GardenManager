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
    @StateObject private var motionTracker = MotionTracker()
    @StateObject private var motionCoordinator: MotionAudioCoordinator
    
    init() {
        let motionTracker = MotionTracker()
        let audioPlayer = AudioPlayerService()
        _motionTracker = StateObject(wrappedValue: motionTracker)
        _audioPlayer = StateObject(wrappedValue: audioPlayer)
        _motionCoordinator = StateObject(wrappedValue: MotionAudioCoordinator(motionTracker: motionTracker, audioPlayerService: audioPlayer))
        _downloadManager = StateObject(wrappedValue: DownloadManager())
        _podcastViewModel = StateObject(wrappedValue: PodcastListViewModel())
    }
    
    var body: some View {
        TabView {
            VStack(spacing: 0) {
                PodcastListView()
                    .environmentObject(audioPlayer)
                    .environmentObject(downloadManager)
                    .environmentObject(podcastViewModel)
                     .environmentObject(motionTracker)
                
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
                     .environmentObject(motionTracker)
                
                MiniPlayerView()
                    .environmentObject(audioPlayer)
            }
            .tabItem {
                Label("Downloads", systemImage: "arrow.down.circle")
            }

             MotionStatusView()
                 .environmentObject(motionTracker)
                 .tabItem {
                     Label("Motion", systemImage: "figure.walk")
                 }
        }
        .onReceive(podcastViewModel.$podcasts) { podcasts in
            audioPlayer.restoreLastPlayedEpisode(
                podcasts: podcasts,
                resolveLocalURL: { episode in
                    downloadManager.getLocalURL(for: episode)
                }
            )
        }
    }
}
