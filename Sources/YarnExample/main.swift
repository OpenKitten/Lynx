import Darwin
import Yarn

while true {
    do {
        let router = VaporStyleRouter()
        
        let server = try HTTPServer(port: 1234, handler: router.handle)
        try server.start()
    } catch {
        // unable to bind to socket? retry
        sleep(1)
    }
}

