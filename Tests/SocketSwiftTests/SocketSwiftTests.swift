//
//  SocketSwiftTests.swift
//  SocketSwiftTests
//
//  Created by Orkhan Alikhanov on 7/5/17.
//  Copyright © 2017 BiAtoms. All rights reserved.
//

import XCTest
@testable import SocketSwift

class SocketSwiftTests: XCTestCase {
    
    func testTls() {
        let socket = try! Socket(.inet)
        let addr = try! socket.addresses(for: "google.com", port: 443).first!
        try! socket.connect(address: addr)
        try! socket.startTls(TLS.Configuration(peer: "google.com"))
        try! socket.write("GET / HTTP/1.1\r\n\r\n".bytes)
        let expected = "HTTP/1.1 "
        var buff = [Byte](repeating: 0, count: expected.count)
        let read = try! socket.read(&buff, bufferSize: buff.count)
        XCTAssertEqual(read, buff.count)
        XCTAssertEqual(String(bytes: buff, encoding: .utf8), expected)
    }
    
    func testExample() {
        let server = try! Socket.tcpListening(port: 8090)
        
        let client = try! Socket(.inet)
        try! client.connect(port: 8090)
        
        let bytes = "Hello World".bytes
        
        let writableClient = try! server.accept();
        try! writableClient.write(bytes, length: bytes.count)
        writableClient.close()
        
        var readBytes = [Byte]()
        (0..<bytes.count).forEach { _ in
            readBytes.append(try! client.read())
        }
        
        
        XCTAssertEqual(readBytes, bytes)
        client.close()
        server.close()
    }

    func testReceivingMultipleBytes() {
        let server = try! Socket.tcpListening(port: 8090)

        let client = try! Socket(.inet)
        try! client.connect(port: 8090)

        let bytes = "Hello World".bytes
        let writableClient = try! server.accept();
        try! writableClient.write(bytes, length: bytes.count)
        writableClient.close()

        var buffer = [Byte](repeating: 0, count: 16)
        let totalBytesReceived = try! client.read(&buffer, bufferSize: 16)

        let results = Array(buffer.prefix(totalBytesReceived))

        XCTAssertEqual(totalBytesReceived, 11)
        XCTAssertEqual(results, bytes)

        client.close();
        server.close()
    }
    
    func testSetOption() throws {
        //testing only SO_RCVTIMEO
        
        let server = try Socket.tcpListening(port: 8090)
        let client = try Socket(.inet)
        try client.set(option: .receiveTimeout, TimeValue(seconds: 0, microseconds: 50*1000))
        try client.connect(port: 8090)

        XCTAssertThrowsError(try client.read(), "Should throw timeout error") { err in
            XCTAssertEqual(err as? Socket.Error, Socket.Error(errno: EWOULDBLOCK))
        }
        client.close()
        server.close()
    }
    
    func testError() {
        do {
            _ = try Socket.tcpListening(port: 80)
        } catch let error where (error as! Socket.Error) == Socket.Error.aa {
            print(error)
        } catch {
            print("baddd")
        }
    }

    func testPort() throws {
        let server = try Socket.tcpListening(port: 8090)

        XCTAssertEqual(try server.port(), 8090)

        server.close()
    }

    static var allTests = [
        ("testExample", testExample),
        ("testError", testError),
        ("testReceivingMultipleBytes", testReceivingMultipleBytes),
        ("testSetOption", testSetOption),
        ("testTsl", testTls),
        ("testPort", testPort)
    ]
}

private extension String {
    var bytes: [Byte] {
        return [Byte](self.utf8)
    }
}
