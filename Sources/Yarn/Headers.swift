public typealias HeaderValue = HeaderKey

public struct HeaderKey : Hashable, CustomDebugStringConvertible {
    private var utf8String: UTF8String
    
    public var bytes: [UInt8] {
        guard let buffer = utf8String.makeBuffer() else {
            return []
        }
        
        return Array(buffer)
    }
    
    public var string: String {
        return utf8String.makeString() ?? ""
    }
    
    public var hashValue: Int {
        return utf8String.hashValue
    }
    
    public static func ==(lhs: HeaderKey, rhs: HeaderKey) -> Bool {
        return lhs.utf8String == rhs.utf8String
    }
    
    public init(bytes: [UInt8]) {
        self.utf8String = UTF8String(bytes: bytes)
    }
    
    public init(buffer: UnsafeBufferPointer<UInt8>) {
        self.utf8String = UTF8String(buffer: buffer)
    }
    
    public var debugDescription: String {
        return self.string
    }
}

public struct Path : Hashable, CustomDebugStringConvertible {
    private var utf8String: UTF8String
    private var query: UTF8String?
    
    public var bytes: [UInt8] {
        guard let buffer = utf8String.makeBuffer() else {
            return []
        }
        
        return Array(buffer)
    }
    
    public internal(set) var tokens = [String: String]()
    
    /// Reads memory unsafelyArray
    /// Can crash if deallocated during use
    /// Use short-term only
    internal var components: [UnsafeBufferPointer<UInt8>] {
        // '/'
        return self.utf8String.slice(by: 0x2f)
    }
    
    public var string: String {
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
    
    public var hashValue: Int {
        return utf8String.hashValue
    }
    
    public static func ==(lhs: Path, rhs: Path) -> Bool {
        return lhs.utf8String == rhs.utf8String
    }
    
    public init(path: UnsafeBufferPointer<UInt8>, query: UnsafeBufferPointer<UInt8>?) {
        self.utf8String = UTF8String(buffer: path)
        
        if let query = query {
            self.query = UTF8String(buffer: query)
        }
    }
    
    public var debugDescription: String {
        return self.string
    }
}

extension UTF8String : ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(bytes: [UInt8](value.utf8))
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.init(bytes: [UInt8](value.utf8))
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(bytes: [UInt8](value.utf8))
    }
}

public enum Method : Equatable, Hashable {
    case get, put, post, delete, patch, options
    case unknown(String)
    
    public var hashValue: Int {
        switch self {
        case .get: return 2000
        case .put: return 2001
        case .post: return 2002
        case .delete: return 2003
        case .patch: return 2004
        case .options: return 2005
        case .unknown(let s):  return 2006 &+ s.hashValue
            
        }
    }
    
    public static func ==(lhs: Method, rhs: Method) -> Bool {
        switch (lhs, rhs) {
        case (.get, .get): return true
        case (.put, .put): return true
        case (.post, .post): return true
        case (.delete, .delete): return true
        case (.patch, .patch): return true
        case (.options, .options): return true
        case (.unknown(let lhsString), .unknown(let rhsString)): return lhsString == rhsString
        default: return false
        }
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
