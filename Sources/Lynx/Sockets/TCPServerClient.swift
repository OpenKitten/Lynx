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
        pointer.initialize(to: 0, count: capacity)
        self.capacity = capacity
    }
    
    deinit {
        pointer.deinitialize(count: capacity)
        pointer.deallocate(capacity: capacity)
    }
}

/// Callback that can be called for each set of received TCP data
public typealias ReadCallback = ((UnsafePointer<UInt8>, Int)->())

final class ClientHolder {
    /// A buffer, specific to this client
    let incomingBuffer = Buffer()
    
    /// The client's descriptor
    fileprivate let descriptor: Int32
    
    /// The remote address
    fileprivate var addr: UnsafeMutablePointer<sockaddr_storage>!
    
    /// Used to notify the `onRead` function of an update to the socket.
    ///
    /// This can be the closing of a socket or new data
    internal let readSource: DispatchSourceRead
    
    /// On TCP error, this gets called
    var errorHandler: ((TCPError) -> ())?
    
    var receive: ReadCallback?
    
    init(descriptor: Int32, addr: UnsafeMutablePointer<sockaddr_storage>, onClose:  @escaping (() -> ())) {
        self.descriptor = descriptor
        self.addr = addr
        self.readSource = DispatchSource.makeReadSource(fileDescriptor: self.descriptor, queue: Client.queue)
        
        self.readSource.setCancelHandler {
            self.receive = nil
            onClose()
            
            #if os(Linux)
                Glibc.close(descriptor)
            #else
                _ = cClose(descriptor)
            #endif
        }
    }
    
    /// Closes the connection
    func close() {
        self.readSource.cancel()
        self.readSource.setEventHandler(handler: nil)
    }
    
    /// Returns whether the socket is actively connected
    var isConnected: Bool {
        var error = 0
        getsockopt(self.descriptor, SOL_SOCKET, SO_ERROR, &error, &len)
        
        return error == 0
    }
    
    func listen() {
        self.readSource.setEventHandler(qos: .userInteractive) {
            #if os(Linux)
                let read = Glibc.recv(self.descriptor, self.incomingBuffer.pointer, Int(UInt16.max), 0)
            #else
                let read = Darwin.recv(self.descriptor, self.incomingBuffer.pointer, Int(UInt16.max), 0)
            #endif
            
            guard read > -1 else {
                self.onError(.cannotRead)
                return
            }
            
            guard read != 0 else {
                self.close()
                return
            }
            
            // Calls the closure with new data
            self.receive?(self.incomingBuffer.pointer, read)
        }
        
        self.readSource.resume()
    }
    
    /// Takes care of error handling
    func onError(_ error: TCPError) {
        self.close()
        
        errorHandler?(error)
    }
    
    deinit {
        if self.isConnected {
            self.close()
        }
    }
}

/// A client that connected to the TCPServer
public struct Client {
    let holder: ClientHolder
    
    public static var errorHandler: ((Error & Encodable, Client) -> ())?
    
    /// The queue on which data is received
    fileprivate static let queue = DispatchQueue(label: "org.openkitten.lynx.clientReadQueue", qos: DispatchQoS.userInteractive, attributes: .concurrent)
    
    /// Creates a new Client from an incoming connection
    init(holder: ClientHolder) {
        self.holder = holder
    }
    
    /// Sets the onRead event closure
    public func onRead(_ closure: @escaping ReadCallback) {
        self.holder.receive = closure
    }
    
    public func startListening() {
        self.holder.listen()
    }
    
    public func close() {
        self.holder.close()
    }
    
    public var isConnected: Bool {
        return holder.isConnected
    }
    
    /// Sends new data to the client
    public func send(data: [UInt8]) throws {
        try self.send(data: data, withLengthOf: data.count)
    }
    
    /// Sends new data to the client
    public func send(data pointer: UnsafePointer<UInt8>, withLengthOf length: Int) throws {
        #if os(Linux)
            let sent = Glibc.send(self.holder.descriptor, pointer, length, 0)
        #else
            let sent = Darwin.send(self.holder.descriptor, pointer, length, 0)
        #endif
        
        guard sent == length else {
            throw TCPError.sendFailure
        }
    }
}
