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
public typealias TimeValue = timeval

open class Socket {
    public let fileDescriptor: FileDescriptor
    open var tls: TLS?
    
    required public init(with fileDescriptor: FileDescriptor) {
        self.fileDescriptor = fileDescriptor
    }
    
    required public init(_ family: Family, type: Type = .stream, protocol: Protocol = .tcp) throws {
        self.fileDescriptor = try ing { socket(family.rawValue, type.rawValue, `protocol`.rawValue) }
    }
    
    open func close() {
        //Dont close after an error. see http://man7.org/linux/man-pages/man2/close.2.html#NOTES
        //TODO: Handle error on close
        tls?.close()
        _ = OS.close(fileDescriptor)
    }
    
    open func read() throws -> Byte {
        var byte: Byte = 0
        _ = try read(&byte, size: 1)
        return byte
    }
    
    open func read(_ buffer: UnsafeMutableRawPointer, size: Int) throws -> Int {
        if let tls = tls {
            return try tls.read(buffer, size: size)
        }
        let received = try ing { recv(fileDescriptor, buffer, size, 0) }
        return received
    }
    
    /// Writes all `length` of the `buffer` into the socket by calling
    /// write(_:size:) in a loop.
    ///
    /// - Parameters:
    ///   - buffer: Raw pointer to the buffer.
    ///   - length: Length of the buffer to be written.
    /// - Throws: `Socket.Error` holding `errno`
    open func write(_ buffer: UnsafeRawPointer, length: Int) throws {
        var totalWritten = 0
        while totalWritten < length {
            let written = try write(buffer + totalWritten, size: length - totalWritten)
            totalWritten += written
        }
    }
    
    /// Writes bytes to socket
    ///
    /// - Parameters:
    ///   - buffer: Raw pointer to the buffer.
    ///   - size: Maximum number of bytes to write.
    /// - Returns: Number of written bytes.
    /// - Throws: `Socket.Error` holding `errno`
    open func write(_ buffer: UnsafeRawPointer, size: Int) throws -> Int {
        if let ssl = tls {
            return try ssl.write(buffer, size: size)
        }
        
        let written = OS.write(fileDescriptor, buffer, size)
        if written <= 0 { //see http://man7.org/linux/man-pages/man2/write.2.html#RETURN_VALUE
            throw Error(errno: errno)
        }
        
        return written
    }
    
    open func set<T>(option: Option<T>, _ value: T) throws {
        // setsockopt expects at least Int32 structure, meaning 4 bytes at least.
        // When the `value` variable is Bool, MemoryLayout<Bool>.size returns 1 and
        // bytes in memory are garbage except one of them. (eg. [0, 241, 49, 19], first indicates false)
        // Passing a pointer to `value` variable and size of Int32 (which is 4) into setsockopt
        // would be equal to always passing true since although the byte sequance [0, 241, 49, 19] of `value`
        // variable is false as Bool, it is non-zero as an Int32.
        // We avoid it by explicitly checking whether T is Bool and passing Int32 0 or 1.
        
        let size = value is Bool ? MemoryLayout<Int32>.size : MemoryLayout<T>.size
        var state: Any = value is Bool ? (value as! Bool == true ? 1 : 0) : value
        
        try ing { setsockopt(fileDescriptor, SOL_SOCKET, option.rawValue, &state, socklen_t(size)) }
    }
    
    open func bind(port: Port, address: String? = nil) throws {
        try bind(address: SocketAddress(port: port, address: address))
    }
    
    open func bind(address: SocketAddress) throws {
        var addr = address
        try ing { OS.bind(fileDescriptor, &addr, socklen_t(MemoryLayout<SocketAddress>.size)) }
    }
    
    open func connect(port: Port, address: String? = nil) throws {
        try connect(address: SocketAddress(port: port, address: address))
    }
    
    open func connect(address: SocketAddress) throws {
        var addr = address
        try ing { OS.connect(fileDescriptor, &addr, socklen_t(MemoryLayout<SocketAddress>.size)) }
    }
    
    open func listen(backlog: Int32 = SOMAXCONN) throws {
        try ing { OS.listen(fileDescriptor, backlog) }
    }
    
