//
//  ClientTunnelConnection.swift
//  packetTunnel
//
//  Created by Joe Liu on 2018/8/24.
//  Copyright © 2018年 NUDT. All rights reserved.
//
//  本文件包含ClientTunnelConnection类，该类完成了客户端IP报文对应于SimpleTunnel隧道协议的解包封包过程。
//

import Foundation
import testVPNServices
import NetworkExtension

// MARK: Protocols

// The delegate protocol for ClientTunnelConnection
protocol ClientTunnelConnectionDelegate {
    // Handle the connection being opened
    func tunnelConnectionDidOpen(_ connection: ClientTunnelConnection, configuration: [NSObject: AnyObject])
    // Handle the connection being closed
    func tunnelConnectionDidClose(_ connection: ClientTunnelConnection, error: NSError?)
}

// An object used to tunnel IP packets using SimpleTunnel protocol
class ClientTunnelConnection: Connection {
    // MARK: Properties
    
    let TAG = "ClientTunnelConnection: "
    
    // The connection delegate
    let delegate: ClientTunnelConnectionDelegate
    
    // The flow off IP packets
    let packetFlow: NEPacketTunnelFlow
    
    // MARK: Initializers
    
    init(tunnel: ClientTunnel, clientPacketFlow: NEPacketTunnelFlow, connectionDelegate: ClientTunnelConnectionDelegate){
        testVPNLog(self.TAG + "initializing ClientTunnelConnection")
        delegate = connectionDelegate
        packetFlow = clientPacketFlow
        let newConnectionIdentifier = arc4random()
        super.init(connectionIdentifier: Int(newConnectionIdentifier), parentTunnel: tunnel)
    }
    
    // MARK: Interfaces
    
    // open the connection by sending a "open connection" message to the tunnel server
    func open(){
        testVPNLog(self.TAG + "open the connection by sending an open connection message")
        guard let clientTunnel = tunnel as? ClientTunnel else {return}
        
        let properties = createMessagePropertiesForConnection(identifier, commandType: .open, extraProperties: [
            TunnelMessageKey.TunnelType.rawValue: TunnelLayer.ip.rawValue as AnyObject
            ])
        
        clientTunnel.sendMessage(properties) { error in
            if error != nil {
                self.delegate.tunnelConnectionDidClose(self, error: error as! NSError)
                return 
            }
        }
    }
    
    // handle packets coming from the packet flow
    func handlePackets(_ packets: [Data], protocols: [NSNumber]){
        testVPNLog(self.TAG + "handle packets coming from the packet flow.")
        guard  let clientTunnel = tunnel as? ClientTunnel else {return}
        
        let properties = createMessagePropertiesForConnection(identifier, commandType: .packets, extraProperties: [
            TunnelMessageKey.Packets.rawValue: packets as AnyObject,
            TunnelMessageKey.Protocols.rawValue: protocols as AnyObject
            ])
        clientTunnel.sendMessage(properties) { error in
            if error != nil {
                self.delegate.tunnelConnectionDidClose(self, error: error as NSError?)
                return
            }
            
            // Read more packets
            self.packetFlow.readPackets() {inPackets, inProtocols in
                self.handlePackets(inPackets, protocols: inProtocols)
            }
        }
    }
    
    // Make the initial readPacketsWithCompletionHandler call
    func startHandlingPackets(){
        testVPNLog(self.TAG + "Make the initial readPacketsWithCompletionHandler call")
        
        packetFlow.readPackets { inPackets, inProtocols in
            self.handlePackets(inPackets, protocols: inProtocols)
        }
    }
    
    // MARK: Connection
    
    // Handle the event of the connection being established
    override func handleOpenCompleted(_ resultCode: TunnelConnectionOpenResult, properties: [NSObject : AnyObject]) {
        testVPNLog(self.TAG + "handling the event of the connection being established")
        guard resultCode == .success else {
            delegate.tunnelConnectionDidClose(self, error: SimpleTunnelError.badConnection as NSError)
            return
        }
        
        // Pass the tunnel network settings to the delegate
        if let configuration = properties[TunnelMessageKey.Configuration.rawValue as NSString] as? [NSObject: AnyObject] {
            delegate.tunnelConnectionDidOpen(self, configuration: configuration)
        }else{
            delegate.tunnelConnectionDidOpen(self, configuration: [:])
        }
    }
    
    /// Send packets to the virtual interface to be injected into the IP stack.
    override func sendPackets(_ packets: [Data], protocols: [NSNumber]) {
        testVPNLog(self.TAG + "sending apckets to the virtual interface to be injected into the IP stack")
        packetFlow.writePackets(packets, withProtocols: protocols)
    }
}
