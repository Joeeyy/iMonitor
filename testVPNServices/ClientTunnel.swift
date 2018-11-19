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

/// Make NEVPNStatus convertible to a string
extension NWTCPConnectionState: CustomStringConvertible {
    public var description: String {
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

/// The client-side implementation of the SimpleTunnel protocol.
open class ClientTunnel: Tunnel {
    
    // MARK: Properties
    private var database: Database!
    
    private let TAG = "ClientTunnel: "
    
    /// The tunnel connection.
    open var connection: NWTCPConnection?
    
    /// The last error that occurred on the tunnel.
    open var lastError: NSError?
    
    /// The previously-received incomplete message data.
    var previousData: NSMutableData?
    
    /// The address of the tunnel server.
    open var remoteHost: String?
    
    // MARK: Interface
    
    /// Start the TCP connection to the tunnel server.
    open func startTunnel(_ provider: NETunnelProvider) -> SimpleTunnelError? {
        testVPNLog(self.TAG + "starting tunnel")
        
        guard let serverAddress = provider.protocolConfiguration.serverAddress else {
            return .badConfiguration
        }
        
        let endpoint: NWEndpoint
        
        if let colonRange = serverAddress.rangeOfCharacter(from: CharacterSet(charactersIn: ":"), options: [], range: nil) {
            // The server is specified in the configuration as <host>:<port>.
            
            let hostname = serverAddress.substring(with: serverAddress.startIndex..<colonRange.lowerBound)
            let portString = serverAddress.substring(with: serverAddress.index(after: colonRange.lowerBound)..<serverAddress.endIndex)
            
            guard !hostname.isEmpty && !portString.isEmpty else {
                return .badConfiguration
            }
            
            endpoint = NWHostEndpoint(hostname:hostname, port:portString)
        }
        else {
            // The server is specified in the configuration as a Bonjour service name.
            endpoint = NWBonjourServiceEndpoint(name: serverAddress, type:Tunnel.serviceType, domain:Tunnel.serviceDomain)
        }
        
        // Kick off the connection to the server.
        connection = provider.createTCPConnection(to: endpoint, enableTLS:false, tlsParameters:nil, delegate:nil)
        
        // Register for notificationes when the connection status changes.
        connection!.addObserver(self, forKeyPath: "state", options: .initial, context: &connection)
        
        return nil
    }
    
    /// Close the tunnel.
    open func closeTunnelWithError(_ error: NSError?) {
        testVPNLog(self.TAG + "closing tunnel")
        lastError = error
        closeTunnel()
    }
    
    /// Read a SimpleTunnel packet from the tunnel connection.
    func readNextPacket() {
        testVPNLog(self.TAG + "reading next packet")
        guard let targetConnection = connection else {
            closeTunnelWithError(SimpleTunnelError.badConnection as NSError)
            return
        }
        
        // First, read the total length of the packet.
        targetConnection.readMinimumLength(MemoryLayout<UInt32>.size, maximumLength: MemoryLayout<UInt32>.size) { data, error in
            if let readError = error {
                testVPNLog(self.TAG + "Got an error on the tunnel connection: \(readError)")
                self.closeTunnelWithError(readError as NSError?)
                return
            }
            
            let lengthData = data
            
            guard lengthData!.count == MemoryLayout<UInt32>.size else {
                testVPNLog("Length data length (\(lengthData!.count)) != sizeof(UInt32) (\(MemoryLayout<UInt32>.size)")
                self.closeTunnelWithError(SimpleTunnelError.internalError as NSError)
                return
            }
            
            var totalLength: UInt32 = 0
            (lengthData as! NSData).getBytes(&totalLength, length: MemoryLayout<UInt32>.size)
            
            if totalLength > UInt32(Tunnel.maximumMessageSize) {
                testVPNLog("Got a length that is too big: \(totalLength)")
                self.closeTunnelWithError(SimpleTunnelError.internalError as NSError)
                return
            }
            
            totalLength -= UInt32(MemoryLayout<UInt32>.size)
            
            // Second, read the packet payload.
            targetConnection.readMinimumLength(Int(totalLength), maximumLength: Int(totalLength)) { data, error in
                if let payloadReadError = error {
                    testVPNLog("Got an error on the tunnel connection: \(payloadReadError)")
                    self.closeTunnelWithError(payloadReadError as NSError?)
                    return
                }
                
                let payloadData = data
                
                guard payloadData!.count == Int(totalLength) else {
                    testVPNLog("Payload data length (\(payloadData!.count)) != payload length (\(totalLength)")
                    self.closeTunnelWithError(SimpleTunnelError.internalError as NSError)
                    return
                }
                
                _ = self.handlePacket(payloadData!)
                
                self.readNextPacket()
            }
        }
    }
    
    /// Send a message to the tunnel server.
    open func sendAData(data: Data, completionHandler: @escaping (Error?) -> Void) {
        testVPNLog(self.TAG + "send a message to the tunnel server, messageProperties: \(data)")
        /*guard let messageData = serializeMessage(messageProperties) else {
            completionHandler(SimpleTunnelError.internalError as NSError)
            return
        }*/
        
        connection?.write(data, completionHandler: completionHandler)
    }
    
    /// Send a message to the tunnel server.
    open func sendMessage(_ messageProperties: [String: AnyObject], completionHandler: @escaping (Error?) -> Void) {
        testVPNLog(self.TAG + "send a message to the tunnel server, messageProperties: \(messageProperties)")
        guard let messageData = serializeMessage(messageProperties) else {
            completionHandler(SimpleTunnelError.internalError as NSError)
            return
        }
        
        connection?.write(messageData, completionHandler: completionHandler)
    }
    
    // MARK: NSObject
    
    /// Handle changes to the tunnel connection state.
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        testVPNLog(self.TAG + "observe changes to the tunnel connection state")
        
        guard keyPath == "state" && context?.assumingMemoryBound(to: Optional<NWTCPConnection>.self).pointee == connection else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        testVPNLog(self.TAG + "Tunnel connection state changed to \(connection!.state)")
        
        switch connection!.state {
        case .connected:
            if let remoteAddress = self.connection!.remoteAddress as? NWHostEndpoint {
                remoteHost = remoteAddress.hostname
            }
            
            let port = (self.connection!.localAddress as? NWHostEndpoint)?.port
            
            testVPNLog(self.TAG + "\(port)")
            database = Database()
            let lastPort = self.database.tableAPPCONFIGQueryItem(key: "port")
            if lastPort == nil {
                self.database.tableAPPCONFIGInsertItem(key: "port", value: port!)
                self.database.tableNETWORKFLOWLOGUpdateItem(key: "localPort", value: port!)
            }else if lastPort == port{
                // do nothing
            }else {
                self.database.tableAPPCONFIGUpdateItem(key: "port", value: port!)
                self.database.tableNETWORKFLOWLOGUpdateItem(key: "localPort", value: port!)
            }
            
            // Start reading messages from the tunnel connection.
            //readNextPacket()
            
            // Let the delegate know that the tunnel is open
            delegate?.tunnelDidOpen(self)
            
        case .disconnected:
            closeTunnelWithError(connection!.error as NSError?)
            
        case .cancelled:
            connection!.removeObserver(self, forKeyPath:"state", context:&connection)
            connection = nil
            delegate?.tunnelDidClose(self)
            
        default:
            break
        }
    }
    
    // MARK: Tunnel
    
    /// Close the tunnel.
    override open func closeTunnel() {
        testVPNLog(self.TAG + "closing tunnel")
        super.closeTunnel()
        // Close the tunnel connection.
        if let TCPConnection = connection {
            TCPConnection.cancel()
        }
        
    }
    
    /// Write data to the tunnel connection.
    override func writeDataToTunnel(_ data: Data, startingAtOffset: Int) -> Int {
        testVPNLog(self.TAG + "write data to tunnel")
        connection?.write(data) { error in
            if error != nil {
                self.closeTunnelWithError(error as NSError?)
            }
        }
        return data.count
    }
    
    /// Handle a message received from the tunnel server.
    override func handleMessage(_ commandType: TunnelCommand, properties: [String: AnyObject], connection: Connection?) -> Bool {
        testVPNLog(self.TAG + "handle message received from the tunnel server, commandType: \(commandType), properties: \(properties)")
        var success = true
        
        switch commandType {
        case .openResult:
            // A logical connection was opened successfully.
            guard let targetConnection = connection,
                let resultCodeNumber = properties[TunnelMessageKey.ResultCode.rawValue] as? Int,
                let resultCode = TunnelConnectionOpenResult(rawValue: resultCodeNumber)
                else
            {
                success = false
                break
            }
            
            targetConnection.handleOpenCompleted(resultCode, properties:properties as [NSObject : AnyObject])
            
        case .fetchConfiguration:
            guard let configuration = properties[TunnelMessageKey.Configuration.rawValue] as? [String: AnyObject]
                else { break }
            
            delegate?.tunnelDidSendConfiguration(self, configuration: configuration)
            
        default:
            testVPNLog("Tunnel received an invalid command")
            success = false
        }
        return success
    }
    
    /// Send a FetchConfiguration message on the tunnel connection.
    open func sendFetchConfiguation() {
        testVPNLog(self.TAG + "send fetch configuration")
        let properties = createMessagePropertiesForConnection(0, commandType: .fetchConfiguration)
        if !sendMessage(properties) {
            testVPNLog("Failed to send a fetch configuration message")
        }
    }
}
