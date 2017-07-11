#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Dispatch

/// A plain TCP server that can handle incoming clients
final class TCPServer {
    /// The file descriptor on which connections are received
    let descriptor: Int32
    
    /// A queue where, asynchronously, clients are being accepted
    let queue = DispatchQueue(label: "org.openkitten.lynx.listen", qos: .userInteractive)
    
    /// The server's public address
    var server = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
    
    /// A closure to call for each connected client
    let onConnect: ((Client) -> ())
    
    /// A readsource that triggers when a new client connects to the descriptor
    let readSource: DispatchSourceRead?
    
    /// Creates a new TCPServer listening on the specify hostname and port
    ///
    /// Calls the `onConnect` closure for each client
    init(hostname: String, port: UInt16, onConnect: @escaping ((Client) -> ())) throws {
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
        
        self.onConnect = onConnect
        self.readSource = DispatchSource.makeReadSource(fileDescriptor: descriptor)
        
        self.readSource!.setCancelHandler {
            close(self.descriptor)
        }
    }
    
    /// Starts listening for clients
    func start() throws {
        let addr =  UnsafeMutablePointer<sockaddr>(OpaquePointer(self.server))
        let addrSize = socklen_t(MemoryLayout<sockaddr_in>.size)
        guard bind(descriptor, addr, addrSize) > -1 else {
            throw TCPError.bindFailed
        }
        
        guard listen(descriptor, 4096) > -1 else {
            throw TCPError.bindFailed
        }
        
        // On every connected client, this triggers
        readSource?.setEventHandler {
            let addr = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
            let addrSockAddr = UnsafeMutablePointer<sockaddr>(OpaquePointer(addr))
            var a = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let clientDescriptor = accept(self.descriptor, addrSockAddr, &a)
            
            guard clientDescriptor > -1 else {
                addr.deallocate(capacity: 1)
                return
            }
            
            let holder = ClientHolder(descriptor: clientDescriptor, addr: addr)
            
            self.onConnect(Client(holder: holder))
        }
        
        self.readSource?.resume()
    }
    
    /// Stops listening for clients
    func stop() throws {
        self.readSource?.cancel()
    }
    
    deinit {
        // Closes the file descriptor when not used anymore
        close(self.descriptor)
    }
}
