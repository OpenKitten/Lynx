import CryptoKitten

public final class WebSocket {
    let remote: Client
    let id: Int
    
    internal init?(from request: Request, to client: Client, identifiedBy id: Int) throws {
        guard
            request.method == .get,
            let key = request.headers["Sec-WebSocket-Key"],
            let version = Int(request.headers["Sec-WebSocket-Version"]),
            request.headers["Upgrade"] == "websocket",
            request.headers["Connection"] == "Upgrade" else {
                return nil
        }
        
        let headers: Headers
        
        let hash = HeaderValue(bytes: [UInt8](Base64.encode(SHA1.hash((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").bytes)).utf8))
        
        if version > 13 {
            headers = [
                "Upgrade": "websocket",
                "Connection": "Upgrade",
                "Sec-WebSocket-Version": "13",
                "Sec-WebSocket-Key": hash
            ]
        } else {
            headers = [
                "Upgrade": "websocket",
                "Connection": "Upgrade",
                "Sec-WebSocket-Accept": hash
            ]
        }
        
        self.remote = client
        self.id = id
        
        client.onRead(self.receive)
        
        try Response(status: .upgrade, headers: headers).send(to: client)
    }
    
    func receive(data: UnsafePointer<UInt8>, length: Int) {
        do {
            let message = try Frame(from: data, length: length)
            
            if message.opCode == .ping {
                // TODO: send pong
            } else if message.opCode == .close {
                // TODO: Close
            }
            
            print(String(bytes: message.data, encoding: .utf8)!)
        } catch {
            remote.close()
        }
    }
}
