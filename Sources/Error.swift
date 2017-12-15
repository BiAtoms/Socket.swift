//
//  SocketError.swift
//  Socket.swift
//
//  Created by Orkhan Alikhanov on 7/6/17.
//  Copyright © 2017 BiAtoms. All rights reserved.
//

import Foundation

@discardableResult
public func ing<T: SignedInteger>(_ block: (() -> T)) throws -> T {
    let value = block()
    if value == -1 {
        throw Socket.Error(errno: errno)
    }
    return value
}

extension Socket {
    public struct Error: Swift.Error, Equatable, CustomStringConvertible {
        public let errno: Int32
        public init(errno: Int32) { self.errno = errno }
        
        public static func == (lhs: Error, rhs: Error) -> Bool {
            return lhs.errno == rhs.errno
        }
        
        public var description: String {
            return "SocketError \(self.errno): \(String(cString: UnsafePointer(strerror(self.errno))))."
        }
    }
}
