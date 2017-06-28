open class TrieRouter {
    public var defaultHandler: RequestHandler = NotFound(body: "henk").handle
    public let tokenByte: UInt8?
    
    init(startingTokensWith byte: UInt8? = nil) {
        self.tokenByte = byte
    }
    
    public func handleDefault(using closure: @escaping RequestHandler) {
        self.defaultHandler = closure
    }
    
    public func handle(_ request: Request, for client: Client) {
        guard let node = findNode(at: request.path.components, for: request) else {
            self.defaultHandler(request, client)
            return
        }
        
        guard let handler = node.leafs[request.method] else {
            self.defaultHandler(request, client)
            return
        }
        
        handler(request, client)
    }
    
    fileprivate func findNode(at path: [UnsafeBufferPointer<UInt8>], for request: Request) -> TrieRouterNode? {
        var node = self.node
        var currentIndex = 0
        
        recursiveSearch: for component in path {
            defer { currentIndex = currentIndex &+ 1 }
            
            guard component.count > 0 else {
                continue
            }
            
            for subNode in node.subNodes {
                let isToken = subNode.component.bytes.first == tokenByte && subNode.component.bytes.count > 1
                
                // colon is acceptable for tokenized strings
                if subNode.component == component || isToken {
                    if isToken,
                        let token = String(bytes: subNode.component.bytes[1..<subNode.component.bytes.endIndex], encoding: .utf8),
                        currentIndex < path.count,
                        let value = String(bytes: path[currentIndex], encoding: .utf8) {
                        request.path.tokens[token] = value
                    }
                    
                    node = subNode
                    continue recursiveSearch
                }
            }
            
            break recursiveSearch
        }
        
        return node
    }
    
    public func register(at path: [String], method: Method, handler: @escaping RequestHandler) {
        self.register(at: path.flatMap { UTF8String(bytes: [UInt8]($0.utf8)) }, method: method, handler: handler)
    }
    
    internal func register(at path: [UTF8String], method: Method, handler: @escaping RequestHandler) {
        var node = self.node
        var path = path.filter { $0.bytes.count > 0 }
        
        var done = 0
        
        recursiveSearch: for component in path {
            guard component.bytes.count > 0 else {
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

public protocol StringInitializable {
    init?(from string: String) throws
}

extension String : StringInitializable {
    public init?(from string: String) throws {
        self = string
    }
}

public struct InvalidExtractionError : Error {}

extension Request {
    public func extract<SI: StringInitializable>(_ initializable: SI.Type, from token: String) throws -> SI? {
        guard let value = self.path.tokens[token] else {
            throw InvalidExtractionError()
        }
    
        return try SI(from: value)
    }
}

public final class TrieRouterNode {
    internal var leafs = [Method : RequestHandler]()
    internal var component: UTF8String
    internal var subNodes = [TrieRouterNode]()
    internal var components: [UTF8String]
    
    internal init(at path: [UTF8String], component: UTF8String) {
        self.components = path
        self.component = component
    }
}
