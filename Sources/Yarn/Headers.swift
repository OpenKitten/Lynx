public typealias HeaderValue = UTF8String
public typealias HeaderKey = UTF8String
public typealias Path = UTF8String

public struct UTF8String : Hashable, CustomDebugStringConvertible {
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

public struct Headers : ExpressibleByDictionaryLiteral {
    public private(set) var serialized: [UInt8]
    private var hashes: [(hash: Int, position: Int)]
    
    public subscript(key: HeaderKey) -> HeaderValue? {
        get {
            guard let position = hashes.first(where: { $0.0 == key.hashValue })?.position else {
                return nil
            }
            
            // key + ": "
            let start = position &+ key.bytes.count &+ 2
            
            guard start < serialized.count else {
                return nil
            }
            
            var buffer = [UInt8]()
            
            for i in start..<serialized.count {
                // \r
                guard serialized[i] != 0x0d else {
                    return HeaderValue(bytes: buffer)
                }
                
                buffer.append(serialized[i])
            }
            
            return nil
        }
        set {
            if let index = hashes.index(where: { $0.0 == key.hashValue }) {
                if let newValue = newValue {
                    let position = hashes[index].position
                    
                    let start = position &+ key.bytes.count
                    
                    var final: Int?
                    
                    finalChecker: for i in start..<serialized.count {
                        // \r
                        if serialized[i] == 0x0d {
                            final = i
                            break finalChecker
                        }
                    }
                    
                    if let final = final {
                        serialized.replaceSubrange(start..<final, with: newValue.bytes)
                    }
                } else {
                    hashes.remove(at: index)
                }
                // overwrite or remove on `nil`
            } else if let newValue = newValue {
                hashes.append((key.hashValue, serialized.endIndex))
                serialized.append(contentsOf: key.bytes)
                
                // ": "
                serialized.append(0x3a)
                serialized.append(0x20)
                serialized.append(contentsOf: newValue.bytes)
                serialized.append(0x0d)
                serialized.append(0x0a)
            }
        }
    }
    
    public init() {
        self.serialized = []
        self.hashes = []
    }
    
    public init(dictionaryLiteral elements: (HeaderKey, HeaderValue)...) {
        self.serialized = []
        self.hashes = []
        
        for (key, value) in elements {
            self[key] = value
        }
    }
}
