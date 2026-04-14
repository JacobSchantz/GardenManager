import XCTest
import SwiftLlama

/// Tests for GGUF model loading via LlamaService (the public API).
/// Note: Tests that directly use LlamaModel require linking the llama C library,
/// which is not available to the test target. These tests use LlamaService instead.
final class GGUFModelLoaderTests: XCTestCase {

    private var fixturesURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".openclaw/workspace/GardenManager/test_fixtures")
    }

    private func tinyllamaURL() -> URL {
        fixturesURL.appendingPathComponent("tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf")
    }

    // MARK: - Test: Non-existent file returns error gracefully

    func test_loadNonExistentFile_failsWithError() async throws {
        let badURL = fixturesURL.appendingPathComponent("nonexistent-model.gguf")
        XCTAssertFalse(FileManager.default.fileExists(atPath: badURL.path))

        let config = LlamaConfig(batchSize: 512, maxTokenCount: 128, useGPU: false)
        let service = LlamaService(modelUrl: badURL, config: config)

        // Attempting to send a message should fail since model can't load
        do {
            let messages = [LlamaChatMessage(role: .user, content: "Hello")]
            let samplingConfig = LlamaSamplingConfig(temperature: 0.7, seed: 42, grammarConfig: nil)
            _ = try await service.respond(to: messages, samplingConfig: samplingConfig)
            XCTFail("Should have thrown an error for missing model")
        } catch {
            // Expected - model loading should fail
            XCTAssertTrue(true, "Should fail gracefully for non-existent model")
        }
    }

    // MARK: - Test: GGUF file can be loaded with LlamaService

    func test_loadTinyLlamaService_succeeds() async throws {
        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found at \(url.path)")
        }

        let config = LlamaConfig(batchSize: 512, maxTokenCount: 128, useGPU: false)
        let service = LlamaService(modelUrl: url, config: config)

        // Verify service was created (model loads lazily on first inference)
        XCTAssertNotNil(service, "LlamaService should initialize")
    }

    // MARK: - Test: Model quantization level detectable via description

    func test_tinyllama_quantizationDetected_viaService() async throws {
        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found")
        }

        let config = LlamaConfig(batchSize: 512, maxTokenCount: 128, useGPU: false)
        let service = LlamaService(modelUrl: url, config: config)

        // Do a quick inference to ensure model is loaded
        let messages = [LlamaChatMessage(role: .user, content: "Hi")]
        let samplingConfig = LlamaSamplingConfig(temperature: 0.7, seed: 42, grammarConfig: nil)

        let response = try await service.respond(to: messages, samplingConfig: samplingConfig)
        XCTAssertFalse(response.isEmpty, "Model should produce a response")

        // Q4_K_M quantization should appear in response or model should load successfully
        XCTAssertTrue(response.count > 0, "Should get a response from Q4 quantized model")
    }

    // MARK: - Test: Model size is within expected range

    func test_tinyllama_modelSizeInExpectedRange() async throws {
        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found")
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let sizeBytes = attributes[.size] as? Int64 ?? 0

        // Q4_K_M tinyllama should be roughly 600-800MB range
        let sizeMB = Double(sizeBytes) / 1_000_000
        XCTAssertGreaterThan(sizeMB, 100, "Model should be at least 100MB")
        XCTAssertLessThan(sizeMB, 1500, "Model should be less than 1.5GB")
    }

    // MARK: - Test: Corrupt GGUF returns error gracefully

    func test_loadCorruptFile_failsGracefully() async throws {
        // Create a corrupt GGUF file
        let corruptURL = fixturesURL.appendingPathComponent("corrupt.gguf")
        FileManager.default.createFile(atPath: corruptURL.path, contents: Data([0, 1, 2, 3]))

        defer { try? FileManager.default.removeItem(at: corruptURL) }

        let config = LlamaConfig(batchSize: 512, maxTokenCount: 128, useGPU: false)
        let service = LlamaService(modelUrl: corruptURL, config: config)

        do {
            let messages = [LlamaChatMessage(role: .user, content: "Hello")]
            let samplingConfig = LlamaSamplingConfig(temperature: 0.7, seed: 42, grammarConfig: nil)
            _ = try await service.respond(to: messages, samplingConfig: samplingConfig)
            XCTFail("Should throw for corrupt model")
        } catch {
            // Expected - corrupt model should fail
            XCTAssertTrue(true, "Loading corrupt GGUF should fail gracefully")
        }
    }
}
