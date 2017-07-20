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
            let read = self.readIntoBuffer()
            
            guard read != 0 else {
                self.readSource.cancel()
                return
            }
            
            onRead(self.incomingBuffer.pointer, read)
        }
        
        self.readSource.resume()
    }
    
    open func readIntoBuffer() -> Int {
        return recv(self.descriptor, self.incomingBuffer.pointer, Int(UInt16.max), 0)
    }
    
    var onRead: ReadCallback
    
    deinit {
        readSource.cancel()
    }
}
