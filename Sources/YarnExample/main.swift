import Darwin
import Yarn

while true {
    do {
        let server = try HTTPServer(port: 1234)
        try server.start()
    } catch {}
    sleep(1)
}
