/// A basic router
open class TrieRouter {
    /// This will be called if no route is found
    public var defaultHandler: RequestHandler = NotFound(body: "henk").handle
    
    /// The UTF-8 character in front of a token
    ///
    /// In `/users/:id/` the token is `:id` and the tokenByte is `:` as UTF-8 character
    public let tokenByte: UInt8?
    
    /// Creates a new router
    public init(startingTokensWith byte: UInt8? = nil) {
        self.tokenByte = byte
    }
    
    /// Changes the default handler
    public func handleDefault(using closure: @escaping RequestHandler) {
        self.defaultHandler = closure
    }
    
    /// Handles a request from the HTTP server
    public func handle(_ request: Request, for client: Client) {
        guard let node = findNode(at: request.url, for: request) else {
            self.defaultHandler(request, client)
            return
        }
        
        guard let handler = node.leafs[request.method] else {
            self.defaultHandler(request, client)
            return
        }
        
        handler(request, client)
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
                let isToken = subNode.component.firstByte == tokenByte && subNode.component.byteCount > 1
                
                // colon is acceptable for tokenized strings
                if subNode.component == component || isToken {
                    if isToken,
                        let token = subNode.component.makeString(from: 1),
                        currentIndex < components.count,
                        let value = String(bytes: components[currentIndex], encoding: .utf8) {
                        request.url.tokens[token] = value
                    }
                    
                    node = subNode
                    continue recursiveSearch
                }
            }
            
            break recursiveSearch
        }
        
        return node
    }
    
    /// A public API for registering a new route
    public func register(at path: [String], method: Method, handler: @escaping RequestHandler) {
        self.register(at: path.flatMap { UTF8String(bytes: [UInt8]($0.utf8)) }, method: method, handler: handler)
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
