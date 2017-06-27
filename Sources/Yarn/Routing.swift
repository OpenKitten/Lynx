public class TrieRouter {//} : ExpressibleByDictionaryLiteral {
    public var handler: RequestHandler = NotFound(body: "henk").handle
    
//    public subscript(tokenizedPath: String) -> TrieRouter {
//        get {
//
//        }
//        set {
//
//        }
//    }
    public init() {}
}
