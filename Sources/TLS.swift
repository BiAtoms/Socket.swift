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
    internal typealias SSLContext = OpaquePointer
    public typealias Certificate = (cert: Data, key: Data)
#else
    public typealias Certificate = CFArray
#endif

open class TLS {
    #if !os(Linux)
    open var fd: FileDescriptor { return fdPtr.pointee }
    open private(set) var fdPtr = UnsafeMutablePointer<FileDescriptor>.allocate(capacity: 1)
    #else
    public private(set) static var isInitialized = false
    public static func initialize() throws {
        guard !isInitialized else { return }
        try ing { tls_init() }
        isInitialized = true
    }
    #endif
    
    internal var context: SSLContext
    public struct Configuration {
        public var peer: String?
        public var certificate: Certificate?
        public var allowSelfSigned: Bool
        public var isServer: Bool { return certificate != nil }
        
        public init(peer: String? = nil, certificate: Certificate? = nil, allowSelfSigned: Bool = false) {
            self.peer = peer
            self.certificate = certificate
            self.allowSelfSigned = allowSelfSigned
        }
    }
    
    public init(_ fd: FileDescriptor,  _ config: Configuration) throws {
        
        #if os(Linux)
            // TODO: make `try ing { }` throw TlsError with description of
            // String(cString: tls_error(context))
            
            guard TLS.isInitialized else {
                fatalError("Call TLS.initialize(), concurrent calls will cause crash")
            }
            
            let cfg = tls_config_new()
            defer { tls_config_free(cfg) }
            
            context = config.isServer ? tls_server() : tls_client()
            
            if config.isServer {
                let cert = config.certificate!
                _ = try cert.cert.withUnsafeBytes { ptr in
                    try ing { tls_config_set_cert_mem(cfg, ptr, cert.cert.count) }
                }
                _ = try cert.key.withUnsafeBytes { ptr in
                    try ing { tls_config_set_key_mem(cfg, ptr, cert.key.count) }
                }
            } else {
                if config.allowSelfSigned {
                    tls_config_insecure_noverifycert(cfg)
                    // tls_config_insecure_noverifyname(cfg)
                    // tls_config_insecure_noverifytime(cfg)
                }
            }
            
            try ing { tls_configure(context, cfg) }
            
            if config.isServer {
                var newContext: SSLContext?
                try ing { tls_accept_socket(context, &newContext, fd) }
                // FIXME: It seems that server context is needed to be somehow alive.
                // Although, on accept, it does copy the configurations to the child context
                // free-ing the server context causes fatal error when the child context
                // tries to do handshake.
                
                // tls_free(context)
                context = newContext!
            } else {
                try ing { tls_connect_socket(self.context, fd, config.peer) }
            }
        #else
            self.context = SSLCreateContext(nil, config.isServer ? .serverSide : .clientSide, .streamType)!
            self.fdPtr.pointee = fd
            
            SSLSetIOFuncs(context, sslRead, sslWrite)
            SSLSetConnection(context, fdPtr)
            
            if config.isServer {
                SSLSetCertificate(context, config.certificate)
            } else {
                if let peerName = config.peer {
                    SSLSetPeerDomainName(context, peerName, peerName.count)
                }
                
                if config.allowSelfSigned {
                    SSLSetSessionOption(context, .breakOnServerAuth, true)
                }
            }
        #endif
    }
    
    open func handshake() throws {
        #if os(Linux)
            try ing { tls_handshake(context) }
        #else
            var status: OSStatus = -1
            repeat {
                status = SSLHandshake(context)
            } while status == errSSLWouldBlock
            if status != noErr && status != errSSLPeerAuthCompleted {
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
        #else
            SSLClose(context)
            fdPtr.deallocate()
        #endif
    }
}

extension TLS {
    #if !os(Linux)
    open class func importCert(at path: URL, password: String) -> Certificate {
        let data = FileManager.default.contents(atPath: path.path)! as NSData
        let options: NSDictionary = [kSecImportExportPassphrase: password]

        var items: CFArray?
        let status = SecPKCS12Import(data, options, &items)
        assert(status == noErr)
        let dictionary = (items! as [AnyObject])[0]
        let secIdentity = dictionary.value(forKey: kSecImportItemIdentity as String)!
        let ccerts = dictionary.value(forKey: kSecImportItemCertChain as String) as! [SecCertificate]
        
        let certs = [secIdentity] + ccerts.dropFirst().map { $0 as Any }
        return certs as CFArray
    }
    
    #else
    open class func importCert(at path: URL, withKey key: URL, password: String?) -> Certificate {
        var certLen = 0
        let certMem = tls_load_file(path.path, &certLen, nil)!
        defer { free(certMem) }
    
        var keyLen = 0
        let keyMem = {
            password?.withCString {
                tls_load_file(key.path, &keyLen, UnsafeMutablePointer(mutating: $0))!
            } ?? tls_load_file(key.path, &keyLen, nil)!
        }()
        defer { free(keyMem) }
    
        return (Data(bytes: certMem, count: certLen), Data(bytes: keyMem, count: keyLen))
    }
    #endif
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
