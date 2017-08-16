//
//  CookieTests.swift
//  LynxTests
//
//  Created by James William Graham on 8/11/17.
//

import XCTest
@testable import Lynx

class CookieTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() throws {
        let expectation = XCTestExpectation(description: "timeout")
        let http = try HTTPServer() { request, handler in
            do {
                try handler.send(Response(status: 200))
            } catch {
                handler.error(error)
            }
        }

        let sesh = URLSession.shared
        let url = URL(string: "http://127.0.0.1:8080/")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        req.setValue("Cookie: SID=31d4d96e407aad42; lang=en-US", forHTTPHeaderField: "Cookie")
        let cookie = HTTPCookie(properties: [HTTPCookiePropertyKey.comment : "",
                                             HTTPCookiePropertyKey.path : "/",
                                             HTTPCookiePropertyKey.name : "MyFavoriteCookie",
                                             HTTPCookiePropertyKey.value : "DefinitelyMostValuedCookie",
                                             HTTPCookiePropertyKey.domain : "127.0.0.1:8080"])!
        HTTPCookieStorage.shared.setCookies([cookie], for: url, mainDocumentURL: nil)

        // We request latently, to get around http server starting synchronously
        DispatchQueue.global().async {
            sleep(1)
            let task = sesh.dataTask(with: req) { (data, res, err) in
                let http = res as! HTTPURLResponse
                XCTAssertNotNil(http.allHeaderFields["Set-Cookie"])
                expectation.fulfill()
            }
            task.resume()
        }
        try dispatch_async_global_rethrows { () -> Void in
            try http.start()
        }
        self.wait(for: [expectation], timeout: 6.0)


    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
