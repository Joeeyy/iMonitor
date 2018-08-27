//
//  AppProxyProvider.swift
//  appProxy
//
//  Created by Joe Liu on 2018/8/22.
//  Copyright © 2018年 NUDT. All rights reserved.
//
//  本文件包含AppProxyProvider类。AppProxyProvider是NEAppProxyProvider的子类，是NetworkExtension和SimpleTunnel隧道协议的连接点。
//

import NetworkExtension
import testVPNServices

// A NEAppProxyProvider sub-class that implements the client side of the SimpleTunnel tunneling protocol.
class AppProxyProvider: NEAppProxyProvider, TunnelDelegate {
    
    // MARK: Properties
    
    // A reference to the tunnel object
    var tunnel: ClientTunnel?
    
    /// The completion handler to call when the tunnel is fully established.
    var pendingStartCompletion: ((NSError?) -> Void)?
    
    /// The completion handler to call when the tunnel is fully disconnected.
    var pendingStopCompletion: ((Void) -> Void)?
    
    // MARK: NEAppProxyProvider
    let TAG = "AppProxyProvider: "

    // begin the process of establishing the tunnel
    override func startProxy(options: [String : Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        testVPNLog(self.TAG + " starting PER_APP_PROXY tunnel")
        let newTunnel = ClientTunnel()
        newTunnel.delegate = self
        
        if let error = newTunnel.startTunnel(self) {
            completionHandler(error as NSError)
            testVPNLog(self.TAG + " start new Tunnel failed.")
            return
        }
        testVPNLog(self.TAG+" PER_APP_PROXY started successfully!")
        pendingStartCompletion = completionHandler
        tunnel = newTunnel
    }
    
    // begin the process of stop the proxy
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        // Clear out any pending start completion handler.
        testVPNLog(self.TAG + " Stopping PER_APP_VPN.")
        pendingStartCompletion = nil
        
        pendingStopCompletion = completionHandler
        tunnel?.closeTunnel()
        testVPNLog(self.TAG + " PER_APP_VPN stopped.")
    }
    
    // Handle a new flow of network data created by an application
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        // Add code here to handle the incoming flow.
        testVPNLog(self.TAG+" A new PER_APP_PROXY_FLOW comes, start handling it.")
        var newConnection: ClientAppProxyConnection?
        
        guard let clientTunnel = tunnel else { return false }
        
        if let TCPFlow = flow as? NEAppProxyTCPFlow {
            testVPNLog(self.TAG + " it's a TCP Flow, description: \(TCPFlow.description), from app: \(TCPFlow.metaData.sourceAppSigningIdentifier).")
            newConnection = ClientAppProxyTCPConnection(tunnel: clientTunnel, newTCPFlow: TCPFlow)
        }
        else if let UDPFlow = flow as? NEAppProxyUDPFlow {
            testVPNLog(self.TAG + " it's a UDP Flow, description: \(UDPFlow.description), from app: \(UDPFlow.metaData.sourceAppSigningIdentifier).")
            newConnection = ClientAppProxyUDPConnection(tunnel: clientTunnel, newUDPFlow: UDPFlow)
        }
        
        guard newConnection != nil else { testVPNLog(self.TAG + " new connection established failed."); return false }
        
        newConnection!.open()
        testVPNLog(self.TAG + " new connection established.")
        
        return true
    }
    
    // MARK: Tunnel Delegate
    
    /// Handle the event of the tunnel being fully established.
    func tunnelDidOpen(_ targetTunnel: Tunnel) {
        guard let clientTunnel = targetTunnel as? ClientTunnel else {
            pendingStartCompletion?(SimpleTunnelError.internalError as NSError)
            pendingStartCompletion = nil
            return
        }
        testVPNLog(self.TAG + " Tunnel opened, fetching configuration")
        clientTunnel.sendFetchConfiguation()
    }
    
    /// Handle the event of the tunnel being fully disconnected.
    func tunnelDidClose(_ targetTunnel: Tunnel) {
        
        // Call the appropriate completion handler depending on the current pending tunnel operation.
        if pendingStartCompletion != nil {
            pendingStartCompletion?(tunnel?.lastError)
            pendingStartCompletion = nil
        }
        else if pendingStopCompletion != nil {
            pendingStopCompletion?()
            pendingStopCompletion = nil
        }
        else {
            // No completion handler, so cancel the proxy.
            cancelProxyWithError(tunnel?.lastError)
        }
        testVPNLog(self.TAG + " Tunnel closed.")
        tunnel = nil
    }
    
    /// Handle the server sending a configuration.
    func tunnelDidSendConfiguration(_ targetTunnel: Tunnel, configuration: [String : AnyObject]) {
        testVPNLog(self.TAG + " Server sent configuration: \(configuration)")
        
        guard let tunnelAddress = tunnel?.remoteHost else {
            let error = SimpleTunnelError.badConnection
            pendingStartCompletion?(error as NSError)
            pendingStartCompletion = nil
            return
        }
        
        guard let DNSDictionary = configuration[SettingsKey.DNS.rawValue] as? [String: AnyObject], let DNSServers = DNSDictionary[SettingsKey.Servers.rawValue] as? [String] else {
            self.pendingStartCompletion?(nil)
            self.pendingStartCompletion = nil
            return
        }
        
        let newSettings = NETunnelNetworkSettings(tunnelRemoteAddress: tunnelAddress)
        
        newSettings.dnsSettings = NEDNSSettings(servers: DNSServers)
        if let DNSSearchDomains = DNSDictionary[SettingsKey.SearchDomains.rawValue] as? [String] {
            newSettings.dnsSettings?.searchDomains = DNSSearchDomains
        }
        
        testVPNLog(self.TAG + " Calling setTunnelNetworkSettings")
        
        self.setTunnelNetworkSettings(newSettings) { error in
            if error != nil {
                let startError = SimpleTunnelError.badConfiguration
                self.pendingStartCompletion?(startError as NSError)
                self.pendingStartCompletion = nil
            }
            else {
                self.pendingStartCompletion?(nil)
                self.pendingStartCompletion = nil
            }
        }
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping() -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
}
