//
//  TLS.swift
//  SocketSwift
//
//  Created by Orkhan Alikhanov on 11/22/17.
//  Copyright © 2017 BiAtoms. All rights reserved.
//

import Foundation

#if os(Linux)
    import CLibreSSL
    private typealias SSLContext = OpaquePointer
#endif

open class TLS {
    #if !os(Linux)
    private var fd: FileDescriptor = 0
    #endif
    private var context: SSLContext
    public struct Configuration {
        let peer: String?
        
        public init(peer: String?) {
            self.peer = peer
        }
    }
    
    public init(_ fd: FileDescriptor,  _ config: Configuration) throws {
        
        #if os(Linux)
            // TODO: make `try ing { }` throw TlsError with description of
            // String(cString: tls_error(context))
            try ing { tls_init() }
            context = tls_client()
            
            let cfg = tls_config_new() // can we free cfg after tls_configure?
            try ing { tls_configure(context, cfg) }
            
            try config.peer!.withCString { s in
                try ing { tls_connect_socket(self.context, fd, s) }
            }
            try ing { tls_handshake(context) }
        #else
            guard let context = SSLCreateContext(nil, .clientSide, .streamType) else {
                throw Socket.Error(errno: ENOMEM)
            }
            
            self.context = context
            self.fd = fd
            SSLSetIOFuncs(context, sslRead, sslWrite)
            SSLSetConnection(context, &self.fd)
            if let peerName = config.peer {
                SSLSetPeerDomainName(context, peerName, peerName.characters.count)
            }
            
            var status: OSStatus = -1
            repeat {
                status = SSLHandshake(context)
            } while status == errSSLWouldBlock
            if status != noErr {
                // print(status, SecCopyErrorMessageString(status, nil)!)
                try ing { -1 } // throw
            }
        #endif
    }
    
    open func write(_ buffer: UnsafeRawPointer, size: Int) throws -> Int {
        #if os(Linux)
            return tls_write(context, buffer, size)
        #else
            var written = 0
            if SSLWrite(context, buffer, size, &written) != noErr {
                try ing { -1 } // throw
            }
            return written
        #endif
    }
    
    open func read(_ buffer: UnsafeMutableRawPointer, size: Int) throws -> Int {
        #if os(Linux)
            return tls_read(context, buffer, size)
        #else
            var received = 0
            if SSLRead(context, buffer, size, &received) != noErr {
                try ing { -1 } // throw errno
            }
            return received
        #endif
    }
    
    open func close() {
        #if os(Linux)
            tls_close(context);
            tls_free(context);
            //	tls_config_free(config);
        #else
            SSLClose(context)
        #endif
    }
}

#if !os(Linux)
    
    // Based on https://stackoverflow.com/a/23611166/5555803
    private func sslWrite(connection: SSLConnectionRef, data: UnsafeRawPointer, dataLength: UnsafeMutablePointer<Int>) -> OSStatus {
        let fd = connection.assumingMemoryBound(to: FileDescriptor.self).pointee
        let bytesToWrite = dataLength.pointee
        let written = OS.write(fd, data, bytesToWrite)
        
        dataLength.pointee = written
        if written > 0 {
            return written < bytesToWrite ? errSSLWouldBlock : noErr
        }
        if written == 0 {
            return errSSLClosedGraceful
        }
        
        dataLength.pointee = 0
        return errno == EAGAIN ? errSSLWouldBlock : errSecIO
    }
    
    // Based on https://stackoverflow.com/a/23611166/5555803
    private func sslRead(connection: SSLConnectionRef, data: UnsafeMutableRawPointer, dataLength: UnsafeMutablePointer<Int>) -> OSStatus {
        let fd = connection.assumingMemoryBound(to: FileDescriptor.self).pointee
        let bytesToRead = dataLength.pointee
        let read = recv(fd, data, bytesToRead, 0)
        dataLength.pointee = read
        if read > 0 {
            return read < bytesToRead ? errSSLWouldBlock : noErr
        }
        
        if read == 0 {
            return errSSLClosedGraceful
        }
        
        dataLength.pointee = 0
        switch errno {
        case ENOENT:
            return errSSLClosedGraceful
        case EAGAIN:
            return errSSLWouldBlock
        case ECONNRESET:
            return errSSLClosedAbort
        default:
            return errSecIO
        }
    }
#endif
