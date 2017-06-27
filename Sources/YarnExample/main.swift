import Darwin
import Yarn

while true {
    do {
        let router = TrieRouter()
        
        let server = try HTTPServer(port: 1234, handler: router.handler)
        try server.start()
    } catch {}
    sleep(1)
}