    open func accept() throws -> Self {
        var addrlen: socklen_t = 0, addr = sockaddr()
        let client = try ing { OS.accept(fileDescriptor, &addr, &addrlen) }
        return type(of: self).init(with: client)
    }
    
    public struct WaitOption: OptionSet {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }
        
        public static let read = WaitOption(rawValue: POLLIN)
        public static let write = WaitOption(rawValue: POLLOUT)
    }
    		
    
    /// Wating for socket to become ready to perform I/O.
    ///
    /// - Parameters:
    ///   - option: `option` to wait for. The option can be masked.
    ///   - timeout: Number of seconds to wait at most.
    ///   - retryOnInterrupt: If enabled, will retry polling when EINTR error happens.
    /// - Returns: Boolean indicating availability of `option`, false means timeout.
    /// - Throws: Socket.Error holding `errno`
    open func wait(for option: WaitOption, timeout: TimeInterval, retryOnInterrupt: Bool = true) throws -> Bool {
        var fd = pollfd() //swift zeroes out memory of any struct. no need to memset 0
        fd.fd = fileDescriptor
        fd.events = Int16(option.rawValue)
        
        var rc: Int32 = 0
        repeat {
            rc = poll(&fd, 1, Int32(timeout * 1000))
        } while retryOnInterrupt && rc == -1 && errno == EINTR //retry on interrupt
        
        //-1 will throw error, 0 means timeout, otherwise success
        return try ing { rc } != 0
    }
    
    
    /// Resolves domain into connectable addresses.
    ///
    /// - Parameters:
    ///   - host: The hostname to dns lookup.
    ///   - port: The port for SocketAddress.
    /// - Returns: An array of connectable addresses
    /// - Throws: Domain name not resolved
    open func addresses(for host: String, port: Port) throws -> [SocketAddress] {
        var hints = addrinfo()
        
        //TODO: set correct values of current socket
        hints.ai_family = Family.inet.rawValue
        hints.ai_socktype = Type.stream.rawValue
        hints.ai_protocol = Protocol.tcp.rawValue
        
        var addrs: UnsafeMutablePointer<addrinfo>?
        if getaddrinfo(host, String(port), &hints, &addrs) != 0 {
            // unable to resolve
            throw Error(errno: 11) //TODO: fix this thing
        }
        defer { freeaddrinfo(addrs) }
        
        var result: [SocketAddress] = []
        for addr in sequence(first: addrs!, next: { $0.pointee.ai_next }) {
            result.append(addr.pointee.ai_addr.pointee)
        }
        assert(!result.isEmpty)
        return result
    }
    
    
    open func startTls(_ config: TLS.Configuration) throws {
        tls = try TLS(self.fileDescriptor, config)
        try tls?.handshake()
    }

    /// Returns the local port number to which the socket is bound.
    ///
    /// - Returns: Local port to which the socket is bound.
    open func port() throws -> Port {
        var address = sockaddr_in()
        var len = socklen_t(MemoryLayout.size(ofValue: address))
        let ptr = UnsafeMutableRawPointer(&address).assumingMemoryBound(to: sockaddr.self)

        try ing { getsockname(fileDescriptor, ptr, &len) }

        return Port(address.sin_port.bigEndian)
    }
}

extension Socket {
    open class func tcpListening(port: Port, address: String? = nil, maxPendingConnection: Int32 = SOMAXCONN) throws -> Self {
        
        let socket = try self.init(.inet)
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
}

extension SocketAddress {
    public init(port: Port, address: String? = nil) {
        var addr = sockaddr_in() //no need to memset 0. Swift does it
        #if !os(Linux)
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.stride)
        #endif
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        
        if let address = address {
            let r = inet_pton(AF_INET, address, &addr.sin_addr)
            assert(r == 1, "\(address) is not converted.")
        }
        
        self = withUnsafePointer(to: &addr) {
            UnsafePointer<SocketAddress>(OpaquePointer($0)).pointee
        }
    }
}

extension TimeValue {
    public init(seconds: Int, milliseconds: Int = 0, microseconds: Int = 0) {
        #if !os(Linux)
            let microseconds = Int32(microseconds)
            let milliseconds = Int32(milliseconds)
        #endif
        self.init(tv_sec: seconds, tv_usec: microseconds + milliseconds * 1000)
    }
}
