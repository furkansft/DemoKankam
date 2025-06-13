import XCTest
@testable import DemoKankam

final class DemoKankamTests: XCTestCase {
    func testPromptEcho() async throws {
        let reply = try await APIManager.shared.sendPrompt("Hello")
        XCTAssert(reply.contains("Hello"))
    }
}
