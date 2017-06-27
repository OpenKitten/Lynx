import XCTest
@testable import Lion

class LionTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Lion().text, "Hello, World!")
    }


    static var allTests: [(String, (LionTests) -> () -> Void)] = [
        ("testExample", testExample),
    ]
}
