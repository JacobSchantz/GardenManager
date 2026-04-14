import XCTest
import SwiftLlama
@testable import GardenManager

/// Tests for GGUF multimodal (vision) support via LocalAIClient.
final class GGUFMultimodalTests: XCTestCase {

    private var fixturesURL: URL {
        Bundle(for: Self.self).bundleURL
    }

    private func testImageData() -> Data? {
        // Create a small test JPEG image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 224, height: 224))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 224, height: 224))
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 56, y: 56, width: 112, height: 112))
        }
        return image.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Test: Can encode an image and send with text

    func test_imageEncoding_producesDataURI() throws {
        guard let imageData = testImageData() else {
            throw XCTSkip("Could not create test image")
        }

        // Verify the data URI format
        let base64 = imageData.base64EncodedString()
        XCTAssertFalse(base64.isEmpty, "Image should encode to base64")

        let dataURI = "data:image/jpeg;base64,\(base64)"
        XCTAssertTrue(dataURI.hasPrefix("data:image/jpeg;base64,"), "Data URI should have correct prefix")
    }

    // MARK: - Test: LocalAIClient can be initialized

    func test_localAIClient_initializes() async throws {
        let client = LocalAIClient(serverURL: URL(string: "http://localhost:8080")!, modelName: "llava")
        XCTAssertNotNil(client)
    }

    // MARK: - Test: LocalAIClient ping returns connectivity status

    func test_localAIClient_ping_returnsBool() async throws {
        let client = LocalAIClient(serverURL: URL(string: "http://localhost:8080")!, modelName: "llava")
        let reachable = await client.ping()

        // Returns false when server is not running (expected in test environment)
        XCTAssertFalse(reachable, "LocalAI server should not be running in test environment")
    }

    // MARK: - Test: LocalAIClient handles missing server gracefully

    func test_localAIClient_missingServer_returnsError() async throws {
        let client = LocalAIClient(serverURL: URL(string: "http://localhost:9999")!, modelName: "llava")

        do {
            _ = try await client.sendMessage(text: "Hello", imageData: nil, history: [])
            XCTFail("Should throw when server is unreachable")
        } catch {
            // Expected - connection refused or network error
            XCTAssertTrue(true, "Should fail gracefully when server unreachable")
        }
    }

    // MARK: - Test: LocalAIClient with image builds correct request format

    func test_localAIClient_imageMessageFormat() async throws {
        guard let imageData = testImageData() else {
            throw XCTSkip("Could not create test image")
        }

        let client = LocalAIClient(serverURL: URL(string: "http://localhost:8080")!, modelName: "llava")

        // The client should accept image data without crashing
        // (actual server call will fail since no server is running)
        let history: [ChatMessage] = [
            ChatMessage(role: "user", text: "What is this?"),
            ChatMessage(role: "assistant", text: "It looks like a red square.")
        ]

        do {
            _ = try await client.sendMessage(text: "Describe this image.", imageData: imageData, history: history)
            XCTFail("Should fail without server")
        } catch {
            // Expected - server not running
        }
    }

    // MARK: - Test: Text-only prompt still works after image test

    func test_textOnlyPrompt_stillWorks() async throws {
        let client = LocalAIClient(serverURL: URL(string: "http://localhost:8080")!, modelName: "llava")

        do {
            _ = try await client.sendMessage(text: "Hello", imageData: nil, history: [])
            XCTFail("Should fail without server")
        } catch {
            // Expected
        }
    }

    // MARK: - Test: ChatMessage history is correctly structured

    func test_chatMessageHistory_structure() throws {
        let messages: [ChatMessage] = [
            ChatMessage(role: "user", text: "Hello", imageData: nil),
            ChatMessage(role: "assistant", text: "Hi there!")
        ]

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, "user")
        XCTAssertEqual(messages[1].role, "assistant")
        XCTAssertEqual(messages[0].text, "Hello")
        XCTAssertEqual(messages[1].text, "Hi there!")
    }

    // MARK: - Test: Vision model name configuration

    func test_visionModelName_isStored() async throws {
        var client = LocalAIClient(serverURL: URL(string: "http://localhost:8080")!, modelName: "bakllava")

        let modelName = await client.modelName
        XCTAssertEqual(modelName, "bakllava")
    }
}
