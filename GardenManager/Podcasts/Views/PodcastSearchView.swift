import SwiftUI

struct PodcastSearchView: View {
    @StateObject private var viewModel = PodcastSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search podcasts...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task {
                                await viewModel.searchPodcasts()
                            }
                        }
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.searchQuery = ""
                            viewModel.searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.searchPodcasts()
                        }
                    }) {
                        Text("Search")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                        .padding()
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No podcasts found")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                    Spacer()
                } else {
                    List(viewModel.searchResults) { podcast in
                        PodcastSearchRow(podcast: podcast) {
                            Task {
                                await viewModel.importPodcast(podcast)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search Podcasts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Import Successful", isPresented: $viewModel.showImportSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("\"\(viewModel.lastImportedPodcast?.title ?? "")\" has been added to your library.")
            }
            .alert("Import Failed", isPresented: $viewModel.showImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.importErrorMessage)
            }
        }
    }
}

struct PodcastSearchRow: View {
    let podcast: PodcastSearchResult
    let onImport: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: podcast.image ?? podcast.thumbnail ?? "")) { image in
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
                
                Text(podcast.publisher)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text("\(podcast.totalEpisodes) episodes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if podcast.explicitContent {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Explicit")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            Button(action: onImport) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
    }
}

@MainActor
class PodcastSearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [PodcastSearchResult] = []
    @Published var isLoading = false
    @Published var showImportSuccess = false
    @Published var showImportError = false
    @Published var importErrorMessage = ""
    @Published var lastImportedPodcast: PodcastSearchResult?
    
    private let searchService = PodcastSearchService()
    private var podcastListViewModel: PodcastListViewModel?
    
    func setPodcastListViewModel(_ viewModel: PodcastListViewModel) {
        self.podcastListViewModel = viewModel
    }
    
    func searchPodcasts() async {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await searchService.searchPodcasts(query: searchQuery)
            searchResults = response.results
        } catch {
            // For now, just clear results on error
            // In a production app, you'd show an error message
            searchResults = []
        }
    }
    
    func importPodcast(_ searchResult: PodcastSearchResult) async {
        guard let podcastListViewModel = podcastListViewModel else { return }
        
        // Check if podcast already exists
        if podcastListViewModel.podcasts.contains(where: { $0.feedURL.absoluteString == searchResult.rss }) {
            importErrorMessage = "This podcast is already in your library."
            showImportError = true
            return
        }
        
        do {
            // Use the RSS URL to create the podcast via RSS parsing
            let rssURL = URL(string: searchResult.rss)!
            let parser = RSSFeedParser(feedURL: rssURL)
            let podcast = try await parser.parse()
            
            podcastListViewModel.podcasts.append(podcast)
            podcastListViewModel.savePodcasts()
            
            lastImportedPodcast = searchResult
            showImportSuccess = true
        } catch {
            importErrorMessage = "Failed to import podcast: \(error.localizedDescription)"
            showImportError = true
        }
    }
}
