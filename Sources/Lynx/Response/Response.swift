#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

fileprivate let contentLengthHeader = [UInt8]("Content-Length: ".utf8)
fileprivate let eol = [UInt8]("\r\n".utf8)

fileprivate let upgradeSignature = [UInt8]("HTTP/1.1 101 Switching Protocols\r\n".utf8)
fileprivate let okSignature = [UInt8]("HTTP/1.1 200 OK\r\n".utf8)
fileprivate let notFoundSignature = [UInt8]("HTTP/1.1 404 NOT FOUND\r\n".utf8)

/// The HTTP response status
///
/// TODO: Add more status codes
public enum Status {
    case upgrade
    
    case ok
    
    case notFound
    
    case internalServerError
    
    case custom(code: Int, message: String)
    
    /// Returns a signature, for internal purposes only
    fileprivate var signature: [UInt8] {
        switch self {
        case .upgrade:
            return upgradeSignature
        case .ok:
            return okSignature
        case .notFound:
            return notFoundSignature
        case .internalServerError:
            return [UInt8]("HTTP/1.1 500 INTERNAL SERVER ERROR\r\n".utf8)
        case .custom(let code, let message):
            return code.description.utf8 + [0x20] + message.utf8
        }
    }
    
    /// Creates a new (custom) status code
    public init(_ code: Int, message: String = "") {
        switch code {
        case 101: self = .upgrade
        case 200: self = .ok
        case 404: self = .notFound
        case 500: self = .internalServerError
        default: self = .custom(code: code, message: message)
        }
    }
}

/// An HTTP response
///
/// To be returned to a client
public class Response {
    /// The resulting status
    public var status: Status
    
    /// The headers to be responded with
    public var headers: Headers
    
    /// The body, can contain anything you want to return
    ///
    /// An image, JSON, PDF, HTML etc..
    ///
    /// Must be nil for requests like `HEAD`
    public var body: BodyRepresentable?
    
    /// Creates a new bodyless response
    public init(status: Status, headers: Headers = Headers()) {
        self.status = status
        self.headers = headers
    }
    
    /// Creates a new response with a body
    public init(status: Status, headers: Headers = Headers(), body: BodyRepresentable) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

public protocol HTTPRemote {
    func send(_ response: Response) throws
    func error(_ error: Error)
}

extension Client : HTTPRemote {
    public func error(_ error: Error) {
        self.close()
    }
    
    public func send(_ response: Response) throws {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 65_536)
        defer { pointer.deallocate(capacity: 65_536) }
        
        let signature = response.status.signature
        var consumed = signature.count
        
        memcpy(pointer, signature, consumed)
        
        guard response.headers.buffer.count &+ consumed &+ 2 < 65_536 else {
            fatalError()
        }
        
        // headers
        memcpy(pointer.advanced(by: consumed), response.headers.buffer.baseAddress, response.headers.buffer.count)
        
        consumed = consumed &+ response.headers.buffer.count
        
        // length header
        
        memcpy(pointer.advanced(by: consumed), contentLengthHeader, contentLengthHeader.count)
        
        consumed = consumed &+ contentLengthHeader.count
        
        let body = try response.body?.makeBody()
        
        let bodyLengthWithEOL = [UInt8]((body?.buffer.count ?? 0).description.utf8) + eol
        
        memcpy(pointer.advanced(by: consumed), bodyLengthWithEOL, bodyLengthWithEOL.count)
        
        consumed = consumed &+ bodyLengthWithEOL.count
        
        // Headers end
        memcpy(pointer.advanced(by: consumed), eol, eol.count)
        
        consumed = consumed &+ eol.count
        
        if let body = body, body.buffer.count &- consumed < 65_536, let baseAddress = body.buffer.baseAddress {
            memcpy(pointer.advanced(by: consumed), baseAddress, body.buffer.count)
            consumed = consumed &+ body.buffer.count
            
            try self.send(data: pointer, withLengthOf: consumed)
        } else {
            try self.send(data: pointer, withLengthOf: consumed)
            
            if let body = body, let baseAddress = body.buffer.baseAddress {
                try self.send(data: baseAddress, withLengthOf: body.buffer.count)
            }
        }
    }
}

/// Can be representable as a response
public protocol ResponseRepresentable {
    func makeResponse() throws -> Response
}

