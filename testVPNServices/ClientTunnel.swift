//
//  ClientTunnel.swift
//  testVPNServices
//
//  Created by Joe Liu on 2018/8/22.
//  Copyright © 2018年 NUDT. All rights reserved.
//
//  实现客户端的SimpleTunnel协议
//

import Foundation
import NetworkExtension

// Make NEVPNStatus convertible to String
extension NWTCPConnectionState: CustomStringConvertible { // 以NWTCPConnectionState 为输入，CustomStringConvertible为输出
    public var description: String{
        switch self {
        case .cancelled: return "Cancelled"
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnected: return "Disconnected"
        case .invalid: return "Invalid"
        case .waiting: return "Waiting"
        }
    }
}

// Client-side implementation of SimpleTunnel Protocol
open class ClientTunnel: Tunnel{
    
}
