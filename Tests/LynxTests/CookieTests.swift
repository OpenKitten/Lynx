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

    func testConnection() throws {
        let expectation = XCTestExpectation(description: "timeout")

        let c1 = ("SID", "31d4d96e407aad42")
        let c2 = ("lang", "en-US")


        let http = try HTTPServer() { request, handler in
            let cookies = request.cookies
            XCTAssert(cookies.count == 2)
            XCTAssert(cookies[c1.0]! == c1.1)
            XCTAssert(cookies[c2.0]! == c2.1)
            expectation.fulfill()
        }

        let tcpClient = try! TCPClient(hostname: "127.0.0.1", port: 8080) { (ptr, i) in

        }
        try dispatch_async_rethrows(dispatchQueue: DispatchQueue(label: "com.mongokitten.tcpconnect", qos: .userInteractive)) {
            sleep(1)

            try tcpClient.connect()
            try tcpClient.send(Request(method: .get, path: "/", headers: [
                "Cookie":  HeaderKey("\(c1.0)=\(c1.1); \(c2.0)=\(c2.1)")
                ]))
            }


        try dispatch_async_global_rethrows {
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
