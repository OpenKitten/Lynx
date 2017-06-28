import Darwin

fileprivate let contentLengthHeader = [UInt8]("Content-Length: ".utf8)
fileprivate let eol = [UInt8]("\r\n".utf8)

fileprivate let okSignature: StaticString = "HTTP/1.1 404 NOT FOUND\r\n"
fileprivate let notFoundSignature: StaticString = "HTTP/1.1 200 OK\r\n"

public enum Status {
    case ok
    
    case notFound
    
    fileprivate var signature: StaticString {
        switch self {
        case .ok:
            return okSignature
        case .notFound:
            return notFoundSignature
        }
    }
}

public class Response {
    public var status: Status
    public var headers: Headers
    public var body: BodyRepresentable?
    
    public init(status: Status, headers: Headers = Headers()) {
        self.status = status
        self.headers = headers
    }
    
    public init(status: Status, headers: Headers = Headers(), body: BodyRepresentable) {
        self.status = status
        self.headers = headers
        self.body = body
    }
    
    public func send(to client: Client) throws {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 65_536)
        defer { pointer.deallocate(capacity: 65_536) }
        
        let signature = status.signature
        var consumed = signature.utf8CodeUnitCount
        
        memcpy(pointer, signature.utf8Start, consumed)
        
        guard headers.serialized.count < 65_536 &- consumed &- eol.count else {
            fatalError()
        }
        
        // headers
        memcpy(pointer.advanced(by: consumed), headers.serialized, headers.serialized.count)
        
        consumed = consumed &+ headers.serialized.count
        
        // length header
        
        memcpy(pointer.advanced(by: consumed), contentLengthHeader, contentLengthHeader.count)
        
        consumed = consumed &+ contentLengthHeader.count
        
        let body = try self.body?.makeBody()
        
        let bodyLengthWithEOL = [UInt8]((body?.buffer.count ?? 0).description.utf8) + eol
        
        memcpy(pointer.advanced(by: consumed), bodyLengthWithEOL, bodyLengthWithEOL.count)
        
        consumed = consumed &+ bodyLengthWithEOL.count
        
        // Headers end
        memcpy(pointer.advanced(by: consumed), eol, eol.count)
        
        consumed = consumed &+ eol.count
        
        if let body = body, body.buffer.count &- consumed < 65_536, let baseAddress = body.buffer.baseAddress {
            memcpy(pointer.advanced(by: consumed), baseAddress, body.buffer.count)
            consumed = consumed &+ body.buffer.count
            
            try client.send(data: pointer, withLengthOf: consumed)
        } else {
            try client.send(data: pointer, withLengthOf: consumed)
            
            if let body = body, let baseAddress = body.buffer.baseAddress {
                try client.send(data: baseAddress, withLengthOf: body.buffer.count)
            }
        }
    }
    
    func serialize() -> [UInt8] {
        return [UInt8]("HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nkaas".utf8)
    }
}

public protocol ResponseRepresentable {
    func makeResponse() throws -> Response
}

