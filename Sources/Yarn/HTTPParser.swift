#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

typealias RequestParsedHandler = ((Request)->())

fileprivate let contentLengthKey: HeaderKey = "Content-Length"

internal final class RequestPlaceholder {
    init() { }
    
    var pointer: UnsafePointer<UInt8>!
    var length: Int!
    var currentPosition: Int = 0
    
    var parsable = true {
        didSet {
            if parsable == false {
                self.leftovers.append(contentsOf: UnsafeBufferPointer(start: pointer, count: length))
                return
            }
        }
    }
    
    fileprivate var proceedable: Bool {
        return correct && parsable
    }
    
    var correct = true
    
    var leftovers = [UInt8]()
    var topLineComplete = false
    var complete = false
    
    var method: Method?
    var path: Path?
    var headers: Headers?
    var contentLength = 0
    var bodyLength = 0
    var body: UnsafeMutablePointer<UInt8>?
    
    func empty() {
        self.method = nil
        self.path = nil
        self.headers = nil
        self.topLineComplete = false
        self.complete = false
        self.correct = true
        self.parsable = true
        self.contentLength = 0
        self.bodyLength = 0
        self.body = nil
    }
    
    func parse(_ ptr: UnsafePointer<UInt8>, len: Int) {
        self.pointer = ptr
        self.length = len
        
        func parseMethod() {
            pointer.peek(until: 0x20, length: &length, offset: &currentPosition)
            
            // length + 1
            if currentPosition == 4 {
                if ptr[0] == 0x47, ptr[1] == 0x45, ptr[2] == 0x54 {
                    self.method = .get
                    return
                }
                
                if ptr[0] == 0x50, ptr[1] == 0x55, ptr[2] == 0x54 {
                    self.method = .put
                    return
                }
            } else if currentPosition == 5 {
                if ptr[0] == 0x50, ptr[1] == 0x4f, ptr[2] == 0x53, ptr[3] == 0x54 {
                    self.method = .post
                    return
                }
            } else if currentPosition == 6 {
                if ptr[0] == 0x50, ptr[1] == 0x41, ptr[2] == 0x54, ptr[3] == 0x43, ptr[4] == 0x48 {
                    self.method = .patch
                    return
                }
            } else if currentPosition == 7 {
                if ptr[0] == 0x44, ptr[1] == 0x45, ptr[2] == 0x4c, ptr[3] == 0x45, ptr[4] == 0x54, ptr[5] == 0x45 {
                    self.method = .delete
                    return
                }
            } else if currentPosition == 8 {
                if ptr[0] == 0x4f, ptr[1] == 0x50, ptr[2] == 0x54, ptr[3] == 0x49, ptr[4] == 0x4f, ptr[5] == 0x4e, ptr[6] == 0x53 {
                    self.method = .options
                    return
                }
            }
            
            guard let string = pointer.string(until: &currentPosition) else {
                parsable = false
                return
            }
            
            self.method = .unknown(string)
        }
        
        func parsePath() {
            pointer.peek(until: 0x20, length: &length, offset: &currentPosition)
            
            let buffer = pointer.buffer(until: &currentPosition)
            
            // '?'
            if let index = buffer.index(of: 0x3f), index &+ 1 < buffer.count {
                let path = UnsafeBufferPointer(start: buffer.baseAddress, count: index)
                let query = UnsafeBufferPointer(start: buffer.baseAddress?.advanced(by: index &+ 1), count: buffer.count &- index &- 1)
                
                self.path = Path(path: path, query: query)
            } else {
                self.path = Path(path: buffer, query: nil)
            }
        }
        
        // TODO: malloc and no copies
        func parseHeaders() {
            let start = pointer
            
            while true {
                // \n
                pointer.peek(until: 0x0a, length: &length, offset: &currentPosition)
                
                guard currentPosition > 0 else {
                    correct = false
                    return
                }
                
                if length > 1, pointer[-2] == 0x0d, pointer[0] == 0x0d, pointer[1] == 0x0a {
                    defer {
                        pointer = pointer.advanced(by: 2)
                        length = length &- 2
                    }
                    
                    self.headers = Headers(serialized: UnsafeBufferPointer(start: start, count: start!.distance(to: pointer)))
                    return
                }
            }
        }
        
        guard len > 7 else {
            return
        }
        
        if proceedable, method == nil {
            parseMethod()
        }
        
        if proceedable, path == nil {
            parsePath()
        }
        
        if proceedable, !topLineComplete {
            pointer.peek(until: 0x0a, length: &length, offset: &currentPosition)
            
            guard pointer[-2] == 0x0d else {
                correct = false
                return
            }
            
            topLineComplete = true
        }
        
        if proceedable, headers == nil {
            parseHeaders()
            
            if let cl = headers?[contentLengthKey], let contentLength = Int(cl.string) {
                self.contentLength = contentLength
                self.body = UnsafeMutablePointer<UInt8>.allocate(capacity: self.contentLength)
            }
        }
        
        if length > 0, let body = body {
            let copiedLength = min(length, contentLength &- bodyLength)
            memcpy(body.advanced(by: bodyLength), pointer, copiedLength)
            length = length &- copiedLength
            self.bodyLength = bodyLength &+ copiedLength
            pointer = pointer.advanced(by: copiedLength)
        }
        
        if bodyLength == contentLength {
            complete = true
        }
        
        leftovers.append(contentsOf: UnsafeBufferPointer(start: pointer, count: length))
    }
    
    deinit {
        body?.deallocate(capacity: self.contentLength)
    }
    
    public func makeRequest() -> Request? {
        guard let method = method, let path = path, let headers = headers else {
            return nil
        }
        
        return Request(with: method, url: path, headers: headers, body: UnsafeMutableBufferPointer(start: body, count: contentLength))
    }
}

/// TODO: Copy for swift inline optimization

extension UnsafePointer where Pointee == UInt8 {
    fileprivate func string(until length: inout Int) -> String? {
        return String(bytes: buffer(until: &length), encoding: .utf8)
    }
    
    fileprivate func buffer(until length: inout Int) -> UnsafeBufferPointer<UInt8> {
        return UnsafeBufferPointer(start: self.advanced(by: -length), count: length)
    }
    
    fileprivate mutating func peek(until byte: UInt8, length: inout Int!, offset: inout Int) {
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
