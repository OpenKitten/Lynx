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
    internal private(set) var tcpServer: TCPServer!
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

/// Class so you don't copy the data at all and treat them like a state machine
public final class Request {
    public let method: Method
    public var url: Path
    public let headers: Headers
    public let body: UnsafeMutableBufferPointer<UInt8>?
    
    public init(with method: Method, url: Path, headers: Headers, body: UnsafeMutableBufferPointer<UInt8>?) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
    
    deinit {
        if let body = body {
            body.baseAddress?.deallocate(capacity: body.count)
        }
    }
}

