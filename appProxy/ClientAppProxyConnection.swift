/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This file contains the ClientAppProxyTCPConnection and ClientAppProxyUDPConnection classes. The ClientAppProxyTCPConnection class handles the encapsulation and decapsulation of a stream of application network data in the client side of the SimpleTunnel tunneling protocol. The ClientAppProxyUDPConnection class handles the encapsulation and decapsulation of a sequence of datagrams containing application network data in the client side of the SimpleTunnel tunneling protocol.
 */

import Foundation
import testVPNServices
import NetworkExtension


/// An object representing the client side of a logical flow of network data in the SimpleTunnel tunneling protocol.
class ClientAppProxyConnection : Connection {
    
    // MARK: Properties
    
    // Database
    var database: Database!
    
    /// The NEAppProxyFlow object corresponding to this connection.
    let appProxyFlow: NEAppProxyFlow
    
    let TAG = "ClientAppProxyConnection: "
    
    /// A dispatch queue used to regulate the sending of the connection's data through the tunnel connection.
    lazy var queue: DispatchQueue = DispatchQueue(label: "ClientConnection Handle Data queue", attributes: [])
    
    // MARK: Initializers
    
    init(tunnel: ClientTunnel, flow: NEAppProxyFlow) {
        testVPNLog(self.TAG + "initializing a new ClientAppProxyConnection")
        appProxyFlow = flow
        database = Database()
        super.init(connectionIdentifier: flow.hash, parentTunnel: tunnel)
    }
    
    // MARK: Interface
    
    /// Send an "Open" message to the SimpleTunnel server, to begin the process of establishing a flow of data in the SimpleTunnel protocol.
    func open() {
        testVPNLog(self.TAG + "send an \"Open\" message to the SimpleTunnel server, to begin the process of establishing a flow of data in the SimpleTunnel protocol")
        open([:])
    }
    
    /// Send an "Open" message to the SimpleTunnel server, to begin the process of establishing a flow of data in the SimpleTunnel protocol.
    func open(_ extraProperties: [String: AnyObject]) {
        testVPNLog(self.TAG + "send an \"Open\" message to the SimpleTunnel server, to begin the process of establishing a flow of data in the SimpleTunnel protocol")
        guard let clientTunnel = tunnel as? ClientTunnel else {
            // Close the NEAppProxyFlow.
            let error: SimpleTunnelError = .badConnection
            appProxyFlow.closeReadWithError(error as NSError)
            appProxyFlow.closeWriteWithError(error as NSError)
            return
        }
        
        
        let properties = createMessagePropertiesForConnection(identifier, commandType:.open, extraProperties:extraProperties)
        
        clientTunnel.sendMessage(properties) { error in
            if let error = error {
                // Close the NEAppProxyFlow.
                self.appProxyFlow.closeReadWithError(error)
                self.appProxyFlow.closeWriteWithError(error)
            }
        }
    }
    
    /// Handle the result of sending a data message to the SimpleTunnel server.
    func handleSendResult(_ error: NSError?) {
        testVPNLog(self.TAG + "handling send result.")
    }
    
    /// Handle errors that occur on the connection.
    func handleErrorCondition(_ flowError: NEAppProxyFlowError.Code? = nil, notifyServer: Bool = true) {
        testVPNLog(self.TAG +  "an Error occured. Handling it.")
        
        guard !isClosedCompletely else { return }
        
        tunnel?.sendCloseType(.all, forConnection: identifier)
        
        closeConnection(.all)
    }
    
    /// Send a "Data" message to the SimpleTunnel server.
    func sendDataMessage(_ data: Data, extraProperties: [String: AnyObject] = [:]) {
        testVPNLog(self.TAG +  "sending a data message to the server.")
        queue.async {
            
            guard let clientTunnel = self.tunnel as? ClientTunnel else { return }
            
            // Suspend further writes to the tunnel until this write operation is completed.
            self.queue.suspend()
            
            var dataProperties = extraProperties
            dataProperties[TunnelMessageKey.Data.rawValue] = data as AnyObject?
            
            let properties = createMessagePropertiesForConnection(self.identifier, commandType: .data, extraProperties:dataProperties)
            
            clientTunnel.sendMessage(properties) { error in
                
                // Resume the queue to allow subsequent writes.
                self.queue.resume()
                
                // This will schedule another read operation on the NEAppProxyFlow.
                self.handleSendResult(error as NSError?)
            }
        }
    }
    
    // MARK: Connection
    
    /// Handle the "Open Completed" message received from the SimpleTunnel server for this connection.
    override func handleOpenCompleted(_ resultCode: TunnelConnectionOpenResult, properties: [NSObject: AnyObject]) {
        testVPNLog(self.TAG +  "handling open completed messaged received from the SimpleTunnel server")
        guard resultCode == .success else {
            testVPNLog(self.TAG + "Failed to open \(identifier), result = \(resultCode)")
            handleErrorCondition(.peerReset, notifyServer: false)
            return
        }
        
        guard let localAddress = (tunnel as? ClientTunnel)?.connection!.localAddress as? NWHostEndpoint else {
            testVPNLog(self.TAG + "Failed to get localAddress.")
            handleErrorCondition(.internal)
            return
        }
        
        // Now that the SimpleTunnel connection is open, indicate that we are ready to handle data on the NEAppProxyFlow.
        appProxyFlow.open(withLocalEndpoint: localAddress) { error in
            self.handleSendResult(error as NSError?)
        }
    }
    
