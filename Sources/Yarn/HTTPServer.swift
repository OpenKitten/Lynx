//
//  HTTPServer.swift
//  Lion
//
//  Created by Joannis Orlandos on 25/06/2017.
//

import Dispatch
import Foundation

public typealias RequestHandler = ((Request, Client) -> ())

public final class HTTPServer {
    public private(set) var tcpServer: TCPServer!
    let queue = DispatchQueue(label: "org.openkitten.yarn.clientManager", qos: .userInteractive)
    public var handle: RequestHandler
    
    public init(hostname: String = "0.0.0.0", port: UInt16 = 8080, handler: @escaping RequestHandler) throws {
        self.handle = handler
        self.tcpServer = try TCPServer(hostname: hostname, port: port, onConnect: connection)
    }
    
    public func start() throws -> Never {
        try self.tcpServer.start()
        
        print("serving")
        while true { sleep(UInt32.max) }
    }
    
    func connection(from client: Client) {
        let requestProgress = RequestPlaceholder()
        
        client.onRead { ptr, len in
            requestProgress.parse(ptr, len: len)
            
            if requestProgress.complete, let request = requestProgress.makeRequest() {
                self.handle(request, client)
                requestProgress.empty()
            }
        }
    }
}

fileprivate let message = [UInt8]("HTTP/1.1 200 OK\r\nServer: gws\r\nContent-Type: text/html; charset=ISO-8859-1\r\nDate: Tue, 27 Jun 2017 14:54:47 GMT\r\nContent-Length: 4\r\n\r\nKaas".utf8)

/// Class so you don't copy the data at all and treat them like a state machine
public final class Request {
    public let method: Method
    public var path: Path
    public let headers: Headers
    
    // ":token" -> "value"
    
    init(with method: Method, path: Path, headers: Headers) {
        self.method = method
        self.path = path
        self.headers = headers
    }
}

