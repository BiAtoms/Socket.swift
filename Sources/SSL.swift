//
//  SSL.swift
//  SocketSwift
//
//  Created by Orkhan Alikhanov on 11/22/17.
//  Copyright © 2017 BiAtoms. All rights reserved.
//

import Foundation

open class SSL {
    open var fd: FileDescriptor = 0
    private var context: SSLContext
    
    public struct Configuration {
        let peer: String?
        
        public init(peer: String?) {
            self.peer = peer
        }
    }
    
    public init(_ fd: FileDescriptor,  _ config: Configuration) throws {
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
    }
    
    open func write(_ buffer: UnsafeRawPointer, size: Int) throws -> Int {
        var written = 0
        if SSLWrite(context, buffer, size, &written) != noErr {
            try ing { -1 } // throw
        }
        return written
    }
    
    open func read(_ buffer: UnsafeMutableRawPointer, size: Int) throws -> Int {
        var received = 0
        if SSLRead(context, buffer, size, &received) != noErr {
            try ing { -1 } // throw errno
        }
        return received
    }
    
    open func close() {
        SSLClose(context)
    }
}


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
