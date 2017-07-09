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
        
        let client = try! Socket(.IPv4)
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
    }
    
    func testError() {
        do {
            let socket = try Socket.tcpListening(port: 80)
        } catch let error where (error as! Socket.Error) == Socket.Error.aa {
            print(error)
        } catch {
            print("baddd")
        }
    }
    
    static var allTests = [
        ("testExample", testExample),
        ("testError", testError)
        ]
}

private extension String {
    var bytes: [Byte] {
        return [Byte](self.utf8)
    }
}
