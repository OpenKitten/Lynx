#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Dispatch

public final class TCPClient : TCPSocket {
    /// A buffer, specific to this client
    let incomingBuffer = Buffer()
    
    public init(hostname: String, port: UInt16, onRead: @escaping ReadCallback) throws {
        self.onRead = onRead
        
        try super.init(hostname: hostname, port: port)
        
        let addr =  UnsafeMutablePointer<sockaddr>(OpaquePointer(self.server))
        let addrSize = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        var result: Int32
        
        repeat {
            result = connect(self.descriptor, addr, addrSize)
        } while result == -1 && (errno == EINPROGRESS || errno == EALREADY)
        
        if result == -1 {
            guard errno == EINPROGRESS || errno == EISCONN else {
                throw TCPError.unableToConnect
            }
        }
        
        self.readSource.setCancelHandler {
            close(self.descriptor)
        }
        
        self.readSource.setEventHandler(qos: .userInteractive) {
            let read = recv(self.descriptor, self.incomingBuffer.pointer, Int(UInt16.max), 0)
            
            guard read != 0 else {
                self.readSource.cancel()
                return
            }
            
            onRead(self.incomingBuffer.pointer, read)
        }
        
        self.readSource.resume()
    }
    
    var onRead: ReadCallback
    
    deinit {
        readSource.cancel()
    }
}
