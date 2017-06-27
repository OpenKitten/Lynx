import Dispatch
import Darwin

public enum TCPError : Error {
    case bindFailed
    case cannotSendData
    case sendFailure
    case cannotRead
}

fileprivate var len: socklen_t = 4

public final class TCPServer {
    let descriptor: Int32
    let queue = DispatchQueue(label: "org.openkitten.yarn.listen", qos: .userInteractive)
    var server = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
    let onConnect: ((Client) -> ())
    
    public init(hostname: String, port: UInt16, onConnect: @escaping ((Client) -> ())) throws {
        signal(SIGPIPE, SIG_IGN)
        
        var addressCriteria = addrinfo.init()
        // IPv4 or IPv6
        addressCriteria.ai_family = Int32(AF_INET)
        addressCriteria.ai_flags = AI_PASSIVE
        addressCriteria.ai_socktype = SOCK_STREAM
        addressCriteria.ai_protocol = IPPROTO_TCP
        
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
    }
    
    func start() throws {
        let addr =  UnsafeMutablePointer<sockaddr>(OpaquePointer(self.server))
        let addrSize = socklen_t(MemoryLayout<sockaddr_in>.size)
        guard bind(descriptor, addr, addrSize) > -1 else {
            throw TCPError.bindFailed
        }
        
        guard listen(descriptor, 4096) > -1 else {
            throw TCPError.bindFailed
        }
        
        queue.async {
            while true {
                let addr = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
                let addrSockAddr = UnsafeMutablePointer<sockaddr>(OpaquePointer(addr))
                var a = socklen_t(MemoryLayout<sockaddr_storage>.size)
                let clientDescriptor = accept(self.descriptor, addrSockAddr, &a)
                
                guard clientDescriptor > -1 else {
                    addr.deallocate(capacity: 1)
                    continue
                }
                
                let client = Client(descriptor: clientDescriptor, addr: addr)
                
                self.onConnect(client)
            }
        }
    }
    
    deinit {
        close(self.descriptor)
    }
}

public final class Buffer {
    public let pointer: UnsafeMutablePointer<UInt8>
    public let capacity: Int
    
    public init(capacity: Int = 65_507) {
        pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        self.capacity = capacity
    }
    
    deinit {
        pointer.deallocate(capacity: capacity)
    }
}

public typealias ReadCallback = ((UnsafePointer<UInt8>, Int)->())

public struct Client {
    private let descriptor: Int32
    private var addr: UnsafeMutablePointer<sockaddr_storage>!
    private static let queue = DispatchQueue(label: "org.openkitten.yarn.clientReadQueue", qos: DispatchQoS.userInteractive, attributes: .concurrent)
    internal let readSource: DispatchSourceRead
    public var errorHandler: ((TCPError) -> ())?
    
    init(descriptor: Int32, addr: UnsafeMutablePointer<sockaddr_storage>) {
        self.descriptor = descriptor
        self.addr = addr
        self.readSource = DispatchSource.makeReadSource(fileDescriptor: self.descriptor, queue: Client.queue)
        
        self.readSource.setCancelHandler {
            Darwin.close(descriptor)
        }
    }
    
    let incomingBuffer = Buffer()
    
    public func onRead(_ closure: @escaping ReadCallback) {
        self.readSource.setEventHandler(qos: .userInteractive) {
            let read = Darwin.recv(self.descriptor, self.incomingBuffer.pointer, Int(UInt16.max), 0)
            
            guard read > -1 else {
                self.onError(.cannotRead)
                return
            }
            
            guard read != 0 else {
                return
            }
            
            closure(self.incomingBuffer.pointer, read)
        }
        
        self.readSource.resume()
    }
    
    func onError(_ error: TCPError) {
        self.close()
        
        errorHandler?(error)
    }
    
    public var isConnected: Bool {
        var error = 0
        getsockopt(self.descriptor, SOL_SOCKET, SO_ERROR, &error, &len)
        
        return error == 0
    }
    
    public func send(data: [UInt8]) throws {
        try self.send(data: data, withLengthOf: data.count)
    }
    
    public func send(data pointer: UnsafePointer<UInt8>, withLengthOf length: Int) throws {
        let sent = Darwin.send(self.descriptor, pointer, length, 0)
        guard sent == length else {
            throw TCPError.sendFailure
        }
    }
    
    public func close() {
        self.readSource.cancel()
        self.readSource.setEventHandler(handler: nil)
    }
}
