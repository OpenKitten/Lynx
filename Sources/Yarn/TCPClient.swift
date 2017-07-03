import Dispatch

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/// Used as a simple global variable, to prevent useless repetitive allocations
fileprivate var len: socklen_t = 4

/// Every client has a private buffer
final class Buffer {
    let pointer: UnsafeMutablePointer<UInt8>
    let capacity: Int
    
    init(capacity: Int = 65_507) {
        pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        self.capacity = capacity
    }
    
    deinit {
        pointer.deallocate(capacity: capacity)
    }
}

/// Callback that can be called for each set of received TCP data
public typealias ReadCallback = ((UnsafePointer<UInt8>, Int)->())

/// A client that connected to the TCPServer
public struct Client {
    /// The client's descriptor
    private let descriptor: Int32
    
    /// The remote address
    private var addr: UnsafeMutablePointer<sockaddr_storage>!
    
    /// The queue on which data is received
    private static let queue = DispatchQueue(label: "org.openkitten.yarn.clientReadQueue", qos: DispatchQoS.userInteractive, attributes: .concurrent)
    
    /// Used to notify the `onRead` function of an update to the socket.
    ///
    /// This can be the closing of a socket or new data
    internal let readSource: DispatchSourceRead
    
    /// On TCP error, this gets called
    public var errorHandler: ((TCPError) -> ())?
    
    /// Creates a new Client from an incoming connection
    init(descriptor: Int32, addr: UnsafeMutablePointer<sockaddr_storage>) {
        self.descriptor = descriptor
        self.addr = addr
        self.readSource = DispatchSource.makeReadSource(fileDescriptor: self.descriptor, queue: Client.queue)
        
        self.readSource.setCancelHandler {
            Darwin.close(descriptor)
        }
    }
    
    /// A buffer, specific to this client
    let incomingBuffer = Buffer()
    
    /// Sets the onRead event closure
    public func onRead(_ closure: @escaping ReadCallback) {
        self.readSource.setEventHandler(qos: .userInteractive) {
            let read = Darwin.recv(self.descriptor, self.incomingBuffer.pointer, Int(UInt16.max), 0)
            
            guard read > -1 else {
                self.onError(.cannotRead)
                return
            }
            
            guard read != 0 else {
                self.close()
                return
            }
            
            // Calls the closure with new data
            closure(self.incomingBuffer.pointer, read)
        }
        
        self.readSource.resume()
    }
    
    /// Takes care of error handling
    func onError(_ error: TCPError) {
        self.close()
        
        errorHandler?(error)
    }
    
    /// Returns whether the socket is actively connected
    public var isConnected: Bool {
        var error = 0
        getsockopt(self.descriptor, SOL_SOCKET, SO_ERROR, &error, &len)
        
        return error == 0
    }
    
    /// Sends new data to the client
    public func send(data: [UInt8]) throws {
        try self.send(data: data, withLengthOf: data.count)
    }
    
    /// Sends new data to the client
    public func send(data pointer: UnsafePointer<UInt8>, withLengthOf length: Int) throws {
        let sent = Darwin.send(self.descriptor, pointer, length, 0)
        guard sent == length else {
            throw TCPError.sendFailure
        }
    }
    
    /// Closes the connection
    public func close() {
        self.readSource.cancel()
        self.readSource.setEventHandler(handler: nil)
    }
}

