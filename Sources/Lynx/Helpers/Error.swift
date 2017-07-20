/// All possible TCP errors
public enum TCPError : Error {
    /// Failed to bind the socket
    case bindFailed
    
    /// Could not send data to the client
    case sendFailure
    
    /// Cannot read data, the socket is likely closed
    case cannotRead
    
    /// The TCP Client could not connect to the remote
    case unableToConnect
}

