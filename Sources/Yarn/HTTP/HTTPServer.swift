//
//  HTTPServer.swift
//  Lion
//
//  Created by Joannis Orlandos on 25/06/2017.
//

import Dispatch
import Foundation

/// A handler, receives a request and it's client
///
/// Should handle all parts of the further response itself, including closing the socket when appropriate
public typealias RequestHandler = ((Request, Client) -> ())

/// An HTTP server, takes care of most TCP features and HTTP parsing under the hood
public final class HTTPServer {
    /// The TCP server to receive requests on
    internal private(set) var tcpServer: TCPServer!
    
    /// The handler for HTTP requests
    ///
    /// Should *not* be changed suring whilst the server is accepting connections
    public var handle: RequestHandler
    
    /// Creates a new HTTP server on a plain TCP connection to handle incoming requests
    ///
    /// Calls the handler for each request
    public init(hostname: String = "0.0.0.0", port: UInt16 = 8080, handler: @escaping RequestHandler) throws {
        self.handle = handler
        self.tcpServer = try TCPServer(hostname: hostname, port: port, onConnect: connection)
    }
    
    /// Starts serving the HTTP server
    public func start() throws -> Never {
        try self.tcpServer.start()
        
        print("serving")
        while true { sleep(UInt32.max) }
    }
    
    /// Handles an incoming client and starts HTTP parsing/responding
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
