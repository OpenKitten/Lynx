import XCTest
@testable import Lynx

class PathTests: XCTestCase {
    func testUpload() throws {
        let http = try HTTPServer(hostname: "0.0.0.0", port: 8080) { request, handler in
            do {
                guard let multipart = request.multipart else {
                    try handler.send(Response(status: 404))
                    return
                }
                
                for part in multipart.parts {
                    guard case .file(_) = part.type else {
                        continue
                    }
                    
                    let body = try part.data.makeBody()
                    
                    _ = try? FileManager.default.removeItem(atPath: "/Users/joannisorlandos/test")
                    FileManager.default.createFile(atPath: "/Users/joannisorlandos/test", contents: Data(body.buffer))
                }
                
                try handler.send(Response(status: 200))
            } catch {
                handler.error(error)
            }
        }
        
        try http.start()
    }
    
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

    func testPerf() throws {
        let router = TrieRouter()
        
        router.register(at: [""], method: .get) { request, client in
            do {
                try client.send(try "Response".makeResponse())
            } catch { client.error(error) }
        }
        
        let server = try HTTPServer(handler: router.handle)
        
        try server.start()
    }

    static var allTests: [(String, (PathTests) -> () -> Void)] = [
        ("testQuery", testQuery),
        ("testBasicPath", testBasicPath),
    ]
}
