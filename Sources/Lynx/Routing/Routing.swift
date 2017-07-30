/// A router, can register routes and route requests
public protocol Router {
    /// Handles incoming requests
    func handle(_ request: Request, for remote: HTTPRemote)
    
    /// Registers a new route
    func register(at path: [String], method: Method, handler: @escaping RequestHandler)
}

/// A client that's useful for unit tests
public struct TestClient : HTTPRemote {
    /// Handles an error during the handling of the request
    public func error(_ error: Error) {
        fail(error)
    }
    
    /// Handle the Response
    public func send(_ response: Response) throws {
        try handler(response)
    }
    
    public typealias ResponseHandler = ((Response) throws -> ())
    
    let handler: ResponseHandler
    let fail: ((Error)->())
    
    /// Create a new unit test client
    public init(_ handler: @escaping ResponseHandler, or fail: @escaping ((Error)->())) {
        self.handler = handler
        self.fail = fail
    }
}

/// A basic router
open class TrieRouter {
    public struct Config {
        /// The UTF-8 character in front of a token
        ///
        /// In `/users/:id/` the token is `:id` and the tokenByte is `:` as UTF-8 character
        ///
        /// If this is `nil`, no token prefixes exist for path parameters, thus path parameters will not be processed
        public var tokenByte: UInt8? = 0x3a
        
        /// If a path component consists exclusively of this literal it'll be seen as an "any" component, meaning any component matches this
        ///
        /// Example route using the default setting: `/api/v1/*/friends/`
        ///
        /// **Matches:**
        ///
        /// `/api/v1/joannis/friends/`
        ///
        /// **Does not match:**
        ///
        /// `/api/v1/friends/`
        ///
        /// `/api/v1/joannis/profile/friends/`
        ///
        /// If this is `nil`, the "anyComponent" check will not be run, thus paths need to be entered literally
        public var anyComponent: String?
        
        /// If a path component consists exclusively of this literal it'll be seen as an "any" set of components, meaning any multiple components match this
        ///
        /// Example route using the default setting: `/api/v1/**/friends/`
        ///
        /// Matches:
        ///
        /// `/api/v1/friends/`
        ///
        /// `/api/v1/joannis/friends/`
        ///
        /// `/api/v1/testuser/profile/friends/`
        ///
        /// If this is `nil`, the "anyComponent" check will not be run, thus paths need to be entered literally
        public var anyMultiComponents: String? = "**"
        
        /// Creates a new basic config file
        public init() {}
    }
    
    /// This will be called if no route is found
    public var fallbackHandler: RequestHandler = NotFound(body: "Not found").handle
    
    /// The router's configuration
    public let config: TrieRouter.Config
    
    /// Creates a new router
    public init(config: TrieRouter.Config = TrieRouter.Config()) {
        self.config = config
    }
    
    /// Changes the default handler
    public func handleFallback(using closure: @escaping RequestHandler) {
        self.fallbackHandler = closure
    }
    
    /// Handles a request from the HTTP server
    public func handle(_ request: Request, for remote: HTTPRemote) {
        guard let node = findNode(at: request.path, for: request) else {
            self.fallbackHandler(request, remote)
            return
        }
        
        guard let handler = node.leafs[request.method] else {
            self.fallbackHandler(request, remote)
            return
        }
        
        handler(request, remote)
    }
    
    /// Finds a matching route
    fileprivate func findNode(at path: Path, for request: Request) -> TrieRouterNode? {
        var node = self.node
        var currentIndex = 0
        let components = path.components
        
        recursiveSearch: for component in components {
            defer { currentIndex = currentIndex &+ 1 }
            
            guard component.count > 0 else {
                continue
            }
            
            for subNode in node.subNodes {
                let isToken = subNode.component.firstByte == self.config.tokenByte && subNode.component.byteCount > 1
                
                // colon is acceptable for tokenized strings
                if subNode.component == component || isToken {
                    if !isToken {
                        node = subNode
                        continue recursiveSearch
                    } else if isToken,
                        let token = subNode.component.makeString(from: 1),
                        currentIndex < components.count,
                        let value = String(bytes: components[currentIndex], encoding: .utf8) {
                        request.path.tokens[token] = value
                        node = subNode
                        continue recursiveSearch
                    }
                }
            }
            
            return nil
        }
        
        return node
    }
    
    /// A public API for registering a new route
    public func register(at path: [String], method: Method, handler: @escaping RequestHandler) {
        let basePath = path.map { $0.split(separator: "/") }.reduce([], +).map(String.init)
        
        let path = basePath.flatMap { component in
            if component.utf8.first == self.config.tokenByte {
                return component
            } else {
                return component.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            }
        }.flatMap { UTF8String(bytes: [UInt8]($0.utf8)) }
            
        self.register(at: path, method: method, handler: handler)
    }
    
    /// An internal API to register a new route with slightly more performance
    internal func register(at path: [UTF8String], method: Method, handler: @escaping RequestHandler) {
        var node = self.node
        var path = path.filter { $0.byteCount > 0 }
        
        var done = 0
        
        recursiveSearch: for component in path {
            guard component.byteCount > 0 else {
                continue
            }
            
            for subNode in node.subNodes {
                if subNode.component == component {
                    node = subNode
                    done = done &+ 1
                    continue recursiveSearch
                }
            }
            
            break recursiveSearch
        }
        
        path.removeFirst(done)
        
        while path.count > 0 {
            let component = path.removeFirst()
            let newNode = TrieRouterNode(at: path, component: component)
            
            node.subNodes.append(newNode)
            node = newNode
        }
        
        node.leafs[method] = handler
    }
    
    internal var node = TrieRouterNode(at: [], component: UTF8String())
}

/// A node used to keep track of routes
final class TrieRouterNode {
    /// All rotues at this path
    internal var leafs = [Method : RequestHandler]()
    
    /// This last path component
    internal var component: UTF8String
    
    /// All routes directly underneath this path
    internal var subNodes = [TrieRouterNode]()
    
    /// All previous components
    internal var components: [UTF8String]
    
    /// Creates a new RouterNode
    internal init(at path: [UTF8String], component: UTF8String) {
        self.components = path
        self.component = component
    }
}
