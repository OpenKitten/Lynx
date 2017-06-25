//
//  HTTPServer.swift
//  Lion
//
//  Created by Joannis Orlandos on 25/06/2017.
//

import Foundation

public class HTTPServer {
    public private(set) var tcpServer: TCPServer!
    
    public init(port: UInt16 = 8080) throws {
        self.tcpServer = try TCPServer(port: port, onConnect: self.connection)
    }
    
    public func start() throws {
        try self.tcpServer.start()
    }
    
    func connection(from client: Client) {
        client.
    }
}
