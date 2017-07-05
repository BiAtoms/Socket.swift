//
//  Socket.swift
//  Socket.swift
//
//  Created by Orkhan Alikhanov on 7/3/17.
//  Copyright © 2017 BiAtoms. All rights reserved.
//

import Foundation

public typealias FileDescriptor = Int32
public typealias Byte = UInt8
public typealias Port = in_port_t
public typealias SocketAddress = sockaddr

@discardableResult
public func ing(block:(()->Int32)) throws -> Int32 {
    let value = block()
    if value == -1 {
        throw Errno.description
    }
    return value
}

open class Socket {
    open let fileDescriptor: FileDescriptor
    
    required public init(with fileDescriptor: FileDescriptor) {
        self.fileDescriptor = fileDescriptor
    }
    
    public struct Family: RawRepresentable {
        public let rawValue: Int32
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        public static let IPv4 = Family(rawValue: AF_INET)
        public static let IPv6 = Family(rawValue: AF_INET6)
    }
    
    required public init(_ family: Family) throws {
        self.fileDescriptor = try ing{ socket(family.rawValue, SOCK_STREAM, 0) }
    }
    
    open func close() {
        //Dont close after an error. see http://man7.org/linux/man-pages/man2/close.2.html#NOTES
        //TODO: Handle error on close
        _ = Darwin.close(fileDescriptor)
    }
    
    open func read() throws -> Byte {
        var byte: Byte = 0
        let recived = Darwin.recv(fileDescriptor, &byte, 1, 0)
        if recived <= 0 {//-1 is an error, 0 depends. see http://man7.org/linux/man-pages/man2/recv.2.html#RETURN_VALUE
            throw Errno.description
        }
        return byte
    }
    
    open func write(_ buffer: UnsafeRawPointer, length: Int) throws {
        var totalWritten = 0
        while totalWritten < length {
            let written = Darwin.write(fileDescriptor, buffer + totalWritten, length - totalWritten)
            if written <= 0 { //see http://man7.org/linux/man-pages/man2/write.2.html#RETURN_VALUE
                throw Errno.description
            }
            totalWritten += written
        }
    }
    
    public struct Option: RawRepresentable {
        public let rawValue: Int32
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        public static let reuseAddress = Option(rawValue: SO_REUSEADDR)
    }
    
    open func set(option: Option, _ state: Bool) throws {
        var state = state
        try ing { setsockopt(fileDescriptor, SOL_SOCKET, option.rawValue, &state, socklen_t(MemoryLayout<Int32>.size)) }
    }
    
    open func bind(port: Port, address: String? = nil) throws {
        var addr = SocketAddress(port: port, address: address)
        try ing {  Darwin.bind(fileDescriptor, &addr, socklen_t(MemoryLayout<SocketAddress>.size)) }
    }
    
    open func connect(port: Port, address: String? = nil) throws {
        var addr = SocketAddress(port: port, address: address)
        try ing {  Darwin.connect(fileDescriptor, &addr, socklen_t(MemoryLayout<SocketAddress>.size)) }
    }
    
    open func listen(backlog: Int32 = SOMAXCONN) throws {
        try ing { Darwin.listen(fileDescriptor, backlog) }
    }
    
    open func accept() throws -> Self {
        var addrlen: socklen_t = 0, addr = sockaddr()
        let client = try ing { Darwin.accept(fileDescriptor, &addr, &addrlen) }
        return type(of: self).init(with: client)
    }
}
extension String: Error {}
extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

open class Errno {
    open class var description: String {
        return String(cString: UnsafePointer(strerror(errno)))
    }
}

extension Socket {
    open class func tcpListening(port: Port, address: String? = nil, maxPendingConnection: Int32 = SOMAXCONN) throws -> Self {
        
        let socket = try self.init(.IPv4)
        try socket.set(option: .reuseAddress, true)
        try socket.bind(port: port, address: address)
        try socket.listen(backlog: maxPendingConnection)
        
        return socket
    }
}


extension Socket {
    open func write(_ bytes: [Byte]) throws {
        try self.write(bytes, length: bytes.count)
    }
    
    open func readLine() throws -> String {
        var line: String = "" //yep it is StringBuilder
        let CR = Byte(13), LF = Byte(10)
        while let byte = try? read(), byte != LF {
            if byte != CR {
                line.append(Character(UnicodeScalar(byte)))
            }
        }
        if line.isEmpty {
            throw "Empty line"
        }
        
        return line
    }
}

extension SocketAddress {
    public init(port: Port, address: String? = nil) {
        var addr = sockaddr_in(
            sin_len: UInt8(MemoryLayout<sockaddr_in>.stride),
            sin_family: UInt8(AF_INET),
            sin_port: port.bigEndian,
            sin_addr: in_addr(s_addr: in_addr_t(0)),
            sin_zero:(0, 0, 0, 0, 0, 0, 0, 0))
        if let address = address, address.withCString({ cstring in inet_pton(AF_INET, cstring, &addr.sin_addr) }) == 1 {
            // print("\(address) is converted to \(addr.sin_addr).")
        } else {
            // print("\(address) is not converted.")
        }
        
        self = withUnsafePointer(to: &addr) {
            UnsafePointer<SocketAddress>(OpaquePointer($0)).pointee
        }
    }
}
