//
//  ThreadHelper.swift
//  Lynx
//
//  Created by James William Graham on 8/15/17.
//

import Foundation

func dispatch_async_main_rethrows(_ block: @escaping () throws -> Void ) rethrows {
    func logic(_  block: @escaping () throws -> Void, thrower: @escaping ((Error) throws -> ())) rethrows {
        var err: Error? = nil
        DispatchQueue.main.async {
            do {
                try block()
            }
            catch let error {
                err = error
            }
        }
        if let err = err {
            try thrower(err)
        }
    }
    try logic(block) { err in
        throw err
    }
}
