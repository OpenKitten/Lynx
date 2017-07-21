/// An HTTP request path
public struct Path : Hashable, CustomDebugStringConvertible, Codable, ExpressibleByStringLiteral {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        
        self.init(url: string)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.string)
    }
    
    /// The underlying string
    private var utf8String: UTF8String
    
    /// The associated query
    public var query: Query
    
    /// Serialized as UTF8 String bytes
    public var bytes: [UInt8] {
        guard let buffer = utf8String.makeBuffer() else {
            return []
        }
        
        return Array(buffer)
    }
    
    /// The tokens for this route and their associated value
    public internal(set) var tokens = [String: String]()
    
    /// Reads memory unsafelyArray
    /// Can crash if deallocated during use
    /// Use in a synchronous manner and copy results
    internal var components: [UnsafeBufferPointer<UInt8>] {
        // '/'
        return self.utf8String.slice(by: 0x2f)
    }
    
    /// This path represented as a String
    public var string: String {
        let path = String(bytes: bytes, encoding: .utf8) ?? ""
        
        if self.query.storage.utf8String.byteCount > 0 {
            let query = self.query.string
            return path + "?" + query
        }
        
        return path
    }
    
    /// Makes this path hashable for use in Dictionaries as a key
    public var hashValue: Int {
        return utf8String.hashValue
    }
    
    /// Equates two paths
    public static func ==(lhs: Path, rhs: Path) -> Bool {
        return lhs.utf8String == rhs.utf8String
    }
    
    /// Creates a new path
    init(path: UnsafeBufferPointer<UInt8>, query: UnsafeBufferPointer<UInt8>?) {
        self.utf8String = UTF8String(buffer: path)
        
        if let query = query {
            self.query = Query(buffer: query)
        } else {
            self.query = Query()
        }
    }
    
    public init(url: String) {
        let buffer = [UInt8](url.utf8)
        
        // ?
        if let index = buffer.index(of: 0x3f), index < url.characters.count {
            let path = UnsafeBufferPointer(start: buffer, count: index)
            
            let query = buffer.withUnsafeBufferPointer { buffer in
                return UnsafeBufferPointer(start: buffer.baseAddress?.advanced(by: index + 1), count: buffer.count - index - 1)
            }
            
            self.init(path: path, query: query)
        } else {
            self.init(path: UnsafeBufferPointer(start: buffer, count: buffer.count), query: nil)
        }
    }
    
    public init(stringLiteral value: String) {
        self.init(url: value)
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.init(url: value)
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(url: value)
    }
    
    /// Useful for debugging
    public var debugDescription: String {
        return self.string
    }
}
