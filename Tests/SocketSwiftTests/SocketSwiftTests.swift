//
//  SocketSwiftTests.swift
//  SocketSwiftTests
//
//  Created by Orkhan Alikhanov on 7/5/17.
//  Copyright © 2017 BiAtoms. All rights reserved.
//

import XCTest
import Dispatch
@testable import SocketSwift

class SocketSwiftTests: XCTestCase {

    #if os(Linux)
    override class func setUp() {
        super.setUp()
        try! TLS.initialize()
    }
    #endif
    
    func testClientReadWriteTLSWithGoogle() {
        let socket = try! Socket(.inet)
        let addr = try! socket.addresses(for: "google.com", port: 443).first!
        try! socket.connect(address: addr)
        try! socket.startTls(TLS.Configuration(peer: "google.com"))
        try! socket.write("GET / HTTP/1.1\r\n\r\n".bytes)
        AssertReadStringEqual(socket: socket, string: "HTTP/1.1 ")
    }
    
    func testClientServerReadWriteTLS() {
        let server = try! Socket.tcpListening(port: 4443)
        
        DispatchQueue(label: "").async {
            var tls = TLS.Configuration()
            
            #if !os(Linux)
                let path = Bundle(for: SocketSwiftTests.self).url(forResource: "Socket.swift", withExtension: "pfx")!
                tls.certificate = TLS.importCert(at: path, password: "orkhan1234")
            #else
                let file = URL(string: #file)!.appendingPathComponent("../../Socket.swift").standardized
                tls.certificate = TLS.importCert(at: file.appendingPathExtension("csr"),
                                                 withKey: file.appendingPathExtension("key"),
                                                 password: nil)
            #endif
            let writableClient = try! server.accept()
            try! writableClient.startTls(tls)
            AssertReadStringEqual(socket: writableClient, string: "Hello from client")
            try! writableClient.write("Hello from server".bytes)
            writableClient.close()
        }
        
        let client = try! Socket(.inet)
        try! client.connect(port: 4443)
        try! client.startTls(.init(peer: "www.biatoms.com", allowSelfSigned: true))
        try! client.write("Hello from client".bytes)
        AssertReadStringEqual(socket: client, string: "Hello from server")
        client.close()
        server.close()
    }
    
    func testClientServerReadWrite() {
        let server = try! Socket.tcpListening(port: 8090)
        
        let client = try! Socket(.inet)
        try! client.connect(port: 8090)
        
        let writableClient = try! server.accept()
        try! writableClient.write("Hello World".bytes)
        writableClient.close()
        AssertReadStringEqual(socket: client, string: "Hello World")
        
        client.close()
        server.close()
    }
    
    func testSetOption() throws {
        //testing only SO_RCVTIMEO
        
        let server = try Socket.tcpListening(port: 8090)
        let client = try Socket(.inet)
        #if canImport(ObjectiveC)
        try client.set(option: .receiveTimeout, TimeValue(seconds: 0, microseconds: 50*1000))
        #else
        try client.set(option: .receiveTimeout, TimeValue(tv_sec: 0, tv_usec: 50*1000))
        #endif
        try client.connect(port: 8090)
        
        XCTAssertThrowsError(try client.read(), "Should throw timeout error") { err in
            XCTAssertEqual(err as? Socket.Error, Socket.Error(errno: EWOULDBLOCK))
        }
        client.close()
        server.close()
    }
    
    func testError() {
        let server = try? Socket.tcpListening(port: 80)
        XCTAssertThrowsError(try Socket.tcpListening(port: 80), "Should throw") { err in
            XCTAssert(err is Socket.Error)
            let socketError = err as! Socket.Error
            XCTAssert(socketError == Socket.Error(errno: EADDRINUSE) || socketError == Socket.Error(errno: EACCES))
        }
        
        server?.close()
    }
    
    func testPort() throws {
        let server = try Socket.tcpListening(port: 8090)
        XCTAssertEqual(try server.port(), 8090)
        server.close()
    }
    
    static var allTests = [
        ("testPort", testPort),
        ("testError", testError),
        ("testSetOption", testSetOption),
        ("testClientServerReadWrite", testClientServerReadWrite),
        ("testClientServerReadWriteTLS", testClientServerReadWriteTLS),
        ("testClientReadWriteTLSWithGoogle", testClientReadWriteTLSWithGoogle),
    ]
}

private extension String {
    var bytes: [Byte] {
        return [Byte](self.utf8)
    }
}

private extension Array where Element == Byte {
    var string: String? {
        return String(bytes: self, encoding: .utf8)
    }
}

private func AssertReadStringEqual(socket: Socket, string: String, file: StaticString = #file, line: UInt = #line) {
    var buff = [Byte](repeating: 0, count: string.count)
    let bytesRead = try! socket.read(&buff, size: string.count)
    XCTAssertEqual(bytesRead, string.count, file: file, line: line)
    XCTAssertEqual(buff.string, string, file: file, line: line)
}
