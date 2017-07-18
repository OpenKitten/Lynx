#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/// Simple 404 handler, useful for default routes
public class NotFound {
    /// Caches the response
    private var response: Response
    
    /// Creates a new body-less NotFound handler
    public init(headers: Headers = Headers()) {
        self.response = Response(status: .notFound, headers: headers)
    }
    
    /// Creates a new NotFound handler with a body
    public init(headers: Headers = Headers(), body: BodyRepresentable) {
        self.response = Response(status: .notFound, headers: headers, body: body)
    }
    
    /// Responds with 404
    public func handle(_ request: Request, for remote: HTTPRemote) {
        do {
            try remote.send(response)
        } catch {
            remote.error(error)
        }
    }
}

