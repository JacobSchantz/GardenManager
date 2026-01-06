import SwiftUI
import PhotosUI

struct ImagePodcastImportView: View {
    @StateObject private var viewModel = ImagePodcastImportViewModel()
    @Environment(\.dismiss) private var dismiss
    
    private let podcastListViewModel: PodcastListViewModel
    
    init(podcastListViewModel: PodcastListViewModel) {
        self.podcastListViewModel = podcastListViewModel
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.selectedImage == nil {
                    // Image picker view
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Import Podcasts from Image")
                            .font(.title2)
                            .multilineTextAlignment(.center)
                        
                        Text("Take a photo or select an image containing podcast names, and we'll automatically find and import them for you.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        PhotosPicker(selection: $viewModel.selectedItem,
                                     matching: .images,
                                     photoLibrary: .shared()) {
                            Label("Select Image", systemImage: "photo")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                                     .padding(.top)
                    }
                    .padding()
                } else {
                    // Image selected view
                    ScrollView {
                        VStack(spacing: 20) {
                            // Selected image
                            Image(uiImage: viewModel.selectedImage!)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            
                            // Process button or results
                            if viewModel.processingState == .idle {
                                Button(action: {
                                    Task {
                                        await viewModel.processImage()
                                    }
                                }) {
                                    Label("Find Podcasts", systemImage: "magnifyingglass")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                                .padding(.horizontal)
                                
                                Button(action: {
                                    viewModel.selectedImage = nil
                                    viewModel.selectedItem = nil
                                }) {
                                    Text("Choose Different Image")
                                        .foregroundColor(.gray)
                                }
                                
                            } else if viewModel.processingState == .processing {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                    
                                    Text(viewModel.processingStatus)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                
                            } else if viewModel.processingState == .completed {
                                // Results
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Found \(viewModel.podcastResults.count) potential podcasts:")
                                        .font(.headline)
                                    
                                    ForEach(viewModel.podcastResults.indices, id: \.self) { index in
                                        let result = viewModel.podcastResults[index]
                                        PodcastImportResultRow(result: result) {
                                            Task {
                                                await viewModel.importPodcast(at: index)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                
                                Spacer()
                                
                                Button(action: {
                                    viewModel.reset()
                                }) {
                                    Text("Process Another Image")
                                        .foregroundColor(.blue)
                                }
                                .padding(.bottom)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import from Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Import Successful", isPresented: $viewModel.showImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.importSuccessMessage)
            }
            .alert("Import Error", isPresented: $viewModel.showImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.importErrorMessage)
            }
        }
        .onAppear {
            viewModel.setPodcastListViewModel(podcastListViewModel)
        }
    }
    
    struct PodcastImportResultRow: View {
        let result: (name: String, podcast: PodcastSearchResult?)
        let onImport: () -> Void
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(.headline)
                    
                    if let podcast = result.podcast {
                        Text(podcast.publisher)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
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
                    } else {
                        Text("No matching podcast found")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                if result.podcast != nil {
                    Button(action: onImport) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}
