import Darwin

fileprivate let contentLengthHeader = [UInt8]("Content-Length: ".utf8)
fileprivate let signature = [UInt8]("HTTP/1.1 404 NOT FOUND\r\n".utf8)
fileprivate let eol = [UInt8]("\r\n".utf8)

public class NotFound {
    public var headers: Headers
    public var body: UnsafeBufferPointer<UInt8>? {
        didSet {
            self.bodyLengthWithEOL = [UInt8]((body?.count ?? 0).description.utf8) + eol
        }
    }
    
    public var bodyLengthWithEOL: [UInt8]
    
    init(headers: Headers = Headers(), body: UnsafeBufferPointer<UInt8>? = nil) {
        self.headers = headers
        self.body = body
        self.bodyLengthWithEOL = [UInt8]((body?.count ?? 0).description.utf8) + eol
    }
    
    public func handle(_ request: Request, for client: Client) {
        do {
            let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 65_536)
            defer { pointer.deallocate(capacity: 65_536) }
            var consumed = signature.count
            
            memcpy(pointer, signature, consumed)
            
            guard headers.serialized.count < 65_536 &- consumed &- eol.count else {
                fatalError()
            }
            
            // headers
            memcpy(pointer.advanced(by: consumed), headers.serialized, headers.serialized.count)
            
            consumed = consumed &+ headers.serialized.count
            
            // length header
            
            memcpy(pointer.advanced(by: consumed), contentLengthHeader, contentLengthHeader.count)
            
            consumed = consumed &+ contentLengthHeader.count
            
            memcpy(pointer.advanced(by: consumed), bodyLengthWithEOL, bodyLengthWithEOL.count)
            
            consumed = consumed &+ bodyLengthWithEOL.count
            
            // Headers end
            memcpy(pointer.advanced(by: consumed), eol, eol.count)
            
            consumed = consumed &+ eol.count
            
            if let body = body, body.count &- consumed < 65_536, let baseAddress = body.baseAddress {
                memcpy(pointer.advanced(by: consumed), baseAddress, body.count)
                consumed = consumed &+ body.count
                
                try client.send(data: pointer, withLengthOf: consumed)
            } else {
                try client.send(data: pointer, withLengthOf: consumed)
                
                if let body = body, let baseAddress = body.baseAddress {
                    try client.send(data: baseAddress, withLengthOf: body.count)
                }
            }
        } catch {
            client.close()
        }
    }
}

