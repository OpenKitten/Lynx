// Creates a response from a body
extension Body : ResponseRepresentable {
    public func makeResponse() throws -> Response {
        return Response(status: .ok, body: self)
    }
}

// Creates a response from a String
extension String : ResponseRepresentable {
    public func makeResponse() throws -> Response {
        return Response(status: .ok, body: self)
    }
}

// Returns the response
extension Response : ResponseRepresentable {
    public func makeResponse() throws -> Response {
        return self
    }
}
