extension Request {
    public var query: Query {
        if let body = self.body {
            return Query(buffer: UnsafeBufferPointer(start: body.baseAddress, count: body.count))
        }
        
        return Query()
    }
}
