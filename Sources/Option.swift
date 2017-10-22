//
//  Option.swift
//  SocketSwift
//
//  Created by Orkhan Alikhanov on 7/7/17.
//  Copyright © 2017 BiAtoms. All rights reserved.
//

import Foundation //Darwin or Glibc

extension Socket {
    public class BaseOption: RawRepresentable {
        public let rawValue: Int32
        public required init(rawValue: Int32) {
            self.rawValue = rawValue
        }
    }
    
    public class Option<T>: BaseOption {}
}

extension Socket.BaseOption {
    private typealias Option = Socket.Option
    public static let reuseAddress = Option<Bool>(rawValue: SO_REUSEADDR)
    public static let reusePort = Option<Bool>(rawValue: SO_REUSEPORT)
    public static let keepAlive = Option<Bool>(rawValue: SO_KEEPALIVE)
    public static let debug = Option<Bool>(rawValue: SO_DEBUG)
    public static let dontRoute = Option<Bool>(rawValue: SO_DONTROUTE)
    public static let broadcast = Option<Bool>(rawValue: SO_BROADCAST)
    public static let sendBufferSize = Option<Int32>(rawValue: SO_SNDBUF)
    public static let receiveBufferSize = Option<Int32>(rawValue: SO_RCVBUF)
    public static let sendLowWaterMark = Option<Int32>(rawValue: SO_SNDLOWAT)
    public static let receiveLowWaterMark = Option<Int32>(rawValue: SO_RCVLOWAT)
    public static let sendTimeout = Option<TimeValue>(rawValue: SO_SNDTIMEO)
    public static let receiveTimeout = Option<TimeValue>(rawValue: SO_RCVTIMEO)
    
    #if !os(Linux)
    public static let noSignalPipe = Option<Bool>(rawValue: SO_NOSIGPIPE)
    #endif
    
}
