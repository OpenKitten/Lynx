#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Lynx

while true {
    do {
        let router = VaporStyleRouter()
        
        let sr = try "kaas".makeBody().makeResponse()
        router.get() { _ in
            return sr
        }
        
        router.get("login") { _ in
            let body = """
            <form action="login" method="POST">
                <input type="text" name="username" /><br />
                <input type="password" name="password" /><br />
                <button>Kaas</button>
            </form>
            """
            
            return Response(status: .ok, headers: [
                "Content-Type": "text/html"
                ], body: body)
        }
        
        router.websocket("ws") { socket in
            socket.onText { text in
                print(text)
                try socket.send(text)
            }
        }
        
        router.get("login2") { _ in
            let body = """
            <form action="login2" method="POST" enctype="multipart/form-data">
                <input type="text" name="username" /><br />
                <input type="password" name="password" /><br />
                <input type="file" name="file" /><br /><br />
                <textarea name="extra"></textarea><br />
                <button>Kaas</button>
            </form>
            """
            
            return Response(status: .ok, headers: [
                "Content-Type": "text/html"
            ], body: body)
        }
        
        router.post("login") { req in
            print(req.query)
            return ""
        }
        
        router.post("login2") { req in
            print(req.multipart)
            print(req.multipart?["file"]?.string)
            print(req.multipart?["extra"]?.string)
            return ""
        }
        
        router.get("harrie", "de", "bobs") { request in
            return request.url.query["super"] ?? "banana"
        }
        
        router.get("harrie", ":kaas", "bobs") { request in
            return (try request.extract(String.self, from: "kaas") ?? "noes")
        }
        
        router.register(at: ["path", "to", "route"], method: .get) { request, client in
            let response = Response(status: .ok, headers: [
                "Content-Type": "text/html"
            ], body: "<h1>AWESOME</h1>")
            
            do {
                try response.send(to: client)
            } catch {
                client.close()
            }
        }
        
        let server = try HTTPServer(port: 1234, handler: router.handle)
        try server.start()
    } catch {
        // unable to bind to socket? retry
        sleep(1)
    }
}
