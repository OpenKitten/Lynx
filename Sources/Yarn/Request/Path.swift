/// An HTTP request path
public struct Path : Hashable, CustomDebugStringConvertible {
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
        return String(bytes: bytes, encoding: .utf8) ?? ""
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
    
    /// Useful for debugging
    public var debugDescription: String {
        return self.string
    }
}
