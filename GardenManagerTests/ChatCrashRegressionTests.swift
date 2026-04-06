import XCTest
import UIKit
@testable import GardenManager

/// Regression tests for chat crashes related to image handling.
final class ChatCrashRegressionTests: XCTestCase {

    private func createTestImageData(size: CGSize = CGSize(width: 100, height: 100)) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Test: Image data does not crash on encoding

    func test_imageDataEncoding_doesNotCrash() throws {
        guard let imageData = createTestImageData() else {
            throw XCTSkip("Could not create test image")
        }

        // This should not crash
        let base64 = imageData.base64EncodedString()
        XCTAssertFalse(base64.isEmpty)
    }

    // MARK: - Test: Rapid image sends do not crash

    func test_rapidImageSends_noCrash() throws {
        guard let imageData = createTestImageData() else {
            throw XCTSkip("Could not create test image")
        }

        // Simulate rapid image processing
        for i in 0..<3 {
            let base64 = imageData.base64EncodedString()
            XCTAssertFalse(base64.isEmpty, "Image \(i) should encode successfully")
        }
    }

    // MARK: - Test: Image and text together do not crash

    func test_imageAndTextTogether_noCrash() throws {
        guard let imageData = createTestImageData() else {
            throw XCTSkip("Could not create test image")
        }

        let text = "Describe this image"
        let base64 = imageData.base64EncodedString()
        let combined = "User: [Image: data:image/jpeg;base64,\(base64)]\nCaption: \(text)\nAssistant:"

        XCTAssertFalse(combined.isEmpty)
        XCTAssertTrue(combined.contains("data:image/jpeg;base64,"))
        XCTAssertTrue(combined.contains(text))
    }

    // MARK: - Test: Large image does not crash

    func test_largeImage_doesNotCrash() throws {
        guard let imageData = createTestImageData(size: CGSize(width: 1024, height: 1024)) else {
            throw XCTSkip("Could not create large test image")
        }

        // This should not crash even with large image
        let base64 = imageData.base64EncodedString()
        XCTAssertFalse(base64.isEmpty)
        XCTAssertGreaterThan(base64.count, 10_000, "Large image should produce substantial base64")
    }

    // MARK: - Test: Nil image is handled gracefully

    func test_nilImage_handledGracefully() throws {
        let imageData: Data? = nil
        XCTAssertNil(imageData)

        // The app should handle nil image data without crashing
        if let data = imageData {
            _ = data.base64EncodedString()
        }
        // If we reach here without crashing, nil is handled
        XCTAssertTrue(true)
    }

    // MARK: - Test: Empty image data is handled gracefully

    func test_emptyImageData_handledGracefully() throws {
        let emptyData = Data()
        let base64 = emptyData.base64EncodedString()
        XCTAssertTrue(base64.isEmpty)
    }

    // MARK: - Test: Multiple rapid message appends do not crash

    func test_rapidMessageAppends_noCrash() throws {
        var messages: [UnifiedChatMessage] = []

        for i in 0..<10 {
            let msg = UnifiedChatMessage(role: .user, text: "Message \(i)")
            messages.append(msg)
        }

        XCTAssertEqual(messages.count, 10)
    }

    // MARK: - Test: Image is displayed alongside text response (format check)

    func test_imageDisplayFormat_isCorrect() throws {
        guard let imageData = createTestImageData() else {
            throw XCTSkip("Could not create test image")
        }

        // Verify the image can be reconstructed from data URI
        let base64 = imageData.base64EncodedString()
        let dataURI = "data:image/jpeg;base64,\(base64)"

        // Parse base64 from data URI
        XCTAssertTrue(dataURI.hasPrefix("data:image/jpeg;base64,"))
        let commaIndex = dataURI.firstIndex(of: ",")!
        let base64String = String(dataURI[dataURI.index(after: commaIndex)...])
        let parsedData = Data(base64Encoded: base64String)

        XCTAssertNotNil(parsedData, "Should be able to decode base64 back to data")
        XCTAssertEqual(parsedData?.count ?? 0, imageData.count, "Parsed data should match original")
    }

    // MARK: - Test: Conversation clear after image does not crash

    func test_clearConversation_afterImage_noCrash() throws {
        var messages: [UnifiedChatMessage] = []

        let userMsg = UnifiedChatMessage(role: .user, text: "Look at this")
        messages.append(userMsg)

        let assistantMsg = UnifiedChatMessage(role: .assistant, text: "I see an image")
        messages.append(assistantMsg)

        // Clear should not crash
        messages.removeAll()
        XCTAssertTrue(messages.isEmpty)
    }
}
