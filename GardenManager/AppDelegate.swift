import UIKit
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        configureAudioSession()
        application.beginReceivingRemoteControlEvents()
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        reactivateAudioSessionIfNeeded()
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.setActive(true, options: [])
            print("[AppDelegate] Audio session configured for background playback")
        } catch {
            print("[AppDelegate] Failed to configure audio session: \(error)")
        }
    }
    
    private func reactivateAudioSessionIfNeeded() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true, options: [])
                print("[AppDelegate] Audio session reactivated")
            }
        } catch {
            print("[AppDelegate] Failed to reactivate audio session: \(error)")
        }
    }
}
