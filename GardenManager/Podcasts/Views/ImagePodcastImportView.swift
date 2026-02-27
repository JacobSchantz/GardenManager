import SwiftUI
import PhotosUI
import UIKit

// MARK: - Image Cache
// NSCache is thread-safe, but we need proper isolation for Swift concurrency
actor ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    
    private init() {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDir.appendingPathComponent("PodcastImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
    }
    
    func image(for url: URL) -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        let fileURL = diskCacheURL.appendingPathComponent(url.absoluteString.hashValue.description)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            cache.setObject(image, forKey: url as NSURL)
            return image
        }
        return nil
    }
    
    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
        let fileURL = diskCacheURL.appendingPathComponent(url.absoluteString.hashValue.description)
        Task.detached(priority: .background) {
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: fileURL)
            }
        }
    }
    
    func loadImage(from url: URL) async -> UIImage? {
        if let cached = self.image(for: url) {
            return cached
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await self.store(image, for: url)
                return image
            }
        } catch {
            print("ImageCache: Failed to load \(url): \(error)")
        }
        return nil
    }
}

struct CachedAsyncImage: View {
    let url: URL?
    let localURL: URL?  // Local file URL (e.g., from downloaded episode)
    let placeholder: AnyView
    
    init(url: URL?, localURL: URL? = nil, @ViewBuilder placeholder: () -> some View = { Color.gray.opacity(0.3).overlay(Image(systemName: "mic.fill").foregroundColor(.gray)) } ) {
        self.url = url
        self.localURL = localURL
        self.placeholder = AnyView(placeholder())
    }
    
    var body: some View {
        if let url = url {
            CachedAsyncImageInner(url: url, localURL: localURL, placeholder: placeholder)
        } else {
            placeholder
        }
    }
}

struct CachedAsyncImageInner: View {
    let url: URL
    let localURL: URL?
    let placeholder: AnyView
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
            } else {
                placeholder
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard !isLoading else { return }
        isLoading = true
        print("[CachedAsyncImage] Loading image from: \(url)")
        
        // First check: local downloaded file
        if let localURL = localURL,
           let data = try? Data(contentsOf: localURL),
           let localImage = UIImage(data: data) {
            withAnimation { self.image = localImage }
            isLoading = false
            return
        }
        
        // Second check: memory cache
        if let cached = await ImageCache.shared.image(for: url) {
            withAnimation { self.image = cached }
            isLoading = false
            return
        }
        
        // Third check: download from remote
        if let downloaded = await ImageCache.shared.loadImage(from: url) {
            await MainActor.run {
                withAnimation { self.image = downloaded }
            }
        }
        isLoading = false
    }
}

// MARK: - Image Podcast Import View
import SwiftUI
import PhotosUI

struct ImagePodcastImportView: View {
    @StateObject private var viewModel = ImagePodcastImportViewModel()
    @Environment(\.dismiss) private var dismiss
    
    private let podcastListViewModel: PodcastListViewModel
    
    init(podcastListViewModel: PodcastListViewModel) {
        self.podcastListViewModel = podcastListViewModel
    }
    
    private var imagePickerView: some View {
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
    }

    private var imageSelectedView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(uiImage: viewModel.selectedImage!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .padding(.horizontal)
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
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Found \(viewModel.podcastResults.count) potential podcasts:")
                            .font(.headline)
                        ForEach(Array(viewModel.podcastResults.enumerated()), id: \.offset) { pair in
                            let index = pair.offset
                            let result = pair.element
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
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.selectedImage == nil {
                    imagePickerView
                } else {
                    imageSelectedView
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
        let result: (name: String, podcast: Podcast?)
        let onImport: () -> Void
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(.headline)
                    
                    if let podcast = result.podcast {
                        Text(podcast.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(podcast.episodes.count) episodes")
                            .font(.caption)
                            .foregroundColor(.secondary)
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