    override func closeConnection(_ direction: TunnelConnectionCloseDirection) {
        testVPNLog(self.TAG +  "closing connection")
        self.closeConnection(direction, flowError: nil)
    }
    
    func closeConnection(_ direction: TunnelConnectionCloseDirection, flowError: NEAppProxyFlowError.Code?) {
        testVPNLog(self.TAG + "closing connection.")
        super.closeConnection(direction)
        
        var error: NSError?
        if let ferror = flowError {
            error = NSError(domain: NEAppProxyErrorDomain, code: ferror.rawValue, userInfo: nil)
        }
        
        if isClosedForWrite {
            appProxyFlow.closeWriteWithError(error)
        }
        if isClosedForRead {
            appProxyFlow.closeReadWithError(error)
        }
    }
}

/// An object representing the client side of a logical flow of TCP network data in the SimpleTunnel tunneling protocol.
class ClientAppProxyTCPConnection : ClientAppProxyConnection {
    
    // MARK: Properties
    
    /// The NEAppProxyTCPFlow object corresponding to this connection
    var TCPFlow: NEAppProxyTCPFlow {
        return (appProxyFlow as! NEAppProxyTCPFlow)
    }
    
    // MARK: Initializers
    
    init(tunnel: ClientTunnel, newTCPFlow: NEAppProxyTCPFlow) {
        super.init(tunnel: tunnel, flow: newTCPFlow)
        testVPNLog(self.TAG + "clientAppProxyTCPConnection: \(self.identifier), and its TCPFlow: \(self.TCPFlow.description)")
    }
    
    // MARK: ClientAppProxyConnection
    
    /// Send an "Open" message to the SimpleTunnel server, to begin the process of establishing a flow of data in the SimpleTunnel protocol.
    override func open(){
        testVPNLog(self.TAG + "TCP: handling sending an open message ")
        open([
            TunnelMessageKey.TunnelType.rawValue: TunnelLayer.app.rawValue as AnyObject,
            TunnelMessageKey.Host.rawValue: (TCPFlow.remoteEndpoint as! NWHostEndpoint).hostname as AnyObject,
            TunnelMessageKey.Port.rawValue: Int((TCPFlow.remoteEndpoint as! NWHostEndpoint).port)! as AnyObject,
            TunnelMessageKey.AppProxyFlowType.rawValue: AppProxyFlowKind.tcp.rawValue as AnyObject
            ])
    }
    
    /// Handle the result of sending a "Data" message to the SimpleTunnel server.
    override func handleSendResult(_ error: NSError?) {
        testVPNLog(self.TAG + "TCP: handling result of sending a data message")
        if let sendError = error {
            testVPNLog("Failed to send Data Message to the Tunnel Server. error = \(sendError)")
            handleErrorCondition(.hostUnreachable)
            return
        }
        
        // Read another chunk of data from the source application.
        TCPFlow.readData { data, readError in
            guard let readData = data , readError == nil else {
                testVPNLog("Failed to read data from the TCP flow. error = \(readError)")
                self.handleErrorCondition(.peerReset)
                return
            }
            
            guard readData.count > 0 else {
                testVPNLog("\(self.identifier): received EOF on the TCP flow. Closing the flow...")
                self.tunnel?.sendCloseType(.write, forConnection: self.identifier)
                self.TCPFlow.closeReadWithError(nil)
                return
            }
            self.sendDataMessage(readData)
            testVPNLog(self.TAG + "[Send Data To SERVER] time: \(getTime()), length: \(readData.count), from app: \(self.TCPFlow.metaData.sourceAppSigningIdentifier), to: \(self.TCPFlow.remoteEndpoint)")
            let currentIP = self.database.tableAPPCONFIGQueryItem(key: "ip")
            testVPNLog(self.TAG + currentIP!)
            self.database.tableNETWORKFLOWLOGInsertItem(srcIP: currentIP!, srcPort: "localPort", dstIP: (self.TCPFlow.remoteEndpoint as! NWHostEndpoint).hostname, dstPort: (self.TCPFlow.remoteEndpoint as! NWHostEndpoint).port, length: readData.count, proto: "", time: getTime(), app: self.TCPFlow.metaData.sourceAppSigningIdentifier, direction: "out")
            self.database.queryTableNETWORKFLOWLOG()
        }
    }
    
