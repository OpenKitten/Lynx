public struct Path : Hashable, CustomDebugStringConvertible {
    private var utf8String: UTF8String
    public var query: Query
    
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
            self.query = Query(buffer: query)
        } else {
            self.query = Query()
        }
    }
    
    public var debugDescription: String {
        return self.string
    }
}
