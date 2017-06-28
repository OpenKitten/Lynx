public final class VaporStyleRouter : TrieRouter {
    public init() {
        super.init(startingTokensWith: 0x3a)
    }
    
    fileprivate func register(_ path: [String], method: Method, handler: @escaping ((Request) throws -> (ResponseRepresentable))) {
        self.register(at: path, method: method) { request, client in
            do {
                let response = try handler(request)
                
                try response.makeResponse().send(to: client)
            } catch {
                print(error)
                client.close()
            }
        }
    }
    
    public func get(_ path: String..., handler: @escaping ((Request) throws -> (ResponseRepresentable))) {
        self.register(path, method: .get, handler: handler)
    }
    
    public func put(_ path: String..., handler: @escaping ((Request) throws -> (ResponseRepresentable))) {
       self.register(path, method: .get, handler: handler)
    }
    
    public func post(_ path: String..., handler: @escaping ((Request) throws -> (ResponseRepresentable))) {
        self.register(path, method: .post, handler: handler)
    }
    
    public func delete(_ path: String..., handler: @escaping ((Request) throws -> (ResponseRepresentable))) {
        self.register(path, method: .delete, handler: handler)
    }
}
