import Foundation
import Dispatch

#if (os(macOS) || os(iOS))
    import Darwin
#else
    import Glibc
#endif

public class TCPClient : TCPSocket {
    /// A buffer, specific to this client
    let incomingBuffer = Buffer()
    
    public convenience init(hostname: String, port: UInt16, onRead: @escaping ReadCallback) throws {
        try self.init(hostname: hostname, port: port, onRead: onRead, true)
        
        self.readSource.setEventHandler(qos: .userInteractive) {
            let read = recv(self.descriptor, self.incomingBuffer.pointer, Int(UInt16.max), 0)
            
            guard read != 0 else {
                self.readSource.cancel()
                return
            }
            
            onRead(self.incomingBuffer.pointer, read)
        }
        
        self.readSource.setCancelHandler {
            self.close()
        }
        
        self.readSource.resume()
    }
    
    internal init(hostname: String, port: UInt16, onRead: @escaping ReadCallback, _ bool: Bool) throws {
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
    }
    
    open func close() {
        Darwin.close(self.descriptor)
    }
    
    var onRead: ReadCallback
    
    deinit {
        readSource.cancel()
    }
}
