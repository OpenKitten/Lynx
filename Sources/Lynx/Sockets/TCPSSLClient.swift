import Foundation
import Dispatch

#if (os(macOS) || os(iOS))
    import Security
    import Darwin
#if OPENSSL
    import KittenCTLS
#endif
#else
    import KittenCTLS
    import Glibc
#endif

public final class TCPSSLClient : TCPClient {
    #if (os(macOS) || os(iOS)) && !OPENSSL
        private let sslClient: SSLContext
    #else
        private let sslClient: UnsafeMutablePointer<SSL>
        private let sslMethod: UnsafePointer<SSL_METHOD>
        private let sslContext: UnsafeMutablePointer<SSL_CTX>
    #endif
    
    #if (os(macOS) || os(iOS)) && !OPENSSL
        public init(hostname: String, port: UInt16, onRead: @escaping ReadCallback) throws {
            guard let context = SSLCreateContext(nil, .clientSide, .streamType) else {
                throw TCPError.cannotCreateContext
            }
            
            self.sslClient = context
            
            try super.init(hostname: hostname, port: port, onRead: onRead, false)
            
            var val = 1
            setsockopt(self.descriptor, SOL_SOCKET, SO_NOSIGPIPE, &val, socklen_t(MemoryLayout<Int>.stride))
            
            SSLSetIOFuncs(self.sslClient, { context, data, length in
                let context = context.assumingMemoryBound(to: Int32.self).pointee
                let lengthRequested = length.pointee
                
                var readCount = Darwin.recv(context, data, lengthRequested, 0)
                
                defer { length.initialize(to: readCount) }
                if readCount == 0 {
                    return OSStatus(errSSLClosedGraceful)
                } else if readCount < 0 {
                    readCount = 0
                    
                    switch errno {
                    case ENOENT:
                        return OSStatus(errSSLClosedGraceful)
                    case EAGAIN:
                        return OSStatus(errSSLWouldBlock)
                    case ECONNRESET:
                        return OSStatus(errSSLClosedAbort)
                    default:
                        return OSStatus(errSecIO)
                    }
                }
                
                guard lengthRequested <= readCount else {
                    return OSStatus(errSSLWouldBlock)
                }
                
                return noErr
            }, { context, data, length in
                let context = context.bindMemory(to: Int32.self, capacity: 1).pointee
                let toWrite = length.pointee
                
                var writeCount = Darwin.send(context, data, toWrite, 0)
                
                defer { length.initialize(to: writeCount) }
                if writeCount == 0 {
                    return OSStatus(errSSLClosedGraceful)
                } else if writeCount < 0 {
                    writeCount = 0
                    
                    guard errno == EAGAIN else {
                        return OSStatus(errSecIO)
                    }
                        
                    return OSStatus(errSSLWouldBlock)
                }
                
                guard toWrite <= writeCount else {
                    return Int32(errSSLWouldBlock)
                }
                
                return noErr
            })
            
            guard SSLSetConnection(context, &descriptor) == 0 else {
                throw TCPError.unableToConnect
            }
            
            var hostname = [Int8](hostname.utf8.map { Int8($0) })
            guard SSLSetPeerDomainName(context, &hostname, hostname.count) == 0 else {
                throw TCPError.unableToConnect
            }
            
            var result: Int32
            
            repeat {
                result = SSLHandshake(context)
            } while result == errSSLWouldBlock
            
            guard result == errSecSuccess || result == errSSLPeerAuthCompleted else {
                throw TCPError.unableToConnect
            }
            
            self.readSource.setEventHandler(qos: .userInteractive) {
                var read = 0
                SSLRead(self.sslClient, self.incomingBuffer.pointer, Int(UInt16.max), &read)
                
                guard read != 0 else {
                    self.readSource.cancel()
                    return
                }
                
                onRead(self.incomingBuffer.pointer, read)
            }
            
            self.readSource.setCancelHandler {
                SSLClose(self.sslClient)
                Darwin.close(self.descriptor)
            }
            
            self.readSource.resume()
        }
    #else
    public override init(hostname: String, port: UInt16, onRead: @escaping ReadCallback) throws {
        try super.init(hostname: hostname, port: port, onRead: onRead)
    
        let verifyCertificate = !(options["invalidCertificateAllowed"] as? Bool ?? false)

        let method = SSLv23_client_method()

        guard let ctx = SSL_CTX_new(method) else {
            throw Error.cannotCreateContext
        }

        self.sslContext = ctx
        self.sslMethod = method

        SSL_CTX_ctrl(ctx, SSL_CTRL_MODE, SSL_MODE_AUTO_RETRY, nil)
        SSL_CTX_ctrl(ctx, SSL_CTRL_OPTIONS, SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3 | SSL_OP_NO_COMPRESSION, nil)

        if !verifyCertificate {
            SSL_CTX_set_verify(ctx, SSL_VERIFY_NONE, nil)
        }

        guard  SSL_CTX_set_cipher_list(ctx, "DEFAULT") == 1 else {
            throw Error.cannotCreateContext
        }

        if let CAFile = options["CAFile"] as? String {
            SSL_CTX_load_verify_locations(ctx, CAFile, nil)
        }

        guard let ssl = SSL_new(ctx) else {
            throw Error.cannotConnect
        }

        self.sslClient = ssl

        guard SSL_set_fd(ssl, plainClient) == 1 else {
            throw Error.cannotConnect
        }

        var hostname = [UInt8](hostname.utf8)
        SSL_ctrl(ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME, Int(TLSEXT_NAMETYPE_host_name), &hostname)

        guard SSL_connect(ssl) == 1, SSL_do_handshake(ssl) == 1 else {
            throw Error.cannotConnect
        }
    }
    #endif
    
    /// Sends new data to the client
    public override func send(data pointer: UnsafePointer<UInt8>, withLengthOf length: Int) throws {
        #if (os(macOS) || os(iOS)) && !OPENSSL
            var i = 0
            SSLWrite(self.sslClient, pointer, length, &i)
            
            guard i == length else {
                throw TCPError.sendFailure
            }
        #else
            var total = 0
            
            while total < length {
                let sent = SSL_write(self.sslClient!, pointer.advanced(by: total), Int32(length))
                
                guard sent > 0 else {
                    throw Error.cannotSendData
                }
                
                total = total &+ numericCast(sent)
            }
        #endif
    }
}
