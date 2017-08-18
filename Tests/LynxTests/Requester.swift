//Taken from Puma
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

@_exported import Lynx

fileprivate let http1_1 = [UInt8]("HTTP/1.1\r\n".utf8)
fileprivate let eol = [UInt8]("\r\n".utf8)

extension TCPClient {
    public func send(_ request: Request) throws {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 65_536)
        defer { pointer.deallocate(capacity: 65_536) }

        let signature = [UInt8](request.method.string.utf8) + [0x20] + request.path.bytes + [0x20] + http1_1

        var offset = signature.count
        memcpy(pointer, signature, offset)

        guard request.headers.buffer.count &+ signature.count &+ 2 < Int(UInt16.max) else {
            fatalError()
        }

        memcpy(pointer.advanced(by: signature.count), request.headers.buffer.baseAddress, request.headers.buffer.count)
        offset += request.headers.buffer.count

        if request.headers.buffer.count == 0 {
            memcpy(pointer.advanced(by: signature.count), eol, eol.count)
            offset += 2
        }

        if let body = request.body, body.buffer.count - offset < 65_534, let baseAddress = body.buffer.baseAddress {
            memcpy(pointer.advanced(by: offset), baseAddress, body.buffer.count)
            offset = offset &+ body.buffer.count
            pointer[offset] = 0x0d
            pointer[offset &+ 1] = 0x0a
            offset = offset &+ 2

            try self.send(data: pointer, withLengthOf: offset)
        } else {
            if offset < 65_534 {
                pointer[offset] = 0x0d
                pointer[offset &+ 1] = 0x0a
                offset = offset &+ 2
                try self.send(data: pointer, withLengthOf: offset)
            } else {
                try self.send(data: pointer, withLengthOf: offset)
                try self.send(data: eol)
            }

            if let body = request.body, let baseAddress = body.buffer.baseAddress {
                try self.send(data: baseAddress, withLengthOf: body.buffer.count)
            }
        }
    }
}

