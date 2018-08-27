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
    
    // MARK: Properties
    
    let TAG = "PacketTunnelProvider: "
    
    // a reference to the tunnel object
     var tunnel: ClientTunnel?
    
    // The single logical flow of packets through the tunnel
     var tunnelConnection: ClientTunnelConnection?
    
    // The completion handler to call when the tunnel is fully established
    var pendingStartCompletion: ((Error?) -> Void)?
    
    // The completion handler to call when the tunnel is fully disconnected
    var pendingStopCompletion: (() -> Void)?

    // MARK: NEPacketTunnelProvider
    
    // Begin the process of establishing a tunnel.
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        testVPNLog(TAG+" starting VPN Tunnel.")
        
        let newTunnel = ClientTunnel()
        newTunnel.delegate = self
        
        if let error = newTunnel.startTunnel(self){
            testVPNLog(self.TAG + " start Tunnel error")
            completionHandler(error as NSError)
        }
        else {
            // Save the completion handler for when the tunnel is fully established
            pendingStartCompletion = completionHandler
            tunnel = newTunnel
        }
    }
    
    // Begin the process of stopping a tunnel
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        //completionHandler()
        // clear out any pendingStartCompletion handler
        testVPNLog(self.TAG + "stopping tunnel")
        pendingStartCompletion = nil
        
        // Save the completion handler for when the tunnel is fully disconnected
        pendingStopCompletion = completionHandler
        tunnel?.closeTunnel()
    }
    
    // Handle IPC Message from the app
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        //if let handler = completionHandler {
        //    handler(messageData)
        //}
        testVPNLog(self.TAG + "handling app message")
        guard let messageString = NSString(data: messageData, encoding: String.Encoding.utf8.rawValue) else {
            completionHandler?(nil)
            return
        }
        
        testVPNLog(self.TAG + "Got a message from the app \(messageString)")
        
        let responseData = "Hello App".data(using: String.Encoding.utf8)
        completionHandler?(responseData)
    }
    
    // MARK: Tunnel Delegate
    
    // Handle the event tunnel connection being established
    func tunnelDidOpen(_ targetTunnel: Tunnel){
        // Open the logical flow of packets through the tunnel
        let newConnection = ClientTunnelConnection(tunnel: tunnel!, clientPacketFlow: packetFlow, connectionDelegate: self)
        newConnection.open()
        tunnelConnection = newConnection
    }
    
    // Handle the event tunnel connection being closed
    func tunnelDidClose(_ targetTunnel: Tunnel) {
        if pendingStartCompletion != nil {
            // Closed while starting, call the completion handler with the appropriate error
            pendingStartCompletion?(tunnel?.lastError)
            pendingStartCompletion = nil
        }
        else if pendingStopCompletion != nil {
            // Closed as the result of a call to stopTunnelWithReason, call the stop completion handler.
            pendingStopCompletion?()
            pendingStopCompletion = nil
        }
        else {
            // Closed as the result of an error on the tunnel connection, cancel the tunnel.
            cancelTunnelWithError(tunnel?.lastError)
        }
        
        tunnel = nil
    }
    
    // Handle the server sending a configuration
    func tunnelDidSendConfiguration(_ targetTunnel: Tunnel, configuration: [String: AnyObject]){
    }
    
    // MARK: ClientTunnelConnectionDelegate
    
    // Handle the event of the logical flow of packets being established through the tunnel
    func tunnelConnectionDidOpen(_ connection: ClientTunnelConnection, configuration: [NSObject: AnyObject]){
        testVPNLog(self.TAG + "tunnelConnectionDidOpen, going to set settings for it.")
        
        // create virtual interface settings
        guard let settings = createTunnelSettingsFromConfiguration(configuration) else {
            pendingStartCompletion?(SimpleTunnelError.internalError as NSError)
            pendingStartCompletion = nil
            return
        }
        
        // Set the virtual interface settings
        setTunnelNetworkSettings(settings) { error in
            var startError: NSError?
            if let error = error {
                testVPNLog(self.TAG + "Failed to set Tunnel Network settings \(error)")
                startError = SimpleTunnelError.badConfiguration as NSError
            }
            else{
                // Now we can start reading or writing packets from/to virtual interface
                self.tunnelConnection?.startHandlingPackets()
            }
            
            // Now the tunnel is fully established, call the start completion handler
            self.pendingStartCompletion?(startError)
            self.pendingStartCompletion = nil
            
        }
    }
    
    /// Handle the event of the logical flow of packets being torn down.
    func tunnelConnectionDidClose(_ connection: ClientTunnelConnection, error: NSError?) {
        tunnelConnection = nil
        tunnel?.closeTunnelWithError(error)
    }
    
    // create tunnel network settings to be applied to virtual interfaces
    func createTunnelSettingsFromConfiguration(_ configuration: [NSObject: AnyObject]) -> NEPacketTunnelNetworkSettings? {
        testVPNLog(self.TAG + "creating tunnel settings from configuration" )
        guard let tunnelAddress = tunnel?.remoteHost,
        let address = getValueFromPlist(configuration, keyArray: [.IPv4, .Address]) as? String,
        let netmask = getValueFromPlist(configuration, keyArray: [.IPv4, .Address]) as? String
            else {return nil}
        
        let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: tunnelAddress)
        var fullTunnel = true
        
        newSettings.iPv4Settings = NEIPv4Settings(addresses: [address], subnetMasks: [netmask])
        
        if let routes = getValueFromPlist(configuration, keyArray: [.IPv4, .Routes]) as? [[String: AnyObject]] {
            var includedRoutes = [NEIPv4Route]()
            
            for route in routes {
                if let netAddress = route[SettingsKey.Address.rawValue] as? String,
                    let netMask = route[SettingsKey.Address.rawValue] as? String{
                    includedRoutes.append(NEIPv4Route(destinationAddress: netAddress, subnetMask: netMask))
                }
            }
            
            newSettings.iPv4Settings?.includedRoutes = includedRoutes
            fullTunnel = false
        }
        else{
            // No route specified, use the default route
            newSettings.iPv4Settings?.includedRoutes = [NEIPv4Route.default()]
        }
        
        if let DNSDictionary = configuration[SettingsKey.DNS.rawValue as NSString] as? [String: AnyObject],
        let DNSServers = DNSDictionary[SettingsKey.Servers.rawValue] as? [String]
        {
            newSettings.dnsSettings = NEDNSSettings(servers: DNSServers)
            if let DNSSearchDomains = DNSDictionary[SettingsKey.SearchDomains.rawValue] as? [String] {
                newSettings.dnsSettings?.searchDomains = DNSSearchDomains
                if !fullTunnel {
                    newSettings.dnsSettings?.matchDomains = DNSSearchDomains
                }
            }
        }
        
        newSettings.tunnelOverheadBytes = 150
        return newSettings
    }
    
    
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
}
