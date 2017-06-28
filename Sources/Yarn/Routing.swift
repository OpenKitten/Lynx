open class TrieRouter {
    private var defaultHandler: RequestHandler = NotFound(body: "henk").handle
    
    public func handleDefault(using closure: @escaping RequestHandler) {
        self.defaultHandler = closure
    }
    
    public func handle(_ request: Request, for client: Client) {
        guard let node = findNode(at: request.path, method: request.method) else {
            self.defaultHandler(request, client)
            return
        }
        
        node.handler(request, client)
    }
    
    fileprivate func findNode(at path: Path, method: Method) -> TrieRouterNode? {
        var currentNode: TrieRouterNode?
        
        unwinding: for component in path.components {
            guard let currentNodeCopy = currentNode else {
                for node in self.nodes {
                    if node.component == component {
                        continue unwinding
                    }
                }
                
                return nil
            }
            
            for node in currentNodeCopy.subNodes {
                if node.component == component {
                    currentNode = node
                    continue unwinding
                }
            }
            
            return nil
        }
        
        guard currentNode?.method == method else {
            return nil
        }
        
        return currentNode
    }
    
    public func register(at path: [String], method: Method, handler: @escaping RequestHandler) {
        guard let last = path.last else {
            return
        }
        
        var previousNode: TrieRouterNode?
        var currentNode: TrieRouterNode?
        
        var components = path
        
        unwinding: while components.count > 0 {
            let component = components.removeFirst()
            
            guard let currentNodeCopy = currentNode else {
                for node in self.nodes {
                    if node.component == component {
                        continue unwinding
                    }
                }
                
                break unwinding
            }
            
            previousNode = currentNode
            
            for node in currentNodeCopy.subNodes {
                if node.component == component {
                    currentNode = node
                    continue unwinding
                }
            }
            
            break unwinding
        }
        
        let newNode = TrieRouterNode(at: last, method: method, handler: handler)
        
        if components.count == 0 {
            if let currentNode = currentNode {
                newNode.subNodes = currentNode.subNodes
                
                if let previousNode = previousNode {
                    if let index = nodes.index(where: { $0.component == last }) {
                        previousNode.subNodes[index] = newNode
                    } else {
                        previousNode.subNodes.append(newNode)
                    }
                } else if let index = nodes.index(where: { $0.component == last }) {
                    nodes[index] = newNode
                }
            } else {
                self.nodes.append(newNode)
            }
        } else {
            var newComponent: String
            var newExtraNode: TrieRouterNode
            var first = true
            
            repeat {
                newComponent = components.removeFirst()
                newExtraNode = TrieRouterNode(at: newComponent, method: nil, handler: self.defaultHandler)
                
                if first {
                    self.nodes.append(newExtraNode)
                    first = false
                }
            } while components.count > 0
            
            newExtraNode.subNodes.append(newNode)
        }
    }
    
    internal var nodes = [TrieRouterNode]()
}

public final class TrieRouterNode {
    var handler: RequestHandler
    internal var method: Method?
    internal var component: UTF8String
    
    internal var subNodes = [TrieRouterNode]()
    
    public init(at component: String, method: Method, handler: @escaping RequestHandler) {
        self.handler = handler
        self.method = method
        self.component = UTF8String(bytes: [UInt8](component.utf8))
    }
    
    internal init(at component: String, method: Method?, handler: @escaping RequestHandler) {
        self.handler = handler
        self.method = method
        self.component = UTF8String(bytes: [UInt8](component.utf8))
    }
    
    internal init(at component: UTF8String, method: Method?, handler: @escaping RequestHandler) {
        self.handler = handler
        self.method = method
        self.component = component
    }
}
