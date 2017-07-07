//
//  Family.swift
//  SocketSwift
//
//  Created by Orkhan Alikhanov on 7/7/17.
//  Copyright © 2017 BiAtoms. All rights reserved.
//

import Foundation

extension Socket {
    public struct Family: RawRepresentable {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }
        
        public static let IPv4 = Family(rawValue: AF_INET)
        public static let IPv6 = Family(rawValue: AF_INET6)
    }
}
