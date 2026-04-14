import XCTest
import SwiftLlama

/// Tests for GGUF model loading via LlamaService (the public API).
/// Note: Full model loading tests are skipped on simulator due to memory constraints.
/// Use the app itself on a device or with a running simulator to test GGUF loading.
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

    // MARK: - Test: GGUF file exists and is valid format

    func test_tinyllama_fileExists_andIsValidGGUF() throws {
        let url = tinyllamaURL()

        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found at \(url.path)")
        }

        // Check it's a valid GGUF (starts with GGUF magic bytes)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let magicBytes = try handle.read(upToCount: 4)
        let magic = String(data: Data(magicBytes ?? Data()), encoding: .ascii) ?? ""
        XCTAssertEqual(magic, "GGUF", "File should start with GGUF magic bytes, got: \(magic)")
    }

    // MARK: - Test: Model size is within expected range

    func test_tinyllama_modelSizeInExpectedRange() throws {
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

    // MARK: - Test: GGUF service initializes with valid config

    func test_llamaService_initializesWithValidURL() async throws {
        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found")
        }

        let config = LlamaConfig(batchSize: 512, maxTokenCount: 128, useGPU: false)
        let service = LlamaService(modelUrl: url, config: config)

        XCTAssertNotNil(service, "LlamaService should initialize with valid config")
    }

    // MARK: - Test: Corrupt GGUF returns error gracefully

    func test_loadCorruptFile_failsGracefully() async throws {
        // Create a corrupt GGUF file in tmp
        let tmpDir = FileManager.default.temporaryDirectory
        let corruptURL = tmpDir.appendingPathComponent("corrupt-test.gguf")
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

    // MARK: - Test: LlamaConfig validation

    func test_llamaConfig_validation() throws {
        let config1 = LlamaConfig(batchSize: 512, maxTokenCount: 128, useGPU: false)
        XCTAssertEqual(config1.batchSize, 512)
        XCTAssertEqual(config1.maxTokenCount, 128)
        XCTAssertFalse(config1.useGPU)

        let config2 = LlamaConfig(batchSize: 1024, maxTokenCount: 4096, useGPU: true)
        XCTAssertEqual(config2.batchSize, 1024)
        XCTAssertEqual(config2.maxTokenCount, 4096)
        XCTAssertTrue(config2.useGPU)
    }

    // MARK: - Test: LlamaChatMessage structure

    func test_llamaChatMessage_structure() throws {
        let userMsg = LlamaChatMessage(role: .user, content: "Hello")
        XCTAssertEqual(userMsg.role, .user)
        XCTAssertEqual(userMsg.content, "Hello")

        let assistantMsg = LlamaChatMessage(role: .assistant, content: "Hi there!")
        XCTAssertEqual(assistantMsg.role, .assistant)
        XCTAssertEqual(assistantMsg.content, "Hi there!")

        let systemMsg = LlamaChatMessage(role: .system, content: "You are helpful.")
        XCTAssertEqual(systemMsg.role, .system)
    }
}
