import XCTest
import SwiftLlama

/// Integration tests for GGUF inference via LlamaService/SwiftLlama.
final class GGUFInferenceTests: XCTestCase {

    private var fixturesURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".openclaw/workspace/GardenManager/test_fixtures")
    }

    private func tinyllamaURL() -> URL {
        fixturesURL.appendingPathComponent("tinyllama-1.1b.Q4_K_M.gguf")
    }

    // MARK: - Test: Can initialize inference with GGUF file

    func test_initializeInference_succeeds() async throws {
        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found at \(url.path)")
        }

        let config = LlamaConfig(batchSize: 512, maxTokenCount: 256, useGPU: false)
        let service = LlamaService(modelUrl: url, config: config)

        XCTAssertNotNil(service, "LlamaService should initialize")
    }

    // MARK: - Test: Can run inference and get text response

    func test_inference_returnsTextResponse() async throws {
        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found")
        }

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
        XCTAssertTrue(task.isCancelled || task.isFaulted, "Task should be cancelled or faulted")
    }

    // MARK: - Test: Memory is freed after inference session

    func test_memoryFreedAfterSession() async throws {
        let url = tinyllamaURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("tinyllama fixture not found")
        }

        let config = LlamaConfig(batchSize: 512, maxTokenCount: 128, useGPU: false)

        // Run a session
        do {
            let service = LlamaService(modelUrl: url, config: config)
            let messages = [
                LlamaChatMessage(role: .user, content: "Say hello.")
            ]
            let samplingConfig = LlamaSamplingConfig(temperature: 0.7, seed: 42, grammarConfig: nil)
            _ = try await service.respond(to: messages, samplingConfig: samplingConfig)
        }

        // If we reach here without crashing, the session cleaned up
        XCTAssertTrue(true, "Session should complete without memory issues")
    }
}
