public final class VaporStyleRouter : TrieRouter {
    public override init() {}
    
    public func get(_ path: String..., handler: @escaping ((Request) throws -> (ResponseRepresentable))) {
        self.register(at: path, method: .get) { request, client in
            do {
                let response = try handler(request)
                
                try response.makeResponse().send(to: client)
            } catch {
                print(error)
                client.close()
            }
        }
    }
}
