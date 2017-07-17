import XCTest
@testable import Lynx

class PathTests: XCTestCase {
    func testQuery() {
        let pathString = "/users"
        let pathBytes = [UInt8](pathString.utf8)
        
        let queryString = "plain=text&spa%20ces=space%20separated%20value"
        let queryBytes = [UInt8](queryString.utf8)
        
        let path = pathBytes.withUnsafeBufferPointer { pathBytes in
            return queryBytes.withUnsafeBufferPointer { queryBytes in
                return Path(path: pathBytes, query: queryBytes)
            }
        }
        
        XCTAssertEqual(path.query["plain"], "text")
        XCTAssertEqual(path.query["spa ces"], "space separated value")
    }
    
    func testBasicPath() {
        let pathString = "/users/test/route/123"
        let pathBytes = [UInt8](pathString.utf8)
        
        let path = pathBytes.withUnsafeBufferPointer { pathBytes in
            Path(path: pathBytes, query: nil)
        }
        
        XCTAssertEqual(pathString, path.debugDescription)
        
        let pathComponentsAsString = path.components.flatMap { component in
            return String(bytes: component, encoding: .utf8)
        }.joined(separator: "/")
        
        // The path components don't start with a `/`
        XCTAssertEqual(pathString, "/" + pathComponentsAsString)
    }


    static var allTests: [(String, (PathTests) -> () -> Void)] = [
        ("testQuery", testQuery),
        ("testBasicPath", testBasicPath),
    ]
}
