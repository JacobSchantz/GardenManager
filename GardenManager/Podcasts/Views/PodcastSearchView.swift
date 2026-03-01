import SwiftUI

struct PodcastSearchView: View {
    @ObservedObject var searchService = PodcastSearchService()
    @ObservedObject var podcastViewModel: PodcastListViewModel
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var showingAddPodcast = false
    @State private var selectedPodcast: ITunesPodcastResult? = nil
    
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
                        .onSubmit {
                            Task { await searchService.search(query: searchText) }
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
                
                if searchService.isLoading {
                    Spacer()
                    ProgressView("Searching...")
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
                        Button(action: { selectedPodcast = podcast }) {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: podcast.artworkUrl600 ?? "")) { image in
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedPodcast) { podcast in
                AddSearchedPodcastView(podcast: podcast, podcastViewModel: podcastViewModel)
            }
        }
    }
}

struct AddSearchedPodcastView: View {
    let podcast: ITunesPodcastResult
    @ObservedObject var podcastViewModel: PodcastListViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Podcast info
                HStack(spacing: 16) {
                    AsyncImage(url: URL(string: podcast.artworkUrl600 ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 100, height: 100)
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(podcast.trackName)
                            .font(.headline)
                        Text(podcast.artistName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let count = podcast.trackCount {
                            Text("\(count) episodes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Button(action: addPodcast) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Add Podcast")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                .disabled(isLoading)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Add Podcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addPodcast() {
        guard let feedURL = podcast.feedUrl, let url = URL(string: feedURL) else {
            errorMessage = "No feed URL available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            await podcastViewModel.addPodcast(feedURL: feedURL)
            isLoading = false
            
            if !podcastViewModel.showError {
                dismiss()
            } else {
                errorMessage = podcastViewModel.errorMessage
            }
        }
    }
}
