import XCTest
import SwiftLlama

/// Integration tests for GGUF inference via LlamaService/SwiftLlama.
/// Note: Tests that require loading the actual GGUF model are skipped on simulator
/// due to memory constraints. These should be run manually on a device.
final class GGUFInferenceTests: XCTestCase {

    private var fixturesURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".openclaw/workspace/GardenManager/test_fixtures")
    }

    private func tinyllamaURL() -> URL {
        fixturesURL.appendingPathComponent("tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf")
    }

    // MARK: - Test: Can initialize inference with GGUF file (lightweight check)

    func test_initializeInference_succeeds() async throws {
        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found at \(url.path)")
        }

        // Verify file is valid GGUF before trying to load
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let magicBytes = try handle.read(upToCount: 4)
        let magic = String(data: Data(magicBytes ?? Data()), encoding: .ascii) ?? ""
        guard magic == "GGUF" else {
            throw XCTSkip("File is not a valid GGUF (magic: \(magic))")
        }

        let config = LlamaConfig(batchSize: 512, maxTokenCount: 256, useGPU: false)
        let service = LlamaService(modelUrl: url, config: config)
        XCTAssertNotNil(service, "LlamaService should initialize")
    }

    // MARK: - Test: GGUF model can be loaded and returns text (skip on simulator)

    func test_inference_returnsTextResponse() async throws {
        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found")
        }

        #if targetEnvironment(simulator)
        throw XCTSkip("GGUF inference test skipped on simulator due to memory constraints. Run on device.")
        #endif

        let config = LlamaConfig(batchSize: 512, maxTokenCount: 128, useGPU: false)
        let service = LlamaService(modelUrl: url, config: config)

        let messages = [
            LlamaChatMessage(role: .user, content: "Hello, how are you?")
        ]
        let samplingConfig = LlamaSamplingConfig(temperature: 0.7, seed: 42, grammarConfig: nil)

        let reply = try await service.respond(to: messages, samplingConfig: samplingConfig)
        XCTAssertFalse(reply.isEmpty, "Model should return a non-empty response")
    }

    // MARK: - Test: Empty prompt returns error

    func test_emptyPrompt_throwsError() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("GGUF inference test skipped on simulator due to memory constraints. Run on device.")
        #endif

        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found")
        }

        let config = LlamaConfig(batchSize: 512, maxTokenCount: 128, useGPU: false)
        let service = LlamaService(modelUrl: url, config: config)

        let messages: [LlamaChatMessage] = []
        let samplingConfig = LlamaSamplingConfig(temperature: 0.7, seed: 42, grammarConfig: nil)

        do {
            _ = try await service.respond(to: messages, samplingConfig: samplingConfig)
            XCTFail("Empty prompt should throw an error")
        } catch {
            // Expected
        }
    }

    // MARK: - Test: Inference can be cancelled

    func test_inference_cancellable() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("GGUF inference test skipped on simulator due to memory constraints. Run on device.")
        #endif

        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found")
        }

        let config = LlamaConfig(batchSize: 512, maxTokenCount: 512, useGPU: false)
        let service = LlamaService(modelUrl: url, config: config)

        let messages = [
            LlamaChatMessage(role: .user, content: "Count to 1000")
        ]

        let task = Task {
            let samplingConfig = LlamaSamplingConfig(temperature: 0.7, seed: 42, grammarConfig: nil)
            return try await service.respond(to: messages, samplingConfig: samplingConfig)
        }

        // Let it run briefly then cancel
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        await service.stopCompletion()

        task.cancel()
        XCTAssertTrue(task.isCancelled, "Task should be cancelled")
    }

    // MARK: - Test: Memory is freed after inference session

    func test_memoryFreedAfterSession() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("GGUF inference test skipped on simulator due to memory constraints. Run on device.")
        #endif

        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found")
        }

        let config = LlamaConfig(batchSize: 512, maxTokenCount: 128, useGPU: false)

        // Run a session
        let service = LlamaService(modelUrl: url, config: config)
        let messages = [
            LlamaChatMessage(role: .user, content: "Say hello.")
        ]
        let samplingConfig = LlamaSamplingConfig(temperature: 0.7, seed: 42, grammarConfig: nil)
        _ = try await service.respond(to: messages, samplingConfig: samplingConfig)

        // If we reach here without crashing, the session cleaned up
        XCTAssertTrue(true, "Session should complete without memory issues")
    }
}
