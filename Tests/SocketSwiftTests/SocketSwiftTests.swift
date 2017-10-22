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
    
    static var allTests = [
        ("testExample", testExample),
        ("testError", testError),
        ("testReceivingMultipleBytes", testReceivingMultipleBytes),
        ("testSetOption", testSetOption)
    ]
}

private extension String {
    var bytes: [Byte] {
        return [Byte](self.utf8)
    }
}
