extension String : ResponseRepresentable {
    public func makeResponse() throws -> Response {
        return Response(status: .ok, body: self)
    }
}
