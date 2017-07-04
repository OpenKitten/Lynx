/// An HTTP method
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

/// Class so you don't copy the data at all and treat them like a state machine
public final class Request {
    public let method: Method
    public var url: Path
    public let headers: Headers
    public let body: UnsafeMutableBufferPointer<UInt8>?
    
    /// Creates a new request
    init(with method: Method, url: Path, headers: Headers, body: UnsafeMutableBufferPointer<UInt8>?) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
    
    deinit {
        if let body = body {
            body.baseAddress?.deallocate(capacity: body.count)
        }
    }
}


