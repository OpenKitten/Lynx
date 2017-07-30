import Foundation
import Dispatch

#if (os(macOS) || os(iOS))
    import Darwin
    fileprivate let sockConnect = Darwin.connect
    let cClose = Darwin.close
#else
    import Glibc
    fileprivate let sockConnect = connect
    let cClose = Glibc.close
#endif

public class TCPClient : TCPSocket {
    /// A buffer, specific to this client
    let incomingBuffer = Buffer()
    
    public init(hostname: String, port: UInt16, onRead: @escaping ReadCallback) throws {
        self.onRead = onRead
        
        try super.init(hostname: hostname, port: port)
    }
    
    /// Connects the TCP client after initialization
    public func connect() throws {
        try self.connect(startReading: true)
    }
    
    /// Connects the TCP client but allows the reading to not start yet
    ///
    /// Useful if you need to connect the socket but need to run another layer first, such as SSL
    internal func connect(startReading: Bool = true) throws {
        if startReading {
            self.readSource.setEventHandler(qos: .userInteractive) {
                let read = recv(self.descriptor, self.incomingBuffer.pointer, Int(UInt16.max), 0)
                
                guard read != 0 else {
                    self.readSource.cancel()
                    return
                }
                
                self.onRead(self.incomingBuffer.pointer, read)
            }
            
            self.readSource.setCancelHandler {
                self.close()
            }
            
            self.readSource.resume()
        }
        
        let addr =  UnsafeMutablePointer<sockaddr>(OpaquePointer(self.server))
        let addrSize = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        var result: Int32
        
        repeat {
            result = sockConnect(self.descriptor, addr, addrSize)
        } while result == -1 && (errno == EINPROGRESS || errno == EALREADY)
        
        if result == -1 {
            guard errno == EINPROGRESS || errno == EISCONN else {
                throw TCPError.unableToConnect
            }
        }
    }
    
    open func close() {
        _ = cClose(self.descriptor)
    }
    
    var onRead: ReadCallback
    
    deinit {
        readSource.cancel()
    }
}
