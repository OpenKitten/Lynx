import Darwin

public class NotFound {
    private var response: Response
    
    public init(headers: Headers = Headers()) {
        self.response = Response(status: .notFound, headers: headers)
    }
    
    public init(headers: Headers = Headers(), body: BodyRepresentable) {
        self.response = Response(status: .notFound, headers: headers, body: body)
    }
    
    public func handle(_ request: Request, for client: Client) {
        do {
            try response.send(to: client)
        } catch {
            client.close()
        }
    }
}

