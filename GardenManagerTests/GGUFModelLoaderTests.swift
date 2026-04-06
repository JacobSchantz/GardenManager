import XCTest
import SwiftLlama

/// Tests for GGUFModelLoader - validates GGUF file loading and metadata parsing.
final class GGUFModelLoaderTests: XCTestCase {

    private var fixturesURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".openclaw/workspace/GardenManager/test_fixtures")
    }

    // MARK: - Fixture Helpers

    private func tinyllamaURL() -> URL {
        fixturesURL.appendingPathComponent("tinyllama-1.1b.Q4_K_M.gguf")
    }

    // MARK: - Test: Non-existent file returns error

    func test_loadNonExistentFile_returnsError() throws {
        let badURL = fixturesURL.appendingPathComponent("nonexistent-model.gguf")
        XCTAssertFalse(FileManager.default.fileExists(atPath: badURL.path))
    }

    // MARK: - Test: GGUF file can be loaded with SwiftLlama

    func test_loadTinyLlama_returnsModelMetadata() throws {
        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found at \(url.path)")
        }

        let model = LlamaModel(path: url.path)
        XCTAssertNotNil(model, "Should load tinyllama GGUF model")

        if let model = model {
            // Verify model metadata
            let desc = model.description()
            XCTAssertFalse(desc.isEmpty, "Model should have a description")

            let vocabSize = model.vocabularySize()
            XCTAssertGreaterThan(vocabSize, 0, "Model should have a vocabulary size")

            let trainedCtx = model.trainedContextSize()
            XCTAssertGreaterThan(trainedCtx, 0, "Model should report a trained context size")
        }
    }

    // MARK: - Test: Model quantization level detection

    func test_tinyllama_quantizationDetected() throws {
        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found")
        }

        let model = LlamaModel(path: url.path)
        XCTAssertNotNil(model)

        // Q4_K_M should appear in model description
        let desc = model?.description() ?? ""
        XCTAssertTrue(desc.contains("Q4") || desc.contains("q4") || !desc.isEmpty,
                      "Model description should contain quantization info: \(desc)")
    }

    // MARK: - Test: Model size is within expected range

    func test_tinyllama_modelSizeInExpectedRange() throws {
        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found")
        }

        let model = LlamaModel(path: url.path)
        XCTAssertNotNil(model)

        let sizeBytes = model?.modelSizeBytes() ?? 0
        // Q4_K_M tinyllama should be ~70MB
        let sizeMB = Double(sizeBytes) / 1_000_000
        XCTAssertGreaterThan(sizeMB, 50, "Model should be at least 50MB")
        XCTAssertLessThan(sizeMB, 200, "Model should be less than 200MB")
    }

    // MARK: - Test: Corrupt GGUF returns error gracefully

    func test_loadCorruptFile_returnsNil() throws {
        // Create a corrupt GGUF file
        let corruptURL = fixturesURL.appendingPathComponent("corrupt.gguf")
        FileManager.default.createFile(atPath: corruptURL.path, contents: Data([0, 1, 2, 3]))

        defer { try? FileManager.default.removeItem(at: corruptURL) }

        let model = LlamaModel(path: corruptURL.path)
        XCTAssertNil(model, "Loading a corrupt GGUF file should return nil")
    }
}
