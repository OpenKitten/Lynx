/// An HTTP Request method
///
/// Used to provide information about the kind of action being requested
public enum Method : Equatable, Hashable {
    /// A GET request is used to retrieve information, such as a web-page or profile picture
    ///
    /// GET Requests will not provide a body
    case get
    
    /// PUT is used to overwrite information.
    ///
    /// `PUT /users/1` is should replace the information for the user with ID `1`
    ///
    /// It may create a new entity if the requested entity didn't exist.
    case put
    
    /// POST is used to create a new entity, such as a reaction in the comment section
    ///
    /// One of the more common methods, since it's also used to create new users and log in existing users
    case post
    
    /// DELETE is an action that... deletes an entity.
    ///
    /// DELETE requests cannot provide a body
    case delete
    
    /// PATCH is similar to PUT in that it updates an entity.
    ///
    /// ..but where PUT replaces an entity, PATCH only updated the specified fields
    case patch
    
    /// OPTIONS is used by the browser to check if the conditions allow a specific request.
    ///
    /// Often used for secutity purposes.
    case options
    
    /// There are many other methods. But the other ones are most commonly used.
    ///
    /// This `.other` contains the provided METHOD
    case other(String)
    
    public var hashValue: Int {
        switch self {
        case .get: return 2000
        case .put: return 2001
        case .post: return 2002
        case .delete: return 2003
        case .patch: return 2004
        case .options: return 2005
        case .other(let s):  return 2006 &+ s.hashValue
            
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
        case (.other(let lhsString), .other(let rhsString)): return lhsString == rhsString
        default: return false
        }
    }
}

/// Class so you don't copy the data at all and treat them like a state machine
open class Request {
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


