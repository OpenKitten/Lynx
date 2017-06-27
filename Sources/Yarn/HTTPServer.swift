//
//  HTTPServer.swift
//  Lion
//
//  Created by Joannis Orlandos on 25/06/2017.
//

import Dispatch
import Foundation

public class HTTPServer {
    public private(set) var tcpServer: TCPServer!
    let queue = DispatchQueue(label: "org.openkitten.yarn.clientManager", qos: .userInteractive)
    
    public init(hostname: String = "0.0.0.0", port: UInt16 = 8080) throws {
        self.tcpServer = try TCPServer(hostname: hostname, port: port, onConnect: self.connection)
    }
    
    public func start() throws -> Never {
        try self.tcpServer.start()
        
        print("serving")
        while true { sleep(300) }
    }
    
    public func handle(_ request: Request, for client: Client) {
        do {
            try client.send(data: message, withLengthOf: message.count)
        } catch { print(error) }
    }
    
    func connection(from client: Client) {
        let requestProgress = RequestPlaceholder()
        
        client.onRead { ptr, len in
            requestProgress.parse(ptr, len: len)
            
            if requestProgress.complete, let request = requestProgress.makeRequest() {
                client.handle(request)
                requestProgress.empty()
            }
        }
    }
}

fileprivate let message = [UInt8]("HTTP/1.1 200 OK\r\nServer: gws\r\nContent-Type: text/html; charset=ISO-8859-1\r\nDate: Tue, 27 Jun 2017 14:54:47 GMT\r\nContent-Length: 4\r\n\r\nKaas".utf8)

extension Client {
    func handle(_ request: Request) {
        do {
            _ = try send(data: message, withLengthOf: message.count)
        } catch {
            self.close()
        }
    }
}

/// Class so you don't copy the data at all and treat them like a state machine
public class Request {
    public let method: Method
    public let path: String
    public let headers: [HeaderKey : String]
    
    init(with method: Method, path: String, headers: [HeaderKey:String]) {
        self.method = method
        self.path = path
        self.headers = headers
    }
}

