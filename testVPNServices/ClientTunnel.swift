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
    // MARK: Properties
    
    // The Tunnel Connection
    open var connection: NWTCPConnection?
    
    // The last Error that occured in the tunnel
    open var lastError: NSError?
    
    // The previously-received incomplete message data
    var previousData: NSMutableData?
    
    // The address of the tunnel server
    open var remoteHost: String?
    
    // MARK: Interface
    
    // Start the TCP connection with the server
    open func startTunnel(_ provider: NETunnelProvider) -> SimpleTunnelError {
        guard let serverAddress = provider.protocolConfiguration.serverAddress else{
            return .badConfiguration
        }
        
        let endPoint = NWEndpoint
        
        if let colonRange = serverAddress.rangeOfCharacter(from: CharacterSet(charactersIn: ":"), options: [], range: nil) {
            // The server is specified in the form <ip>:<port>
            
            let hostname = serverAddress.subString(with: serverAddress.startIndex..<colonRange.lowerBound)
            let portString = serverAddress.substring(with: serverAddress.index(after: colonRange.lowerBound)..<serverAddress.endIndex)
            
            guard !hostname.isEmpty && !portString.isEmpty else {
                return .badConfiguration
            }
            
            endPoint = NWEndpoint(hostname: hostname, port: portString)
        }else{
            // The server is specified in the config file in the form of a Boujour service name
            endPoint = NWBonjourServiceEndpoint(name: serverAddress, type: Tunnel.serviceType, domain: Tunnel.serviceDomain)
        }
        
        // Kick off the connection to the server
        connection = provider.createTCPConnection(name: serverAddress, enableTLS: false, tlsParameters: nil, delegate: nil)
        
        // register for notifications when the connection status is changed
        connection!.addObserver(self, forKeyPath: "state", options: .initial, context: &connection)
        
        return nil
    }
    
    // close the tunnel
    open func closeTunnelWithError(_ error: NSError?){
        lastError = error
        closeTunnel()
    }
    
    // read SimpleTunnel packet from the tunnel connection
    func readNextPacket(){
        guard  let targetConnection = connection else {
            closeTunnelWithError(SimpleTunnelError.badConnection)
        }
    }
}
