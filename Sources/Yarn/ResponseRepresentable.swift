extension Body : ResponseRepresentable {
    public func makeResponse() throws -> Response {
        return Response(status: .ok, body: self)
    }
}

extension String : ResponseRepresentable {
    public func makeResponse() throws -> Response {
        return Response(status: .ok, body: self)
    }
}

extension Response : ResponseRepresentable {
    public func makeResponse() throws -> Response {
        return self
    }
}
