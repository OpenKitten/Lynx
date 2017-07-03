#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/// A constant to be used for parsing
fileprivate let multipartContentType = [UInt8]("multipart/form-data; boundary=".utf8)

extension Request {
    /// Parses the request's body into a `MultipartForm`
    public var multipart: MultipartForm? {
        if let boundary = self.headers["Content-Type"] {
            guard memcmp(boundary.bytes, multipartContentType, multipartContentType.count) == 0 ,boundary.bytes.count > multipartContentType.count &+ 2 else {
                return nil
            }
            
            return MultipartForm(
                boundary: Array(boundary.bytes[multipartContentType.count..<boundary.bytes.count]),
                bodyFrom: self)
        }
        
        return nil
    }
}

/// Hardcoded constant for parsing
fileprivate let contentDispositionMark = [UInt8]("Content-Disposition: ".utf8)

/// Hardcoded constant for parsing
fileprivate let formData = [UInt8]("form-data;".utf8)

/// Hardcoded constant for parsing
fileprivate let attachment = [UInt8]("attachment;".utf8)

/// A parsed Multipart Form
public final class MultipartForm {
    /// The request containing the body
    ///
    /// A reference is kept to keep the pointers pointing to alive data
    ///
    /// This prevents unnecessary copies
    let request: Request
    
    /// The parsed parts
    let parts: [Part]
    
    /// A single Multipart pair
    ///
    /// Contains a key and value
    public struct Part {
        /// A multipart value type
        enum PartType {
            /// A string value
            case value
        }
        
        let name: UnsafeBufferPointer<UInt8>
        let type: PartType
        let data: UnsafeBufferPointer<UInt8>
        
        /// The key associated with this part
        public var key: String {
            return String(bytes: name, encoding: .utf8) ?? ""
        }
        
        /// Parses the String value associated with this part, if possible/reasonable
        public var string: String? {
            guard type == .value else {
                return nil
            }
            
            return String(bytes: data, encoding: .utf8)
        }
    }
    
    /// Accesses a Part at the provided key, if there is any
    public subscript(_ key: String) -> MultipartForm.Part? {
        let key = [UInt8](key.utf8)
        
        for part in parts {
            if part.name.count == key.count && memcmp(part.name.baseAddress, key, key.count) == 0 {
                return part
            }
        }
        
        return nil
    }
    
    /// Creates a new multipart form
    init?(boundary: [UInt8], bodyFrom request: Request) {
        guard let buffer = request.body else {
            return nil
        }
        
        guard var base = UnsafePointer(buffer.baseAddress) else {
            return nil
        }
        
        var currentPosition = 0
        var length = buffer.count
        var parts = [Part]()
        
        while boundary.count &+ 4 < length {
            // '--'
            guard base[0] == 0x2d, base[1] == 0x2d else {
                return nil
            }
            
            base = base.advanced(by: 2)
            
            guard memcmp(base, boundary, boundary.count) == 0 else {
                return nil
            }
            
            guard base[boundary.count] == 0x0d, base[boundary.count &+ 1] == 0x0a else {
                // '--'
                guard base[boundary.count] == 0x2d, base[boundary.count &+ 1] == 0x2d else {
                    return nil
                }
                
                self.parts = parts
                self.request = request
                return
            }
            
            length = length &- boundary.count
            base = base.advanced(by: boundary.count &+ 2)
            
            guard contentDispositionMark.count < length, memcmp(base, contentDispositionMark, contentDispositionMark.count) == 0 else {
                return nil
            }
            
            length = length &- contentDispositionMark.count
            base = base.advanced(by: contentDispositionMark.count)
            
            // ' '
            base.peek(until: 0x20, length: &length, offset: &currentPosition)
            
            guard currentPosition > 0 else {
                return nil
            }
            
            let contentDisposition = base.buffer(until: &currentPosition)
            
            if formData.count &+ 1 < length, contentDisposition.count == formData.count, memcmp(contentDisposition.baseAddress, formData, formData.count) == 0 {
                // ' '
                guard contentDisposition.baseAddress?[contentDisposition.count] == 0x20 else {
                    return nil
                }
                
                // '"'
                base.peek(until: 0x22, length: &length, offset: &currentPosition)
                
                guard currentPosition > 1 else {
                    return nil
                }
                
                // '"'
                base.peek(until: 0x22, length: &length, offset: &currentPosition)
                
                let nameBuffer = base.buffer(until: &currentPosition)
                
                // \r\n\r\n
                guard 6 < length, base[0] == 0x0d, base[1] == 0x0a, base[2] == 0x0d, base[3] == 0x0a else {
                    return nil
                }
                
                length = length &- 4
                base = base.advanced(by: 4)
                
                base.peek(until: 0x0d, length: &length, offset: &currentPosition)
                
                // \r\n
                guard length > 1, base[0] == 0x0a, base[-1] == 0x0d else {
                    return nil
                }
                
                let dataBuffer = base.buffer(until: &currentPosition)
                
                // skip \n
                base = base.advanced(by: 1)
                
                parts.append(Part(name: nameBuffer, type: .value, data: dataBuffer))
            } else {
                // unsupported
                return nil
            }
        }
        
        self.parts = parts
        self.request = request
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
