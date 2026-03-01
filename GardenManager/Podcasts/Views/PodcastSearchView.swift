import SwiftUI
import Combine

struct PodcastSearchView: View {
    @ObservedObject var searchService = PodcastSearchService()
    @ObservedObject var podcastViewModel: PodcastListViewModel
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    // Debounce timer
    @State private var searchTask: Task<Void, Never>?
    @State private var isAdding = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search podcasts...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { _, newValue in
                            searchTask?.cancel()
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                if !Task.isCancelled {
                                    await searchService.search(query: newValue)
                                }
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchService.clear()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                .onAppear {
                    isSearchFocused = true
                }
                
                if searchService.isLoading || isAdding {
                    Spacer()
                    ProgressView(isAdding ? "Adding..." : "Searching...")
                    Spacer()
                } else if let error = searchService.errorMessage {
                    Spacer()
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                    Spacer()
                } else if searchService.results.isEmpty && !searchText.isEmpty {
                    Spacer()
                    Text("No podcasts found")
                        .foregroundColor(.secondary)
                    Spacer()
                } else if searchService.results.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Search for podcasts")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(searchService.results) { podcast in
                        Button(action: { addPodcast(podcast) }) {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: podcast.artworkUrl600 ?? "")) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(Image(systemName: "mic.fill").foregroundColor(.gray))
                                }
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(podcast.trackName)
                                        .font(.headline)
                                        .lineLimit(2)
                                        .foregroundColor(.primary)
                                    Text(podcast.artistName)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    if let count = podcast.trackCount {
                                        Text("\(count) episodes")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Search Podcasts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func addPodcast(_ podcast: ITunesPodcastResult) {
        guard let feedURL = podcast.feedUrl else { return }
        
        isAdding = true
        Task {
            await podcastViewModel.addPodcast(feedURL: feedURL)
            isAdding = false
            if !podcastViewModel.showError {
                dismiss()
            }
        }
    }
}
