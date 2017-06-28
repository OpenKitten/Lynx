internal struct UTF8String : Hashable {
    static func ==(lhs: UTF8String, rhs: UTF8String) -> Bool {
        return lhs.bytes == rhs.bytes
    }
    
    static func ==(lhs: UTF8String, rhs: String) -> Bool {
        return lhs.bytes == [UInt8](rhs.utf8)
    }
    
    static func ==(lhs: UTF8String, rhs: UnsafeBufferPointer<UInt8>) -> Bool {
        guard lhs.bytes.count == rhs.count, let base = rhs.baseAddress else {
            return false
        }
        
        for i in 0..<rhs.count {
            guard lhs.bytes[i] == base.advanced(by: i).pointee else {
                return false
            }
        }
        
        return true
    }
    
    internal var bytes: [UInt8] {
        didSet {
            hashValue = 0
            
            guard bytes.count > 0 else {
                return
            }
            
            for i in 0..<bytes.count {
                hashValue = 31 &* hashValue &+ numericCast(bytes[i])
            }
        }
    }
    
    internal private(set) var hashValue = 0
    
    init(bytes: [UInt8]) {
        self.bytes = bytes
        
        if bytes.count > 0 {
            for i in 0..<bytes.count {
                hashValue = 31 &* hashValue &+ numericCast(bytes[i])
            }
        }
    }
    
    init(buffer: UnsafeBufferPointer<UInt8>) {
        self.init(bytes: Array(buffer))
    }
    
    init(slice: ArraySlice<UInt8>) {
        self.init(bytes: Array(slice))
    }
}
