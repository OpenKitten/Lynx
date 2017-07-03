/// Header keys have the same properties that values have
public typealias HeaderValue = HeaderKey

public struct HeaderKey : Hashable, CustomDebugStringConvertible {
    internal var utf8String: UTF8String
    
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

extension HeaderKey : ExpressibleByStringLiteral {
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

fileprivate final class HeadersStorage {
    var serialized: [UInt8]
    var hashes = [(hash: Int, position: Int)]()
    
    init(serialized: UnsafeBufferPointer<UInt8>) {
        self.serialized = Array(serialized)
    }
    
    init() {
        self.serialized = []
        self.hashes = []
    }
}

public struct Headers : ExpressibleByDictionaryLiteral, CustomDebugStringConvertible {
    private let storage: HeadersStorage
    
    public var debugDescription: String {
        return String(bytes: self.buffer, encoding: .utf8) ?? ""
    }
    
    init(serialized: UnsafeBufferPointer<UInt8>) {
        self.storage = HeadersStorage(serialized: serialized)
    }
    
    var buffer: UnsafeBufferPointer<UInt8> {
        return UnsafeBufferPointer(start: storage.serialized, count: storage.serialized.count)
    }
    
    public subscript(key: HeaderKey) -> HeaderValue? {
        get {
            if let position = storage.hashes.first(where: { $0.0 == key.hashValue })?.position {
                let start = position &+ key.bytes.count &+ 2
                
                guard start < storage.serialized.count else {
                    return nil
                }
                
                for i in start..<storage.serialized.count {
                    // \r
                    guard storage.serialized[i] != 0x0d else {
                        return HeaderValue(buffer: UnsafeBufferPointer(start: UnsafePointer(storage.serialized).advanced(by: start), count: i &- start))
                    }
                }
                
                return nil
            }
            
            var currentPosition = storage.hashes.last?.position ?? 0
            
            var length: Int = storage.serialized.count
            var pointer = UnsafePointer(storage.serialized).advanced(by: currentPosition)
            var keyEnd = 0
            
            // \n
            pointer.peek(until: 0x0a, length: &length, offset: &currentPosition)
            
            while true {
                let keyPointer = pointer
                // colon
                pointer.peek(until: 0x3a, length: &length, offset: &currentPosition)
                
                keyEnd = currentPosition &- 1
                
                guard keyEnd > 0 else {
                    return nil
                }
                
                guard pointer.pointee == 0x20 else {
                    return nil
                }
                
                // Scan until \r so we capture the string
                pointer.peek(until: 0x0d, length: &length, offset: &currentPosition)
                
                guard pointer.pointee == 0x0a else {
                    return nil
                }
                
                guard currentPosition > 1 else {
                    return nil
                }
                
                if key.bytes.count == keyEnd, key.utf8String == UnsafeBufferPointer(start: keyPointer, count: keyEnd) {
                    currentPosition = currentPosition &- 1
                    let buffer = pointer.buffer(until: &currentPosition)
                    return HeaderValue(buffer: buffer)
                }
                
                // skip \n
                pointer = pointer.advanced(by: 1)
            }
        }
        // TODO: UPDATE CACHE
        set {
            if let index = storage.hashes.index(where: { $0.0 == key.hashValue }) {
                if let newValue = newValue {
                    let position = storage.hashes[index].position
                    
                    let start = position &+ key.bytes.count
                    
                    var final: Int?
                    
                    finalChecker: for i in start..<storage.serialized.count {
                        // \r
                        if storage.serialized[i] == 0x0d {
                            final = i
                            break finalChecker
                        }
                    }
                    
                    if let final = final {
                        storage.serialized.replaceSubrange(start..<final, with: newValue.bytes)
                    }
                } else {
                    storage.hashes.remove(at: index)
                }
                // overwrite or remove on `nil`
            } else if let newValue = newValue {
                storage.hashes.append((key.hashValue, storage.serialized.endIndex))
                storage.serialized.append(contentsOf: key.bytes)
                
                // ": "
                storage.serialized.append(0x3a)
                storage.serialized.append(0x20)
                storage.serialized.append(contentsOf: newValue.bytes)
                storage.serialized.append(0x0d)
                storage.serialized.append(0x0a)
            }
        }
    }
    
    public init() {
        self.storage = HeadersStorage()
    }
    
    public init(dictionaryLiteral elements: (HeaderKey, HeaderValue)...) {
        self.storage = HeadersStorage()
        
        for (key, value) in elements {
            self[key] = value
        }
    }
}


// MARK - Copy for swift inline optimization

extension UnsafePointer where Pointee == UInt8 {
    fileprivate func buffer(until length: inout Int) -> UnsafeBufferPointer<UInt8> {
        // - 1 for the skipped byte
        return UnsafeBufferPointer(start: self.advanced(by: -length), count: length &- 1)
    }
    
    fileprivate mutating func peek(until byte: UInt8, length: inout Int, offset: inout Int) {
        offset = 0
        defer { length = length &- offset }
        
        while offset &+ 4 < length {
            if self[0] == byte {
                offset = offset &+ 1
                self = self.advanced(by: 1)
                return
            }
            if self[1] == byte {
                offset = offset &+ 2
                self = self.advanced(by: 2)
                return
            }
            if self[2] == byte {
                offset = offset &+ 3
                self = self.advanced(by: 3)
                return
            }
            offset = offset &+ 4
            defer { self = self.advanced(by: 4) }
            if self[3] == byte {
                return
            }
        }
        
        if offset < length, self[0] == byte {
            offset = offset &+ 1
            self = self.advanced(by: 1)
            return
        }
        if offset &+ 1 < length, self[1] == byte {
            offset = offset &+ 2
            self = self.advanced(by: 2)
            return
        }
        if offset &+ 2 < length, self[2] == byte {
            offset = offset &+ 3
            self = self.advanced(by: 3)
            return
        }
        
        self = self.advanced(by: length &- offset)
        offset = length
    }
}
