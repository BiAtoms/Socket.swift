//
//  OS.swift
//  Socket.swift
//
//  Created by Orkhan Alikhanov on 7/10/17.
//  Copyright © 2017 BiAtoms. All rights reserved.
//

import Foundation //Darwin or Glibc


/// Shortens `Darwin.XX` and `Glibc.XX` into `OS.XX`
///
/// Since `Socket` defines instance methods having the same name (not signature)
/// with global functions (eg. close, write etc.) swift compiler generates error:
/// Use of 'XX' refers to instance method 'XX()' rather than global function 'XX'
/// in module 'Darwin(Glibc in linux)'. So, instead of calling `Darwin.XX` or `Glibc.XX`
/// now we can call `OS.XX`
///
/// - Note: Module names cannot be aliased. `typealias OS = Darwin` won't compile.
/// That's why we have to go with `struct`
internal struct OS {
    #if os(Linux)
    static let close = Glibc.close
    static let bind = Glibc.bind
    static let connect = Glibc.connect
    static let listen = Glibc.listen
    static let accept = Glibc.accept
    static let write = Glibc.write
    #else
    static let close = Darwin.close
    static let bind = Darwin.bind
    static let connect = Darwin.connect
    static let listen = Darwin.listen
    static let accept = Darwin.accept
    static let write = Darwin.write
    #endif
}
