import Darwin
import Yarn

while true {
    do {
        let router = VaporStyleRouter()
        
        router.get() { _ in
            return "kaas"
        }
        
        router.get("harrie", "de", "bobs") { _ in
            return "bobs"
        }
        
        router.get("harrie", ":kaas", "bobs") { request in
            return (try request.extract(String.self, from: "kaas") ?? "noes")
        }
        
        let server = try HTTPServer(port: 1234, handler: router.handle)
        try server.start()
    } catch {
        // unable to bind to socket? retry
        sleep(1)
    }
}
