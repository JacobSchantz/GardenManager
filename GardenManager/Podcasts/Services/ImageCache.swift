import SwiftUI
import UIKit

/// Simple image cache using NSCache for memory caching
class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    
    private init() {
        // Setup disk cache directory
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDir.appendingPathComponent("PodcastImageCache", isDirectory: true)
        
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Configure memory cache
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func image(for url: URL) -> UIImage? {
        // Check memory cache first
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        
        // Check disk cache
        let fileURL = diskCacheURL.appendingPathComponent(url.absoluteString.hashValue.description)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // Store in memory for faster access
            cache.setObject(image, forKey: url as NSURL)
            return image
        }
        
        return nil
    }
    
    func store(_ image: UIImage, for url: URL) {
        // Store in memory
        cache.setObject(image, forKey: url as NSURL)
        
        // Store on disk asynchronously
        let fileURL = diskCacheURL.appendingPathComponent(url.absoluteString.hashValue.description)
        DispatchQueue.global(qos: .background).async {
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: fileURL)
            }
        }
    }
    
    func loadImage(from url: URL) async -> UIImage? {
        // Check cache first
        if let cached = ImageCache.shared.image(for: url) {
            return cached
        }
        
        // Download
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                ImageCache.shared.store(image, for: url)
                return image
            }
        } catch {
            print("ImageCache: Failed to load \(url): \(error)")
        }
        
        return nil
    }
    
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
}

/// SwiftUI wrapper for cached async image
struct CachedAsyncImage: View {
    let url: URL?
    let placeholder: AnyView
    
    init(url: URL?, @ViewBuilder placeholder: () -> some View = { Color.gray.opacity(0.3).overlay(Image(systemName: "mic.fill").foregroundColor(.gray)) } ) {
        self.url = url
        self.placeholder = AnyView(placeholder())
    }
    
    var body: some View {
        if let url = url {
            CachedAsyncImageInner(url: url, placeholder: placeholder)
        } else {
            placeholder
        }
    }
}

struct CachedAsyncImageInner: View {
    let url: URL
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
        
        // Check cache first
        if let cached = ImageCache.shared.image(for: url) {
            withAnimation {
                self.image = cached
            }
            isLoading = false
            return
        }
        
        // Download and cache
        if let downloaded = await ImageCache.shared.loadImage(from: url) {
            await MainActor.run {
                withAnimation {
                    self.image = downloaded
                }
            }
        }
        
        isLoading = false
    }
}