    /// Send data received from the SimpleTunnel server to the destination application, using the NEAppProxyTCPFlow object.
    override func sendData(_ data: Data) {
        testVPNLog(self.TAG + "TCP: " + "send data received from the server to the destination application")
        TCPFlow.write(data) { error in
            if let writeError = error {
                testVPNLog("Failed to write data to the TCP flow. error = \(writeError)")
                self.tunnel?.sendCloseType(.read, forConnection: self.identifier)
                self.TCPFlow.closeWriteWithError(nil)
            }
        }
        let currentIP = self.database.tableAPPCONFIGQueryItem(key: "ip")
        testVPNLog(self.TAG + "[Send Back To APP] time: \(getTime()), length: \(data.count), to app: \(TCPFlow.metaData.sourceAppSigningIdentifier), from: \(TCPFlow.remoteEndpoint)")
        self.database.tableNETWORKFLOWLOGInsertItem(srcIP: (self.TCPFlow.remoteEndpoint as! NWHostEndpoint).hostname, srcPort: (self.TCPFlow.remoteEndpoint as! NWHostEndpoint).port, dstIP: currentIP!, dstPort: "localPort", length: data.count, proto: "", time: getTime(), app: self.TCPFlow.metaData.sourceAppSigningIdentifier, direction: "in")
        self.database.queryTableNETWORKFLOWLOG()
    }
}

/// An object representing the client side of a logical flow of UDP network data in the SimpleTunnel tunneling protocol.
class ClientAppProxyUDPConnection : ClientAppProxyConnection {
    
    // MARK: Properties
    
    /// The NEAppProxyUDPFlow object corresponding to this connection.
    var UDPFlow: NEAppProxyUDPFlow {
        return (appProxyFlow as! NEAppProxyUDPFlow)
    }
    
    /// The number of "Data" messages scheduled to be written to the tunnel that have not been actually sent out on the network yet.
    var datagramsOutstanding = 0
    
    // MARK: Initializers
    
    init(tunnel: ClientTunnel, newUDPFlow: NEAppProxyUDPFlow) {
        super.init(tunnel: tunnel, flow: newUDPFlow)
    }
    
    // MARK: ClientAppProxyConnection
    
    /// Send an "Open" message to the SimpleTunnel server, to begin the process of establishing a flow of data in the SimpleTunnel protocol.
    override func open() {
        testVPNLog(self.TAG + "UDP: " + "sending an open message to the server")
        open([
            TunnelMessageKey.TunnelType.rawValue: TunnelLayer.app.rawValue as AnyObject,
            TunnelMessageKey.AppProxyFlowType.rawValue: AppProxyFlowKind.udp.rawValue as AnyObject
            ])
    }
    
    /// Handle the result of sending a "Data" message to the SimpleTunnel server.
    override func handleSendResult(_ error: NSError?) {
        testVPNLog(self.TAG + "UDP: " + "handling result of sending data message")
        
        if let sendError = error {
            testVPNLog("Failed to send message to Tunnel Server. error = \(sendError)")
            handleErrorCondition(.hostUnreachable)
            return
        }
        
        if datagramsOutstanding > 0 {
            datagramsOutstanding -= 1
        }
        
        // Only read more datagrams from the source application if all outstanding datagrams have been sent on the network.
        guard datagramsOutstanding == 0 else { return }
        
        // Read a new set of datagrams from the source application.
        UDPFlow.readDatagrams { datagrams, remoteEndPoints, readError in
            
            guard let readDatagrams = datagrams,
                let readEndpoints = remoteEndPoints
                , readError == nil else
            {
                testVPNLog("Failed to read data from the UDP flow. error = \(readError)")
                self.handleErrorCondition(.peerReset)
                return
            }
            
            guard !readDatagrams.isEmpty && readEndpoints.count == readDatagrams.count else {
                testVPNLog("\(self.identifier): Received EOF on the UDP flow. Closing the flow...")
                self.tunnel?.sendCloseType(.write, forConnection: self.identifier)
                self.UDPFlow.closeReadWithError(nil)
                return
            }
            
            self.datagramsOutstanding = readDatagrams.count
            
            for (index, datagram) in readDatagrams.enumerated() {
                guard let endpoint = readEndpoints[index] as? NWHostEndpoint else { continue }
                
                testVPNLog("(\(self.identifier)): Sending a \(datagram.count)-byte datagram to \(endpoint.hostname):\(endpoint.port)")
                
                // Send a data message to the SimpleTunnel server.
                self.sendDataMessage(datagram, extraProperties:[
                    TunnelMessageKey.Host.rawValue: endpoint.hostname as AnyObject,
                    TunnelMessageKey.Port.rawValue: Int(endpoint.port)! as AnyObject
                    ])
            }
        }
    }
    
    /// Send a datagram received from the SimpleTunnel server to the destination application.
    override func sendDataWithEndPoint(_ data: Data, host: String, port: Int) {
        testVPNLog(self.TAG + "UDP: send a datagram received from the SimpleTunnel server to the destination application")
        let datagrams = [ data ]
        let endpoints = [ NWHostEndpoint(hostname: host, port: String(port)) ]
        
        // Send the datagram to the destination application.
        UDPFlow.writeDatagrams(datagrams, sentBy: endpoints) { error in
            if let error = error {
                testVPNLog("Failed to write datagrams to the UDP Flow: \(error)")
                self.tunnel?.sendCloseType(.read, forConnection: self.identifier)
                self.UDPFlow.closeWriteWithError(nil)
            }
        }
    }
}


