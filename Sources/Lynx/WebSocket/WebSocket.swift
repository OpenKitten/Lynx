import Foundation
import CryptoKitten

public final class WebSocket {
    let remote: Client
    let onClose: (()->())
    
    internal init?(from request: Request, to client: Client, onClose: @escaping (()->())) throws {
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
        
        self.onClose = onClose
        self.remote = client
        
        client.onRead(self.receive)
        
        try Response(status: .upgrade, headers: headers).send(to: client)
    }
    
    public func close() {
        remote.close()
        
        onClose()
    }
    
    fileprivate let message = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(UInt16.max))
    
    // MARK - Sending
    
    @discardableResult
    fileprivate func sendFrame(opcode: Frame.OpCode, pointer: UnsafePointer<UInt8>, length: Int, maskingWith mask: (UInt8,UInt8,UInt8,UInt8)? = nil) throws -> Int {
        let drained: Int
        let extra: Int
        
        message[2] = mask?.0 ?? 0
        message[3] = mask?.1 ?? 0
        message[4] = mask?.2 ?? 0
        message[5] = mask?.3 ?? 0
        
        let maskBit: UInt8 = mask == nil ? 0b00000000 : 0b01000000
        
        if length < 126 {
            // header + mask
            extra = (mask == nil) ? 2 : 6
            
            message[0] = 0b10000000 | opcode.rawValue | maskBit
            message[1] = numericCast(length)
            
            memcpy(message.advanced(by: extra), pointer, length)
            drained = length
        } else if opcode == .text && length > 65_532 {
            // header + UInt64 + mask
            extra = (mask == nil) ? 10 : 14
            
            message[0] = 0b10000000 | opcode.rawValue | maskBit
            message[1] = 0b01111111
            var payloadLength = UInt64(length)
            
            memcpy(message.advanced(by: 2), &payloadLength, 8)
            
            memcpy(message.advanced(by: extra), pointer, length)
            
            return length
        } else {
            // header + UInt16 + mask
            extra = (mask == nil) ? 4 : 6
            
            let final: UInt8 = (length <= Int(UInt16.max) && opcode != .text) ? 0b10000000 : 0b00000000
            
            message[0] = final | opcode.rawValue | maskBit
            message[1] = 0b01111110
            
            drained = min(length, 65_532)
            var payloadLength: UInt16 = numericCast(drained)
            memcpy(message.advanced(by: 2), &payloadLength, 2)
            
            memcpy(message.advanced(by: extra), pointer, drained)
        }
        
        try remote.send(data: message, withLengthOf: drained &+ extra)
        return drained
    }
    
    public func send(dataAt pointer: UnsafePointer<UInt8>, length: Int) throws {
        var pointer = pointer
        let message = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(UInt16.max))
        defer { message.deallocate(capacity: Int(UInt16.max)) }
        
        var offset = 0
        
        while offset &+ Int(UInt16.max) <= length {
            let sent = try sendFrame(opcode: offset > 0 ? .continuation : .binary, pointer: pointer, length: length &- offset)
            offset = offset &+ sent
            pointer = pointer.advanced(by: sent)
        }
    }
    
    public func send(_ string: String) throws {
        let data = [UInt8](string.utf8)
        let pointer = UnsafePointer(data)
        
        try self.sendFrame(opcode: .text, pointer: pointer, length: data.count)
    }
    
    public func send(_ bytes: [UInt8]) throws {
        try self.send(dataAt: bytes, length: bytes.count)
    }
    
    public func send(_ data: Data) throws {
        try data.withUnsafeBytes {
            try self.send(dataAt: $0, length: data.count)
        }
    }
    
    // MARK - Receiving
    
    public typealias TextHandler = ((String) throws -> ())
    public typealias BinaryHandler = ((UnsafePointer<UInt8>, Int) throws -> ())
    
    var textHandler: TextHandler?
    var binaryHandler: BinaryHandler?
    
    public func onText(_ handler: @escaping TextHandler) {
        self.textHandler = handler
    }
    
    public func onBinary(_ handler: @escaping BinaryHandler) {
        self.binaryHandler = handler
    }
    
    public func onBytes(_ handler: @escaping (([UInt8]) throws -> ())) {
        self.binaryHandler = { pointer, length in
            let buffer = UnsafeBufferPointer(start: pointer, count: length)
            
            try handler(Array(buffer))
        }
    }
    
    public func onData(_ handler: @escaping ((Data) throws -> ())) {
        self.binaryHandler = { pointer, length in
            let buffer = UnsafeBufferPointer(start: pointer, count: length)
            
            try handler(Data(buffer))
        }
    }
    
    func receive(data: UnsafePointer<UInt8>, length: Int) {
        do {
            let message = try Frame(from: data, length: length)
            
            switch message.opCode {
            case .text:
                if let string = String(bytes: message.data, encoding: .utf8) {
                    try textHandler?(string)
                }
            case .binary:
                if let pointer = message.data.baseAddress {
                    try self.binaryHandler?(pointer, message.data.count)
                }
            case .ping:
            // TODO: send pong
                print("pong")
            case .close:
                close()
            default:
                break
            }
        } catch {
            remote.close()
        }
    }
    
    deinit {
        self.message.deallocate(capacity: Int(UInt16.max))
    }
}
