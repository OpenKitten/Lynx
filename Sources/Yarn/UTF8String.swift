import Darwin

internal class UTF8StringBuffer {
    internal var bytes: UnsafeMutableBufferPointer<UInt8> {
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
    
    init() {
        self.bytes = UnsafeMutableBufferPointer<UInt8>(start: nil, count: 0)
    }
    
    deinit {
        self.bytes.baseAddress?.deallocate(capacity: self.bytes.count)
    }
    
    init(_ bytes: [UInt8]) {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: bytes.count)
        memcpy(pointer, bytes, bytes.count)
        self.bytes = UnsafeMutableBufferPointer(start: pointer, count: bytes.count)
        
        if bytes.count > 0 {
            for i in 0..<bytes.count {
                hashValue = 31 &* hashValue &+ numericCast(bytes[i])
            }
        }
    }
}

internal struct UTF8String : Hashable {
    var hashValue: Int {
        return buffer.hashValue
    }
    
    var firstByte: UInt8? {
        return buffer.bytes.first
    }
    
    var byteCount: Int {
        return buffer.bytes.count
    }
    
    func slice(by byte: UInt8) -> [UnsafeBufferPointer<UInt8>] {
        guard let address = buffer.bytes.baseAddress else {
            return []
        }
        
        var pointer = UnsafePointer(address)
        var slices = [UnsafeBufferPointer<UInt8>]()
        
        var i = 0
        var length = buffer.bytes.count
        
        while i < length {
            pointer.peek(until: byte, length: &length, offset: &i)
            slices.append(pointer.buffer(until: &i))
        }
        
        return slices
    }
    
    func makeBuffer(from base: Int = 0, to end: Int? = nil) -> UnsafeBufferPointer<UInt8>? {
        let end = end ?? buffer.bytes.count
        
        guard let address = buffer.bytes.baseAddress, base > -1, end <= buffer.bytes.count else {
            return nil
        }
        
        return UnsafeBufferPointer<UInt8>.init(start: address.advanced(by: base), count: end &- base)
    }
    
    func makeString(from base: Int = 0, to end: Int? = nil) -> String? {
        guard let buffer = makeBuffer(from: base, to: end) else {
            return nil
        }
        
        return String(bytes: buffer, encoding: .utf8)
    }
    
    static func ==(lhs: UTF8String, rhs: UTF8String) -> Bool {
        guard lhs.buffer.bytes.count == rhs.buffer.bytes.count else {
            return false
        }
        
        guard let lhsBase = lhs.buffer.bytes.baseAddress, let rhsBase = rhs.buffer.bytes.baseAddress else {
            return lhs.buffer.bytes.baseAddress == rhs.buffer.bytes.baseAddress
        }
        
        return memcmp(lhsBase, rhsBase, lhs.buffer.bytes.count) == 0
    }
    
    static func ==(lhs: UTF8String, rhs: UnsafeBufferPointer<UInt8>) -> Bool {
        guard lhs.buffer.bytes.count == rhs.count else {
            return false
        }
        
        guard let lhsBase = lhs.buffer.bytes.baseAddress, let base = rhs.baseAddress else {
            return lhs.buffer.bytes.baseAddress == nil && rhs.baseAddress == nil
        }
        
        return memcmp(lhsBase, base, rhs.count) == 0
    }
    
    private var buffer: UTF8StringBuffer
    
    init(bytes: [UInt8]) {
        self.buffer = UTF8StringBuffer(bytes)
    }
    
    init(buffer: UnsafeBufferPointer<UInt8>) {
        self.init(bytes: Array(buffer))
    }
    
    init() {
        self.buffer = UTF8StringBuffer()
    }
    
    init(slice: ArraySlice<UInt8>) {
        self.init(bytes: Array(slice))
    }
}

/// TODO: Copy for swift inline optimization

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
