import Foundation

@MainActor
class DownloadManager: NSObject, ObservableObject {
    @Published var downloadingEpisodes: [UUID: Double] = [:]
    @Published var downloadedEpisodes: Set<UUID> = []
    
    private var activeDownloads: [UUID: URLSessionDownloadTask] = [:]
    private var downloadSession: URLSession!
    
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
        print("Started download for episode: \(episode.title)")
    }
    
    func cancelDownload(_ episode: Episode) {
        activeDownloads[episode.id]?.cancel()
        activeDownloads.removeValue(forKey: episode.id)
        downloadingEpisodes.removeValue(forKey: episode.id)
    }
    
    func deleteDownload(_ episode: Episode) {
        if let localURL = getLocalURL(for: episode) {
            try? FileManager.default.removeItem(at: localURL)
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
        let ids = Array(downloadedEpisodes).map { $0.uuidString }
        UserDefaults.standard.set(ids, forKey: "downloadedEpisodes")
    }
    
    private func loadDownloadedEpisodes() {
        if let ids = UserDefaults.standard.array(forKey: "downloadedEpisodes") as? [String] {
            downloadedEpisodes = Set(ids.compactMap { UUID(uuidString: $0) })
        }
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
