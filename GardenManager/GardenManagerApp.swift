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

            UnifiedChatView()
            .tabItem {
                Label("Chat", systemImage: "message.fill")
            }

            BuildStatusTabView()
            .tabItem {
                Label("Builds", systemImage: "hammer")
            }

            BeadsView()
            .tabItem {
                Label("Beads", systemImage: "circle.grid.3")
            }

            AccountTabView()
            .tabItem {
                Label("Account", systemImage: "person.fill")
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

// MARK: - Account Tab

struct AccountTabView: View {
    @State private var isPurchasing = false
    @State private var showPurchaseAlert = false
    @State private var purchaseMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Account header
                    accountHeader

                    Divider()

                    // Subscription status
                    subscriptionSection

                    Divider()

                    // Buy a habit
                    buyHabitSection

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Account")
            .alert("Purchase", isPresented: $showPurchaseAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseMessage)
            }
        }
    }

    private var accountHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("GardenManager Account")
                .font(.title2.weight(.semibold))

            Text("Manage your subscription and habits")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Subscription", systemImage: "star.fill")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Free")
                        .font(.title3.weight(.semibold))
                }

                Spacer()

                Button("Upgrade") {
                    purchaseMessage = "Upgrade to Premium to unlock unlimited habits and advanced features!"
                    showPurchaseAlert = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var buyHabitSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Buy a Habit", systemImage: "leaf.fill")
                .font(.headline)

            Text("Purchase new habits to build better routines")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                HabitPurchaseCard(
                    title: "Morning Routine",
                    description: "Wake up early and start your day right",
                    price: "$0.99",
                    isPurchasing: $isPurchasing,
                    onPurchase: {
                        simulatePurchase(habitName: "Morning Routine")
                    }
                )

                HabitPurchaseCard(
                    title: "Exercise Daily",
                    description: "30 minutes of physical activity every day",
                    price: "$0.99",
                    isPurchasing: $isPurchasing,
                    onPurchase: {
                        simulatePurchase(habitName: "Exercise Daily")
                    }
                )

                HabitPurchaseCard(
                    title: "Read More",
                    description: "20 pages of reading before bed",
                    price: "$0.99",
                    isPurchasing: $isPurchasing,
                    onPurchase: {
                        simulatePurchase(habitName: "Read More")
                    }
                )

                HabitPurchaseCard(
                    title: "Drink Water",
                    description: "8 glasses of water throughout the day",
                    price: "$0.99",
                    isPurchasing: $isPurchasing,
                    onPurchase: {
                        simulatePurchase(habitName: "Drink Water")
                    }
                )
            }
        }
    }

    private func simulatePurchase(habitName: String) {
        isPurchasing = true
        // Simulate a purchase flow
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isPurchasing = false
            purchaseMessage = "'\(habitName)' habit purchased successfully! (Demo - no actual purchase)"
            showPurchaseAlert = true
        }
    }
}

struct HabitPurchaseCard: View {
    let title: String
    let description: String
    let price: String
    @Binding var isPurchasing: Bool
    let onPurchase: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(price)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.blue)

            Button {
                onPurchase()
            } label: {
                if isPurchasing {
                    ProgressView()
                        .frame(width: 70)
                } else {
                    Text("Buy")
                        .frame(width: 70)
                }
            }
            .buttonStyle(.bordered)
            .disabled(isPurchasing)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
