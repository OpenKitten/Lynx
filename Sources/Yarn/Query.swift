public class QueryStorage {
    let utf8String: UTF8String
    var cache = [Int : Int]()
    
    init(buffer: UnsafeBufferPointer<UInt8>) {
        self.utf8String = UTF8String(buffer: buffer)
    }
    
    init() {
        self.utf8String = UTF8String()
    }
}

public struct Query : CustomDebugStringConvertible {
    let storage: QueryStorage
    
    public var debugDescription: String {
        return self.storage.utf8String.makeString() ?? ""
    }
    
    init(buffer: UnsafeBufferPointer<UInt8>) {
        self.storage = QueryStorage(buffer: buffer)
    }
    
    init() {
        self.storage = QueryStorage()
    }
    
    public subscript(key: String) -> String? {
        let key = UTF8String(bytes: [UInt8](key.utf8))
        
        if let position = storage.cache[key.hashValue] {
            // \r
            guard let nextIndex = storage.utf8String.index(of: 0x3d, offset: position) else {
                return nil
            }
            
            if storage.utf8String.byte(at: nextIndex) == 0x26 {
                return storage.utf8String.makeString(from: position, to: nextIndex &- 1)
            } else {
                return storage.utf8String.makeString(from: position, to: nextIndex)
            }
        }
        
        let slices = storage.utf8String.slice(by: 0x26)
        
        var offset = 0
        
        // ampersand
        for slice in slices {
            defer { offset = offset &+ slice.count }
            // equals
            if let index = slice.index(of: 0x3d) {
                let foundKey = UnsafeBufferPointer(start: slice.baseAddress, count: index)
                
                storage.cache[UTF8String.hashValue(of: foundKey)] = index
                
                if key == foundKey {
                    guard slice.count &- index > 1 else {
                        return ""
                    }
                    
                    // if ends with `&`
                    if slice.baseAddress?.advanced(by: slice.count).pointee == 0x26 {
                        // don't include the `&`
                        let value = UnsafeBufferPointer(start: slice.baseAddress?.advanced(by: index &+ 1), count: slice.count &- index &- 1)
                        
                        return String(bytes: value, encoding: .utf8)
                    } else {
                        let value = UnsafeBufferPointer(start: slice.baseAddress?.advanced(by: index &+ 1), count: slice.count &- index)
                        
                        return String(bytes: value, encoding: .utf8)
                    }
                }
            } else if key == slice {
                return ""
            }
        }
        
        return nil
    }
}

extension Request {
    public var query: Query {
        if let body = self.body {
            return Query(buffer: UnsafeBufferPointer(start: body.baseAddress, count: body.count))
        }
        
        return Query()
    }
}
