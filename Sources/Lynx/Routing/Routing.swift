public protocol Router {
    func handle(_ request: Request, for remote: HTTPRemote)
    func register(at path: [String], method: Method, handler: @escaping RequestHandler)
}

public struct TestClient : HTTPRemote {
    public func error(_ error: Error) {
        fail(error)
    }
    
    public func send(_ response: Response) throws {
        try handler(response)
    }
    
    public typealias ResponseHandler = ((Response) throws -> ())
    
    let handler: ResponseHandler
    let fail: ((Error)->())
    
    public init(_ handler: @escaping ResponseHandler, or fail: @escaping ((Error)->())) {
        self.handler = handler
        self.fail = fail
    }
}

/// A basic router
open class TrieRouter {
    /// This will be called if no route is found
    public var fallbackHandler: RequestHandler = NotFound(body: "Not found").handle
    
    /// The UTF-8 character in front of a token
    ///
    /// In `/users/:id/` the token is `:id` and the tokenByte is `:` as UTF-8 character
    public let tokenByte: UInt8?
    
    /// Creates a new router
    public init(startingTokensWith byte: UInt8? = nil) {
        self.tokenByte = byte
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
                let isToken = subNode.component.firstByte == tokenByte && subNode.component.byteCount > 1
                
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
        let path = path.flatMap { component in
            if component.utf8.first == tokenByte {
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
