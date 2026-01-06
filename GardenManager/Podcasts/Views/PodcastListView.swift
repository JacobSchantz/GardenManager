import SwiftUI

struct PodcastListView: View {
    @StateObject private var viewModel = PodcastListViewModel()
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
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: podcast.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
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
        }
        .padding(.vertical, 4)
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
