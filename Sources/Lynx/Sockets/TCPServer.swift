#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Dispatch

/// A plain TCP server that can handle incoming clients
public final class TCPServer : TCPSocket {
    /// A closure to call for each connected client
    let onConnect: ((Client) -> ())
    
    public init(hostname: String, port: UInt16, onConnect: @escaping ((Client) -> ())) throws {
        self.onConnect = onConnect
        try super.init(hostname: hostname, port: port)
    }
    
    /// Starts listening for clients
    public func start() throws {
        let addr =  UnsafeMutablePointer<sockaddr>(OpaquePointer(self.server))
        let addrSize = socklen_t(MemoryLayout<sockaddr_in>.size)
        guard bind(descriptor, addr, addrSize) > -1 else {
            throw TCPError.bindFailed
        }
        
        guard listen(descriptor, 4096) > -1 else {
            throw TCPError.bindFailed
        }
        
        // On every connected client, this triggers
        readSource.setEventHandler {
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
        
        self.readSource.resume()
    }
    
    /// Stops listening for clients
    func stop() throws {
        self.readSource.cancel()
    }
    
    deinit {
        // Closes the file descriptor when not used anymore
        close(self.descriptor)
    }
}
