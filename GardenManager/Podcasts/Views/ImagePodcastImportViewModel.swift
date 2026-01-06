import SwiftUI
import PhotosUI

@MainActor
class ImagePodcastImportViewModel: ObservableObject {
    @Published var selectedItem: PhotosPickerItem? {
        didSet {
            if let selectedItem = selectedItem {
                loadImage(from: selectedItem)
            }
        }
    }
    @Published var selectedImage: UIImage?
    @Published var processingState: ProcessingState = .idle
    @Published var processingStatus = ""
    @Published var podcastResults: [(name: String, podcast: Podcast?)] = []
    @Published var showImportSuccess = false
    @Published var showImportError = false
    @Published var importSuccessMessage = ""
    @Published var importErrorMessage = ""
    
    private let visionService = VisionService()
    private let textProcessingService = TextProcessingService()
    private var podcastListViewModel: PodcastListViewModel?
    
    enum ProcessingState {
        case idle
        case processing
        case completed
    }
    
    func setPodcastListViewModel(_ viewModel: PodcastListViewModel) {
        self.podcastListViewModel = viewModel
    }
    
    private func loadImage(from item: PhotosPickerItem) {
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            } catch {
                // Handle error - could show alert
                print("Error loading image: \(error)")
            }
        }
    }
    
    func processImage() async {
        guard let image = selectedImage else { return }
        
        processingState = .processing
        processingStatus = "Extracting text from image..."
        
        do {
            // Step 1: Extract text from image
            let extractedText = try await visionService.extractText(from: image)
            
            if extractedText.isEmpty {
                processingStatus = "No text found in image. Try a clearer image."
                processingState = .idle
                return
            }
            
            processingStatus = "Found \(extractedText.count) text lines. Analyzing for podcast names..."
            
            // Step 2: Extract podcast names from text
            let podcastNames = await textProcessingService.extractPodcastNames(from: extractedText)
            
            if podcastNames.isEmpty {
                processingStatus = "No podcast names detected. Try an image with clearer podcast titles."
                processingState = .idle
                return
            }
            
            processingStatus = "Found \(podcastNames.count) potential podcast names. Searching for matches..."
            
            // Step 3: Find matching podcasts
            let results = await textProcessingService.findMatchingPodcasts(for: podcastNames) { current, total in
                Task { @MainActor in
                    self.processingStatus = "Searching... (\(current + 1)/\(total))"
                }
            }
            
            podcastResults = results
            processingState = .completed
            
            let foundCount = results.filter { $0.podcast != nil }.count
            processingStatus = "Found \(foundCount) matching podcasts out of \(results.count) candidates."
            
        } catch {
            processingState = .idle
            processingStatus = "Error processing image: \(error.localizedDescription)"
        }
    }
    
    func importPodcast(at index: Int) async {
        guard index < podcastResults.count,
              let podcastResult = podcastResults[index].podcast,
              let podcastListViewModel = podcastListViewModel else {
            return
        }
        
        // Check if podcast already exists
        if podcastListViewModel.podcasts.contains(where: { $0.feedURL.absoluteString == podcastResult.feedURL.absoluteString }) {
            importErrorMessage = "\"\(podcastResult.title)\" is already in your library."
            showImportError = true
            return
        }
        
        do {
            // The podcast is already in the correct format, just add it
            podcastListViewModel.podcasts.append(podcastResult)
            podcastListViewModel.savePodcasts()
            
            importSuccessMessage = "\"\(podcastResult.title)\" has been added to your library."
            showImportSuccess = true
            
        } catch {
            importErrorMessage = "Failed to import \"\(podcastResult.title)\": \(error.localizedDescription)"
            showImportError = true
        }
    }
    
    func reset() {
        selectedImage = nil
        selectedItem = nil
        processingState = .idle
        processingStatus = ""
        podcastResults = []
    }
}
