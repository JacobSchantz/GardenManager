import SwiftUI

struct PodcastSearchView: View {
    @StateObject private var searchService = PodcastSearchService()
    @ObservedObject var podcastViewModel: PodcastListViewModel
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    // Debounce timer
    @State private var searchTask: Task<Void, Never>?
    @State private var focusTask: Task<Void, Never>?
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
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            searchTask?.cancel()

                            guard trimmed.count >= 2 else {
                                searchService.clear()
                                return
                            }

                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                if !Task.isCancelled {
                                    await searchService.search(query: trimmed)
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
                    // Reset state every time sheet opens so no stale query/results run automatically.
                    searchTask?.cancel()
                    searchService.clear()
                    if !searchText.isEmpty {
                        searchText = ""
                    }

                    focusTask?.cancel()
                    focusTask = Task {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        if !Task.isCancelled {
                            isSearchFocused = true
                        }
                    }
                }
                .onDisappear {
                    searchTask?.cancel()
                    focusTask?.cancel()
                    isSearchFocused = false
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
                } else if searchService.results.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 {
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
                                CachedAsyncImage(url: URL(string: podcast.artworkUrl600 ?? "")) {
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
