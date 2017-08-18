import Foundation
fileprivate let cookieStart: HeaderKey = "Cookie: "
fileprivate let setCookieStart: HeaderKey = "Set-Cookie: "

public func +=(lhs: inout Cookies, rhs: Cookies) {
    lhs.append(contentsOf: rhs)
}

public struct Cookies : Sequence, ExpressibleByDictionaryLiteral {
    public init() {}
    
    private var cookies = [String : Cookie]()
    
    public mutating func append(contentsOf cookies: Cookies) {
        for (name, cookie) in cookies.cookies {
            self.cookies[name] = cookie
        }
    }
    
    public subscript(key: String) -> Cookie? {
        get {
            return cookies[key]
        }
        set {
            cookies[key] = newValue
        }
    }

    public var count: Int {
        return cookies.count
    }
    
    public init(dictionaryLiteral elements: (String, Cookie)...) {
        for (key, cookie) in elements {
            self[key] = cookie
        }
    }
    
    public mutating func append(_ cookie: Cookie, forKey key: String) {
        self[key] = cookie
    }
    
    mutating func append(fromHeader header: ArraySlice<UInt8>) {
        func parseCookie(from string: String) {
            var cookies = [(String, Cookie)]()
            
            for cookie in string.components(separatedBy: "; ") {
                let cookie = cookie.trimmingCharacters(in: .whitespaces)
                let keyValue = cookie.split(separator: "=")
                
                guard keyValue.count == 2 else {
                    continue
                }
                
                var name = String(keyValue[0])
                
                if name.starts(with: "Cookie: ") {
                    name.removeFirst("Cookie: ".count)
                }
                
                cookies.append((name, Cookie(valueOf: String(keyValue[1]))))
            }
            
            for (key, cookie) in cookies {
                self[key] = cookie
            }
        }
        
        if header.starts(with: cookieStart.bytes), header.count > cookieStart.bytes.count {
            guard let cookies = String(bytes: header[(header.startIndex + cookieStart.bytes.count) ..< header.endIndex], encoding: .utf8) else {
                return
            }
            
            parseCookie(from: cookies)
        } else if header.starts(with: setCookieStart.bytes), header.count > cookieStart.bytes.count {
            guard let cookies = String(bytes: header[(header.startIndex + cookieStart.bytes.count) ..< header.endIndex], encoding: .utf8) else {
                return
            }
            
            parseCookie(from: cookies)
        }
    }
    
    public func makeIterator() -> DictionaryIterator<String, Cookie> {
        return cookies.makeIterator()
    }
}

extension Request {
    public var cookies: Cookies {
        get {
            return headers.cookies
        }
        set {
            headers.setCookies(newValue, for: .request)
        }
    }
}

extension Response {
    public var cookies: Cookies {
        get {
            return headers.cookies
        }
        set {
            headers.setCookies(newValue, for: .response)
        }
    }
}

extension String {
    public init?(_ cookie: Cookie?) {
        guard let me = cookie?.value else {
            return nil
        }
        
        self = me
    }
}

public struct Cookie : ExpressibleByStringLiteral {
    public var value: String

    //GMT Time
    public var expires: Date?
    public var maxAge: TimeInterval?

    // If browsers use session restoring, the session cookie may be considered permanent
    public var sessionCookie : Bool {
        return expires == nil && maxAge == nil
    }

    public init(valueOf value: String) {
        self.value = value
    }
    
    public init(stringLiteral value: String) {
        self.value = value
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.value = value
    }
    
    public init(extendedGrahemeLiteral value: String) {
        self.value = value
    }

    public static func ==(lhs: Cookie, rhs: String) -> Bool {
        return lhs.value == rhs
    }

    public static func ==(lhs: String, rhs: Cookie) -> Bool {
        return rhs.value == lhs
    }
    
    internal func serialized() -> [UInt8] {
        return [UInt8](value.utf8)
    }
}
