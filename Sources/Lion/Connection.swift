import Dispatch
import Darwin

public enum TCPError : Error {
    case bindFailed
    case cannotSendData
}

public final class TCPServer {
    let descriptor: Int32
    let queue = DispatchQueue(label: "org.openkitten.lion.listen", qos: .userInteractive)
    let clientQueue = DispatchQueue(label: "org.openkitten.lion.listen", qos: .userInteractive)
    var server = sockaddr_in()
    let onConnect: ((Client) -> ())
    
    public init(port: UInt16, onConnect: @escaping ((Client) -> ())) throws {
        self.descriptor = socket(AF_INET, SOCK_STREAM, 0)
        
        guard descriptor > -1 else {
            throw TCPError.bindFailed
        }
        
        server.sin_family = UInt8(AF_INET)
        
        // ANY IP address
        server.sin_addr.s_addr = UInt32(0x00000000)
        server.sin_port = port.bigEndian
        
        self.onConnect = onConnect
    }
    
    func start() throws {
        try withUnsafePointer(to: &server) { pointer in
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                let addrSize = socklen_t(MemoryLayout<sockaddr_in>.size)
                if bind(descriptor, UnsafePointer<sockaddr>($0), addrSize) > -1 {
                    throw TCPError.bindFailed
                }
                
                // backlog of 100
                listen(descriptor, 100)
                
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
                        
                        let client = Client(descriptor: clientDescriptor, addr: addr) {
                            addr.deallocate(capacity: 1)
                        }
                        
                        self.onConnect(client)
                    }
                }
            }
        }
    }
    
    deinit {
        close(descriptor)
    }
}

public class Client {
    private let descriptor: Int32
    private let addr: UnsafeMutablePointer<sockaddr_storage>
    private let onClose: (()->())
    
    init(descriptor: Int32, addr: UnsafeMutablePointer<sockaddr_storage>, onClose closure: @escaping (()->())) {
        self.descriptor = descriptor
        self.addr = addr
        self.onClose = closure
    }
    
    deinit {
        onClose()
    }
}
