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
            OpenClawVoiceView()
            .tabItem {
                Label("Voice", systemImage: "phone.fill")
            }

            GrokVoiceView()
            .tabItem {
                Label("Grok", systemImage: "waveform")
            }

            LocalAITabView()
            .tabItem {
                Label("Local AI", systemImage: "cpu")
            }

            PersonActionTabView()
            .tabItem {
                Label("Action", systemImage: "figure.walk")
            }

            BuildStatusTabView()
            .tabItem {
                Label("Builds", systemImage: "hammer")
            }
        }

        .tint(.blue)
    }
} 




#Preview("GrokVoiceView") {
    RootView()
}

//#Preview("SettingsSheet") {
//    SettingsSheet(
//        apiKey: .constant("test-api-key"),
//        service: GrokVoiceService()
//    )
//}
