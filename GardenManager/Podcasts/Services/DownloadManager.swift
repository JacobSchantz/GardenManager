import Foundation
import UIKit

@MainActor
class DownloadManager: NSObject, ObservableObject {
    @Published var downloadingEpisodes: [UUID: Double] = [:]
    @Published var downloadedEpisodes: Set<UUID> = []
    
    private var activeDownloads: [UUID: URLSessionDownloadTask] = [:]
    private var downloadSession: URLSession!
    
    // Track episodes that need image downloads
    private var pendingImageDownloads: Set<UUID> = []
    private let legacyDownloadedEpisodesKey = "downloadedEpisodes"
    private let downloadedEpisodesFileName = "downloaded_episodes.json"
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        loadDownloadedEpisodes()
    }
    
    func downloadEpisode(_ episode: Episode) {
        guard !downloadedEpisodes.contains(episode.id),
              downloadingEpisodes[episode.id] == nil else { return }
        
        let task = downloadSession.downloadTask(with: episode.audioURL)
        activeDownloads[episode.id] = task
        downloadingEpisodes[episode.id] = 0
        task.resume()
        
        // Also download the image if available
        if let imageURL = episode.displayImageURL {
            downloadEpisodeImage(episodeID: episode.id, imageURL: imageURL)
        }
        
        print("Started download for episode: \(episode.title)")
    }
    
    private func downloadEpisodeImage(episodeID: UUID, imageURL: URL) {
        pendingImageDownloads.insert(episodeID)
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let image = UIImage(data: data) {
                    saveImageLocally(episodeID: episodeID, image: image)
                }
            } catch {
                print("Failed to download episode image: \(error)")
            }
            pendingImageDownloads.remove(episodeID)
        }
    }
    
    private func saveImageLocally(episodeID: UUID, image: UIImage) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let episodeFolder = documentsPath.appendingPathComponent("Downloads")
        
        try? FileManager.default.createDirectory(at: episodeFolder, withIntermediateDirectories: true)
        
        let imagePath = episodeFolder.appendingPathComponent("\(episodeID.uuidString).jpg")
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: imagePath)
            print("Saved image to: \(imagePath.path)")
        }
    }
    
    func getLocalImageURL(for episode: Episode) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let episodeFolder = documentsPath.appendingPathComponent("Downloads")
        let imagePath = episodeFolder.appendingPathComponent("\(episode.id.uuidString).jpg")
        
        return FileManager.default.fileExists(atPath: imagePath.path) ? imagePath : nil
    }
    
    func cancelDownload(_ episode: Episode) {
        activeDownloads[episode.id]?.cancel()
        activeDownloads.removeValue(forKey: episode.id)
        downloadingEpisodes.removeValue(forKey: episode.id)
    }
    
    func deleteDownload(_ episode: Episode) {
        // Delete audio file
        if let localURL = getLocalURL(for: episode) {
            try? FileManager.default.removeItem(at: localURL)
        }
        // Delete image file
        if let imageURL = getLocalImageURL(for: episode) {
            try? FileManager.default.removeItem(at: imageURL)
        }
        downloadedEpisodes.remove(episode.id)
        saveDownloadedEpisodes()
    }
    
    func getLocalURL(for episode: Episode) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let episodeFolder = documentsPath.appendingPathComponent("Downloads")
        let fileName = "\(episode.id.uuidString).mp3"
        let fileURL = episodeFolder.appendingPathComponent(fileName)
        
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    func isDownloaded(_ episode: Episode) -> Bool {
        return downloadedEpisodes.contains(episode.id)
    }
    
    private func saveDownloadedEpisodes() {
        let ids = Array(downloadedEpisodes).map { $0.uuidString }.sorted()
        let fileURL = downloadedEpisodesFileURL()
        guard let data = try? JSONEncoder().encode(ids) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }
    
    private func loadDownloadedEpisodes() {
        let fileURL = downloadedEpisodesFileURL()

        if let data = try? Data(contentsOf: fileURL),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            downloadedEpisodes = Set(ids.compactMap { UUID(uuidString: $0) })
            UserDefaults.standard.removeObject(forKey: legacyDownloadedEpisodesKey)
            return
        }

        if let legacyIDs = UserDefaults.standard.array(forKey: legacyDownloadedEpisodesKey) as? [String] {
            downloadedEpisodes = Set(legacyIDs.compactMap { UUID(uuidString: $0) })
            saveDownloadedEpisodes()
        }

        UserDefaults.standard.removeObject(forKey: legacyDownloadedEpisodesKey)
    }

    private func downloadedEpisodesFileURL() -> URL {
        let supportURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GardenManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        return supportURL.appendingPathComponent(downloadedEpisodesFileName)
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let episodeFolder = documentsPath.appendingPathComponent("Downloads")
        
        try? FileManager.default.createDirectory(at: episodeFolder, withIntermediateDirectories: true)
        
        // Copy file synchronously before the temp file is deleted
        let tempCopyURL = episodeFolder.appendingPathComponent("temp_\(UUID().uuidString).mp3")
        do {
            try FileManager.default.copyItem(at: location, to: tempCopyURL)
        } catch {
            print("Failed to copy downloaded file: \(error)")
            return
        }
        
        Task { @MainActor in
            guard let episodeID = self.activeDownloads.first(where: { $0.value == downloadTask })?.key else {
                try? FileManager.default.removeItem(at: tempCopyURL)
                return
            }
            
            let fileName = "\(episodeID.uuidString).mp3"
            let destinationURL = episodeFolder.appendingPathComponent(fileName)
            
            try? FileManager.default.removeItem(at: destinationURL)
            
            do {
                try FileManager.default.moveItem(at: tempCopyURL, to: destinationURL)
                print("Download completed: \(destinationURL.path)")
                
                self.downloadedEpisodes.insert(episodeID)
                self.downloadingEpisodes.removeValue(forKey: episodeID)
                self.activeDownloads.removeValue(forKey: episodeID)
                self.saveDownloadedEpisodes()
            } catch {
                print("Failed to save downloaded file: \(error)")
                try? FileManager.default.removeItem(at: tempCopyURL)
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            guard let episodeID = self.activeDownloads.first(where: { $0.value == downloadTask })?.key else { return }
            
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            self.downloadingEpisodes[episodeID] = progress
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            guard let episodeID = self.activeDownloads.first(where: { $0.value == task })?.key else { return }
            
            if let error = error {
                print("Download failed: \(error.localizedDescription)")
                self.downloadingEpisodes.removeValue(forKey: episodeID)
                self.activeDownloads.removeValue(forKey: episodeID)
            }
        }
    }
}
