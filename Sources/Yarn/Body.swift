public class Body {
    public let buffer: UnsafeMutableBufferPointer<UInt8>
    public let deallocate: Bool
    
    public init(pointingTo buffer: UnsafeMutableBufferPointer<UInt8>, deallocating: Bool) {
        self.buffer = buffer
        self.deallocate = deallocating
    }
    
    deinit {
        if deallocate {
            buffer.baseAddress?.deallocate(capacity: buffer.count)
        }
    }
}

public protocol BodyRepresentable {
    func makeBody() throws -> Body
}

extension Body : BodyRepresentable {
    public func makeBody() throws -> Body {
        return self
    }
}

extension String : BodyRepresentable {
    public func makeBody() throws -> Body {
        let allocated = UnsafeMutablePointer<UInt8>.allocate(capacity: self.utf8.count)
        allocated.initialize(from: [UInt8](self.utf8), count: self.utf8.count)
        
        let buffer = UnsafeMutableBufferPointer<UInt8>(start: allocated, count: self.utf8.count)
        
        return Body(pointingTo: buffer, deallocating: true)
    }
}
