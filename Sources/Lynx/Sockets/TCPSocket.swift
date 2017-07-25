#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Dispatch

/// Used as a simple global variable, to prevent useless repetitive allocations
fileprivate var len: socklen_t = 4

public class TCPSocket {
    /// Returns whether the socket is actively connected
    var isConnected: Bool {
        var error = 0
        getsockopt(self.descriptor, SOL_SOCKET, SO_ERROR, &error, &len)
        
        return error == 0
    }
    
    /// The file descriptor on which connections are received
    public let descriptor: Int32
    
    /// A queue where, asynchronously, the connection is being handled with
    static let queue = DispatchQueue(label: "org.openkitten.lynx.socket", qos: .userInteractive)
    
    /// The server's public address
    var server = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
    
    /// A readsource that triggers when a new client connects to the descriptor
    let readSource: DispatchSourceRead
    
    /// Creates a new TCPServer listening on the specify hostname and port
    ///
    /// Calls the `onConnect` closure for each client
    public init(hostname: String, port: UInt16) throws {
        signal(SIGPIPE, SIG_IGN)
        
        var addressCriteria = addrinfo.init()
        // IPv4 or IPv6
        addressCriteria.ai_family = Int32(AF_INET)
        addressCriteria.ai_flags = AI_PASSIVE
        
        #if os(Linux)
            addressCriteria.ai_socktype = Int32(SOCK_STREAM.rawValue)
            addressCriteria.ai_protocol = Int32(IPPROTO_TCP)
        #else
            addressCriteria.ai_socktype = SOCK_STREAM
            addressCriteria.ai_protocol = IPPROTO_TCP
        #endif
        
        var addrInfo: UnsafeMutablePointer<addrinfo>?
        
        guard getaddrinfo(hostname, port.description, &addressCriteria, &addrInfo) > -1 else {
            throw TCPError.bindFailed
        }
        
        guard let info = addrInfo else { throw TCPError.bindFailed }
        
        defer { freeaddrinfo(info) }
        
        guard let addr = info.pointee.ai_addr else { throw TCPError.bindFailed }
        
        server.initialize(to: sockaddr_storage())
        
        let _addr = UnsafeMutablePointer<sockaddr_in>.init(OpaquePointer(addr))!
        let specPtr = UnsafeMutablePointer<sockaddr_in>(OpaquePointer(server))
        specPtr.assign(from: _addr, count: 1)
        
        self.descriptor = socket(addressCriteria.ai_family, addressCriteria.ai_socktype, addressCriteria.ai_protocol)
        
        guard descriptor > -1 else {
            throw TCPError.bindFailed
        }
        
        guard fcntl(self.descriptor, F_SETFL, O_NONBLOCK) > -1 else {
            throw TCPError.bindFailed
        }
        
        var yes = 1
        
        guard setsockopt(self.descriptor, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int>.size)) > -1 else {
            throw TCPError.bindFailed
        }
        
        self.readSource = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: TCPSocket.queue)
    }
    
    /// Sends new data to the client
    public func send(data: [UInt8]) throws {
        try self.send(data: data, withLengthOf: data.count)
    }
    
    /// Sends new data to the client
    open func send(data pointer: UnsafePointer<UInt8>, withLengthOf length: Int) throws {
        #if os(Linux)
            let sent = Glibc.send(self.descriptor, pointer, length, 0)
        #else
            let sent = Darwin.send(self.descriptor, pointer, length, 0)
        #endif
        
        guard sent == length else {
            throw TCPError.sendFailure
        }
    }
}
