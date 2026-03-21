import SwiftUI

@main
@available(iOS 26.0, *)
@MainActor
struct GardenManagerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

@MainActor
struct RootView: View {
    var body: some View {
        TabView {
            GrokVoiceView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem {
                Label("Grok", systemImage: "waveform")
            }

            Text("AI Coming Soon")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem {
                Label("AI", systemImage: "sparkles")
            }
        }

        .tint(.blue)
    }
} 
