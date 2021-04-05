import XCTest
@testable import SpikeBLE

final class SpikeBLETests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(SpikeBLE().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
