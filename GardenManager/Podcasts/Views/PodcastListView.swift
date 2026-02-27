import SwiftUI

struct PodcastListView: View {
    @EnvironmentObject var viewModel: PodcastListViewModel
    @State private var showingAddFeed = false
    @State private var showingImageImport = false
    @State private var feedURLString = ""
    
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
                            NavigationLink(destination: EpisodeListView(podcastID: podcast.id)) {
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
                    Menu {
                        Button(action: { showingAddFeed = true }) {
                            Label("Add by URL", systemImage: "link")
                        }
                        
                        Button(action: { showingImageImport = true }) {
                            Label("Import from Image", systemImage: "photo")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFeed) {
                AddFeedView(viewModel: viewModel, isPresented: $showingAddFeed)
            }
            .sheet(isPresented: $showingImageImport) {
                ImagePodcastImportView(podcastListViewModel: viewModel)
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
            ItemOptionsSheet(
                type: .podcast(podcast)
            )
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
}

struct AddFeedView: View {
    let type: ItemOptionsType
    @Environment(\.dismiss) var dismiss
    @State private var showCopied = false
    
    private var title: String {
        switch type {
        case .podcast(let podcast):
            return podcast.title
        case .episode(let episode, _):
            return episode.title
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                switch type {
                case .podcast(let podcast):
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
                    
                    Section("Info") {
                        LabeledContent("Author", value: podcast.author)
                        LabeledContent("Episodes", value: "\(podcast.episodes.count)")
                    }
                    
                case .episode(let episode, let podcast):
                    Section {
                        Button(action: copyEpisodeURL) {
                            Label(showCopied ? "Copied!" : "Copy Episode URL", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                        }
                        Button(action: copyAudioURL) {
                            Label("Copy Audio URL", systemImage: "doc.on.doc")
                        }
                        if let podcast = podcast {
                            Button(action: copyPodcastURL) {
                                Label("Copy Podcast RSS", systemImage: "doc.on.doc")
                            }
                        }
                    }
                    
                    Section {
                        ShareLink(item: episode.audioURL) {
                            Label("Share Episode", systemImage: "square.and.arrow.up")
                        }
                    }
                    
                    if let podcast = podcast {
                        Section("Info") {
                            LabeledContent("Podcast", value: podcast.title)
                            if episode.duration > 0 {
                                LabeledContent("Duration", value: formatDuration(episode.duration))
                            }
                            if let date = Optional(episode.publishDate) {
                                LabeledContent("Published", value: date.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
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
        if case .podcast(let podcast) = type {
            UIPasteboard.general.string = podcast.feedURL.absoluteString
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showCopied = false
            }
        }
    }
    
    private func copyEpisodeURL() {
        if case .episode(let episode, _) = type {
            UIPasteboard.general.string = episode.audioURL.absoluteString
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showCopied = false
            }
        }
    }
    
    private func copyAudioURL() {
        if case .episode(let episode, _) = type {
            UIPasteboard.general.string = episode.audioURL.absoluteString
        }
    }
    
    private func copyPodcastURL() {
        if case .episode(_, let podcast) = type, let podcast = podcast {
            UIPasteboard.general.string = podcast.feedURL.absoluteString
        }
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
    
    func savePodcasts() {
        if let encoded = try? JSONEncoder().encode(podcasts) {
            UserDefaults.standard.set(encoded, forKey: "savedPodcasts")
        }
    }
    
    private func loadPodcasts() {
        if let data = UserDefaults.standard.data(forKey: "savedPodcasts"),
           let decoded = try? JSONDecoder().decode([Podcast].self, from: data) {
            podcasts = decoded
        }
    }
}

struct ItemOptionsSheet: View {
    let type: ItemOptionsType
    @Environment(\.dismiss) var dismiss
    @State private var showCopied = false
    
    private var title: String {
        switch type {
        case .podcast(let podcast):
            return podcast.title
        case .episode(let episode, _):
            return episode.title
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                switch type {
                case .podcast(let podcast):
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
                    
                    Section("Info") {
                        LabeledContent("Author", value: podcast.author)
                        LabeledContent("Episodes", value: "\(podcast.episodes.count)")
                    }
                    
                case .episode(let episode, let podcast):
                    Section {
                        Button(action: copyEpisodeURL) {
                            Label(showCopied ? "Copied!" : "Copy Episode URL", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                        }
                        Button(action: copyAudioURL) {
                            Label("Copy Audio URL", systemImage: "doc.on.doc")
                        }
                        if let podcast = podcast {
                            Button(action: copyPodcastURL) {
                                Label("Copy Podcast RSS", systemImage: "doc.on.doc")
                            }
                        }
                    }
                    
                    Section {
                        ShareLink(item: episode.audioURL) {
                            Label("Share Episode", systemImage: "square.and.arrow.up")
                        }
                    }
                    
                    if let podcast = podcast {
                        Section("Info") {
                            LabeledContent("Podcast", value: podcast.title)
                            if episode.duration > 0 {
                                LabeledContent("Duration", value: formatDuration(episode.duration))
                            }
                            if let date = Optional(episode.publishDate) {
                                LabeledContent("Published", value: date.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
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
        if case .podcast(let podcast) = type {
            UIPasteboard.general.string = podcast.feedURL.absoluteString
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showCopied = false
            }
        }
    }
    
    private func copyEpisodeURL() {
        if case .episode(let episode, _) = type {
            UIPasteboard.general.string = episode.audioURL.absoluteString
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showCopied = false
            }
        }
    }
    
    private func copyAudioURL() {
        if case .episode(let episode, _) = type {
            UIPasteboard.general.string = episode.audioURL.absoluteString
        }
    }
    
    private func copyPodcastURL() {
        if case .episode(_, let podcast) = type, let podcast = podcast {
            UIPasteboard.general.string = podcast.feedURL.absoluteString
        }
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
