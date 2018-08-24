//
//  PacketTunnelProvider.swift
//  packetTunnel
//
//  Created by Joe Liu on 2018/8/22.
//  Copyright © 2018年 NUDT. All rights reserved.
//
//  本文件内含PacketTunnelProvider类。PacketTunnelProvider类是NEPacketTunnelProvider的子类，是NE框架与SimpleTunnel隧道协议之间的连接点
//

import NetworkExtension
import testVPNServices

class PacketTunnelProvider: NEPacketTunnelProvider, TunnelDelegate, ClientTunnelConnectionDelegate {
    let TAG = "<AINASSINE> PacketTunnelProvider: "
    
    // a reference to the tunnel object
    var tunnel: ClientTunnel?
    
    // The single logical flow of packets through the tunnel
    var tunnelConnection: ClientTunnelConnection?
    
    // The completion handler to call when the tunnel is fully established
    var pendingStartCompletion: ((Error?) -> Void)?
    
    // The completion handler to call when the tunnel is fully disconnected
    var pendingStopCompletion: ((Void) -> Void)

    // Begin the process of establishing a tunnel.
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        testVPNLog(TAG+" starting VPN Tunnel.")
        
        
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
}
