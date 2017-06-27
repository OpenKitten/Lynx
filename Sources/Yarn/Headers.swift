public struct HeaderKey : Hashable, CustomDebugStringConvertible {
    public var bytes: [UInt8] {
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
    
    public private(set) var hashValue = 0
    
    public var string: String {
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
    
    public static func ==(lhs: HeaderKey, rhs: HeaderKey) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
    
    public init(bytes: [UInt8]) {
        self.bytes = bytes
        
        if bytes.count > 0 {
            for i in 0..<bytes.count {
                hashValue = 31 &* hashValue &+ numericCast(bytes[i])
            }
        }
    }
    
    public init(bytes: UnsafeBufferPointer<UInt8>) {
        self.init(bytes: Array(bytes))
    }
    
    public var debugDescription: String {
        return self.string
    }
}

extension HeaderKey : ExpressibleByStringLiteral {
    /// A dictionary literal that makes this a custom ProjectionExpression
    public init(stringLiteral value: String) {
        self.init(bytes: [UInt8](value.utf8))
    }
    
    /// A dictionary literal that makes this a custom ProjectionExpression
    public init(unicodeScalarLiteral value: String) {
        self.init(bytes: [UInt8](value.utf8))
    }
    
    /// A dictionary literal that makes this a custom ProjectionExpression
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(bytes: [UInt8](value.utf8))
    }
}
