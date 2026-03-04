import SwiftUI

struct PodcastListView: View {
    @EnvironmentObject var viewModel: PodcastListViewModel
    @State private var showingSearch = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.podcasts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Podcasts Yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Add a podcast RSS feed to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(viewModel.podcasts) { podcast in
                            NavigationLink(destination: EpisodeListView(podcastID: podcast.id, showDeleteButton: false)) {
                                PodcastRow(podcast: podcast)
                            }
                        }
                        .onDelete(perform: viewModel.deletePodcast)
                    }
                }
            }
            .navigationTitle("Podcasts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSearch = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                PodcastSearchView(podcastViewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

struct PodcastRow: View {
    let podcast: Podcast
    @State private var showPodcastOptions = false
    @State private var showCopied = false
    
    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: podcast.imageURL) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "mic.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(podcast.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(podcast.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("\(podcast.episodes.count) episodes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                showPodcastOptions = true
            }
        )
        .sheet(isPresented: $showPodcastOptions) {
            PodcastOptionsSheet(podcast: podcast)
        }
    }
}

struct PodcastOptionsSheet: View {
    let podcast: Podcast
    @Environment(\.dismiss) var dismiss
    @State private var showCopied = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: copyRSSURL) {
                        Label(showCopied ? "Copied!" : "Copy RSS URL", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                    }
                }
                
                Section {
                    ShareLink(item: podcast.feedURL) {
                        Label("Share Podcast", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle(podcast.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func copyRSSURL() {
        UIPasteboard.general.string = podcast.feedURL.absoluteString
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }
}

struct AddFeedView: View {
    @ObservedObject var viewModel: PodcastListViewModel
    @Binding var isPresented: Bool
    @State private var feedURLString = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("RSS Feed URL", text: $feedURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("Enter Podcast RSS Feed")
                } footer: {
                    Text("Example: https://feeds.example.com/podcast.xml")
                }
            }
            .navigationTitle("Add Podcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task {
                            isLoading = true
                            await viewModel.addPodcast(feedURL: feedURLString)
                            isLoading = false
                            if !viewModel.showError {
                                isPresented = false
                            }
                        }
                    }
                    .disabled(feedURLString.isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }
}

@MainActor
class PodcastListViewModel: ObservableObject {
    @Published var podcasts: [Podcast] = []
    @Published var showError = false
    @Published var errorMessage = ""
    
    init() {
        loadPodcasts()
        
        // Listen for episodes marked as played
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEpisodeMarkedAsPlayed(_:)),
            name: .episodeMarkedAsPlayed,
            object: nil
        )
    }
    
    @objc private func handleEpisodeMarkedAsPlayed(_ notification: Notification) {
        guard let episodeId = notification.userInfo?["episodeId"] as? UUID else { return }
        let isPlayed = notification.userInfo?["isPlayed"] as? Bool ?? true
        
        if isPlayed {
            // Use the new method that saves to separate storage
            markEpisodeAsPlayed(episodeId)
        }
    }
    
    func addPodcast(feedURL: String) async {
        guard let url = URL(string: feedURL) else {
            errorMessage = "Invalid URL"
            showError = true
            return
        }
        
        do {
            let parser = RSSFeedParser(feedURL: url)
            let podcast = try await parser.parse()
            podcasts.append(podcast)
            savePodcasts()
        } catch {
            errorMessage = "Failed to load podcast: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func deletePodcast(at offsets: IndexSet) {
        podcasts.remove(atOffsets: offsets)
        savePodcasts()
    }

    func deleteEpisode(podcastID: UUID, episodeID: UUID) {
        guard let podcastIndex = podcasts.firstIndex(where: { $0.id == podcastID }) else { return }
        podcasts[podcastIndex].episodes.removeAll(where: { $0.id == episodeID })
        savePodcasts()
    }

    func deleteEpisodes(podcastID: UUID, at offsets: IndexSet) {
        guard let podcastIndex = podcasts.firstIndex(where: { $0.id == podcastID }) else { return }
        podcasts[podcastIndex].episodes.remove(atOffsets: offsets)
        savePodcasts()
    }
    
    // MARK: - Played Status Storage (persists independently of episodes)
    
    private let playedEpisodesKey = "playedEpisodeIDs"
    
    /// Get set of played episode IDs from storage
    private func getPlayedEpisodeIDs() -> Set<UUID> {
        guard let ids = UserDefaults.standard.array(forKey: playedEpisodesKey) as? [String] else {
            return []
        }
        return Set(ids.compactMap { UUID(uuidString: $0) })
    }
    
    /// Save played episode IDs to storage
    private func savePlayedEpisodeIDs(_ ids: Set<UUID>) {
        let idStrings = ids.map { $0.uuidString }
        UserDefaults.standard.set(idStrings, forKey: playedEpisodesKey)
    }
    
    /// Mark episode as played and persist independently
    func markEpisodeAsPlayed(_ episodeId: UUID) {
        var playedIDs = getPlayedEpisodeIDs()
        playedIDs.insert(episodeId)
        savePlayedEpisodeIDs(playedIDs)
        
        // Also update in the episodes if present
        for podcastIndex in podcasts.indices {
            if let episodeIndex = podcasts[podcastIndex].episodes.firstIndex(where: { $0.id == episodeId }) {
                podcasts[podcastIndex].episodes[episodeIndex].isPlayed = true
            }
        }
        savePodcasts()
    }
    
    /// Check if episode is played
    func isEpisodePlayed(_ episodeId: UUID) -> Bool {
        getPlayedEpisodeIDs().contains(episodeId)
    }
    
    /// Restore played status from storage after loading podcasts
    private func restorePlayedStatus() {
        let playedIDs = getPlayedEpisodeIDs()
        for podcastIndex in podcasts.indices {
            for episodeIndex in podcasts[podcastIndex].episodes.indices {
                let episodeId = podcasts[podcastIndex].episodes[episodeIndex].id
                if playedIDs.contains(episodeId) {
                    podcasts[podcastIndex].episodes[episodeIndex].isPlayed = true
                }
            }
        }
    }
    
    func savePodcasts() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let podcastsFile = documentsPath.appendingPathComponent("podcasts.json")
        
        if let encoded = try? JSONEncoder().encode(podcasts) {
            try? encoded.write(to: podcastsFile)
        }
    }
    
    private func loadPodcasts() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let podcastsFile = documentsPath.appendingPathComponent("podcasts.json")
        
        if let data = try? Data(contentsOf: podcastsFile),
           let decoded = try? JSONDecoder().decode([Podcast].self, from: data) {
            podcasts = decoded
            // Restore played status from separate storage
            restorePlayedStatus()
        }
    }
}
