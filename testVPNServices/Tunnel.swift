//
//  Tunnel.swift
//  testVPNServices
//
//  Created by Joe Liu on 2018/8/22.
//  Copyright © 2018年 NUDT. All rights reserved.
//
//  Tunnel 类是ClientTunnel 类的抽象基类，服务器与客户端之间的SimpleTunnel协议下的通讯都是承载于ClientTunnel 类之上进行的。
//

import Foundation

// </ Command Types in the SimpleTunnel Protocol
public enum TunnelCommand: Int, CustomStringConvertible {
    case data = 1
    case suspend = 2
    case resume = 3
    case close = 4
    case dns = 5
    case open = 6
    case openResult = 7
    case packets = 8
    case fetchConfiguration = 9
    
    public var description: String{
        switch self {
        case .data: return "Data"
        case .suspend: return "Suspend"
        case .close: return "Close"
        case .dns: return "DNS"
        case .open: return "Open"
        case .resume: return "Resume"
        case .openResult: return "OpenResult"
        case .fetchConfiguration: return "FetchConfiguration"
        case .packets: return "Packets"
        }
    }
}
// Command Types in the SimpleTunnel Protocol />

// </ Keys in SimpleTunnel message dictionaries
public enum TunnelMessageKey: String{
    case Identifier = "identifier"
    case Command = "command"
    case Data = "data"
    case CloseDirection = "close-type"
    case DNSPacket = "dns-packet"
    case DNSPacketSource = "dns-packet-source"
    case ResultCode = "result-code"
    case TunnelType = "tunnel-type"
    case Host = "host"
    case Port = "port"
    case Configuration = "configuration"
    case Packets = "packets"
    case Protocols = "protocols"
    case AppProxyFlowType = "app-proxy-flow-type"
}
// Keys in SimpleTunnel message dictionaries />

// </ The Layer at which this tunnel tunnels traffic
public enum TunnelLayer: Int{
    case app = 0
    case ip = 1
}
// The Layer at which this tunnel tunnels traffic />

// </ For app layer tunnel, the type of socket being tunneled
public enum AppProxyFlowKind: Int{
    case tcp = 1
    case udp = 3
}
// For app layer tunnel, the type of socket being tunneled />

// </ The tunnel Delegate Protocol
public protocol TunnelDelegate: class {
    func tunnelDidOpen(_ targetTunnel: Tunnel)
    func tunnelDidClose(_ targetTunnel: Tunnel)
    func tunnelDidSendConfiguration(_ targetTunnel: Tunnel, configuration: [String: AnyObject])
}
// The tunnel Delegate Protocol />

// </ The base class that implements common behavior and data structure for both Client side and Server side of SimpleTunnel Protocol
open class Tunnel: NSObject {
    // MARK: Properties
    
    private let TAG = "Tunnel: "
    
    // Tunnel Delegate
    open weak var delegate: TunnelDelegate?
    
    // Current set of logical connections open with the tunnel
    var connections = [Int: Connection]()
    
    // The lists of data that needs to be written to the tunnel when possible
    let savedData = SavedData()
    
    // The SimpleTunnel Boujour service type
    class var serviceType: String { return "_tunnelserver._tcp" }
    
    // The SimpleTunnel Boujour service domain
    class var serviceDomain: String { return "local" }
    
    // The maximum SimpleTunnel message size
    class var maximumMessageSize: Int {return 128 * 1024 }
    
    // The maximum size of a single tunneled IP packet.
    class var packetSize: Int { return 8192 }
    
    // The maximum number of IP packets in a single SimpleTunnel data message.
    class var maximumPacketsPerMessage: Int { return 32 }
    
    // A list of all tunnels
    static var allTunnels = [Tunnel]()
    
    // MARK: Initializers
    
    override public init() {
        testVPNLog(self.TAG + "initializing tunnel")
        super.init()
        Tunnel.allTunnels.append(self)
    }
    
    // MARK: Interface
    
    // Close the tunnel
    func closeTunnel(){
        testVPNLog(self.TAG + "closing tunnel")
        for connection in connections.values {
            connection.tunnel = nil
            connection.abort()
        }
        connections.removeAll(keepingCapacity: false)
        
        savedData.clear()
        
        if let index = Tunnel.allTunnels.index(where: { return $0 === self }) {
            Tunnel.allTunnels.remove(at: index)
        }
    }
    
    // Add a connection to the set
    func addConnection(_ connection: Connection){
        testVPNLog(self.TAG + "adding connection")
        connections[connection.identifier] = connection
        /*var counter = 0
        for t in Tunnel.allTunnels{
            testVPNLog(self.TAG + "Tunnel: \(counter)")
            counter += 1
            for c in t.connections{
                testVPNLog(self.TAG + "connection: \(c.value.identifier)")
            }
        }*/
    }
    
    // Remove a connection from the set
    func dropConnection(_ connection: Connection){
        testVPNLog(self.TAG + "droping connection")
        connections.removeValue(forKey: connection.identifier)
    }
    
    // Close all open tunnels
    class func closeAll() {
        for tunnel in Tunnel.allTunnels{
            tunnel.closeTunnel()
        }
        Tunnel.allTunnels.removeAll(keepingCapacity: false)
    }
    
    // Write some data (i.e., a serialized message) to the tunnel.
    func writeDataToTunnel(_ data: Data, startingAtOffset: Int) -> Int {
        testVPNLog(self.TAG + "data to be written: \(data)")
        testVPNLog(self.TAG + "write data to tunnel")
        return -1
    }
    
    // Serialize a message
    func serializeMessage(_ messageProperties: [String: AnyObject]) -> Data? {
        testVPNLog(self.TAG + "serialize message")
        var messageData: NSMutableData?
        do {
            /*
             * Message format:
             *
             *  0 1 2 3 4 ... Length
             * +-------+------------+
             * |Length | Payload    |
             * +-------+------------+
             *
             */
            let payload = try PropertyListSerialization.data(fromPropertyList: messageProperties, format: .binary, options: 0)
            var totalLength: UInt32 = UInt32(payload.count + MemoryLayout<UInt32>.size)
            messageData = NSMutableData(capacity: Int(totalLength))
            messageData?.append(&totalLength, length: MemoryLayout<UInt32>.size)
            messageData?.append(payload)
            testVPNLog(self.TAG + "serialized message content(\(messageData?.length)): \(messageData)")
        }
        catch {
            testVPNLog("<AINASSINE> testVPN Tunnel.swift: " + "Failed to create a data object from a message property list: \(messageProperties)")
        }
        return messageData as Data?
    }
    
    // Send a message on the tunnel connection
    func sendMessage(_ messageProperties: [String: AnyObject]) -> Bool{
        testVPNLog(self.TAG + "send message: \(messageProperties)")
        var written: Int = 0
        
        guard let messageData = serializeMessage(messageProperties) else{
            return false
        }
        
        if savedData.isEmpty {
            // There is nothing queued up to be sent, to directly write to the tunnel.
            written = writeDataToTunnel(messageData, startingAtOffset: 0)
            if written < 0{
                closeTunnel()
            }
        }
        
        // If not all of the data was written, save the message data to be sent when possible
        if written < messageData.count {
            savedData.append(messageData, offset: written)
            
            // Suspend all connection until the saved data can be written
            for connectin in connections.values {
                connectin.suspend()
            }
        }
        
        return true
    }
    
    // Send a Data message on the tunnel connection
    func sendData(_ data: Data, forConnection connectionIdentifier: Int) {
        testVPNLog(self.TAG + "send a data message on connection \(connectionIdentifier)")
        let properties = createMessagePropertiesForConnection(connectionIdentifier, commandType: .data, extraProperties: [TunnelMessageKey.Data.rawValue: data as AnyObject])
        
        if !sendMessage(properties) {
            testVPNLog("<AINASSINE> testVPN Tunnel.swift: " + "Failed to send a data message for connection \(connectionIdentifier)")
        }
    }
    
    // Send a Data message with an associated endpoint
    func sendDataWithEndPoint(_ data: Data, forConnection connectionIdentifier: Int, host: String, port: Int){
        testVPNLog(self.TAG + "send data with endpoint")
        let properties = createMessagePropertiesForConnection(connectionIdentifier, commandType: .data, extraProperties: [
            TunnelMessageKey.Data.rawValue: data as AnyObject,
            TunnelMessageKey.Host.rawValue: host as AnyObject,
            TunnelMessageKey.Port.rawValue: port as AnyObject
            ])
        
        if !sendMessage(properties){
            testVPNLog("<AINASSINE> testVPN Tunnel.swift: " + "Failed to send a data message for connection \(connectionIdentifier)")
        }
    }
    
    // Send a Suspend message on the tunnel connection
    func sendSuspendForConnection(_ connectionIdentifier: Int) {
        testVPNLog(self.TAG + "send suspend for connection")
        let properties = createMessagePropertiesForConnection(connectionIdentifier, commandType: .suspend)
        if !sendMessage(properties){
            testVPNLog("<AINASSINE> testVPN Tunnel.swift: " + "Failed to send a suspend message for connection \(connectionIdentifier)")
        }
    }
    
    // Send a Resume message on the tunnel connection
    func sendResumeForConnection(_ connectionIdentifier: Int) {
        testVPNLog(self.TAG + "send resume for connection")
        let properties = createMessagePropertiesForConnection(connectionIdentifier, commandType: .resume)
        if !sendMessage(properties){
            testVPNLog("<AINASSINE> testVPN Tunnel.swift: " + "Failed to send a resume message for connection \(connectionIdentifier)")
        }
    }
    
    // Send a Close message on the tunnel connection
    open func sendCloseType(_ type: TunnelConnectionCloseDirection, forConnection connectionIdentifier: Int) {
        testVPNLog(self.TAG + "send close type")
        let properties = createMessagePropertiesForConnection(connectionIdentifier, commandType: .close, extraProperties: [TunnelMessageKey.CloseDirection.rawValue: type.rawValue as AnyObject])
        if !sendMessage(properties){
            testVPNLog("<AINASSINE> testVPN Tunnel.swift: " + "Failed to send a close message for connection \(connectionIdentifier)")
        }
    }
    
    // Send a Packets message on the tunnel connection
    func sendPackets(_ packets: [Data], protocols: [NSNumber], forConnection connectionIdentifier: Int) {
        testVPNLog(self.TAG + "send packets")
        let properties = createMessagePropertiesForConnection(connectionIdentifier, commandType: .packets, extraProperties: [
            TunnelMessageKey.Packets.rawValue: packets as AnyObject,
            TunnelMessageKey.Protocols.rawValue: protocols as AnyObject
            ])
        
        if !sendMessage(properties) {
            testVPNLog("<AINASSINE> testVPN Tunnel.swift: " + "Failed to send a packets message for connection \(connectionIdentifier)")
        }
    }
    
    // Process a message payload
    func handlePacket(_ packetData: Data) -> Bool {
        // this is for debug, should be deleted when publishing
        let tmpMutableData = NSMutableData()
        tmpMutableData.append(packetData)
        testVPNLog(self.TAG + "handle packet, process a message payload. content(\(tmpMutableData.length)): \(tmpMutableData)")
        let properties: [String: AnyObject]
        do {
            properties = try PropertyListSerialization.propertyList(from: packetData, options: PropertyListSerialization.MutabilityOptions(), format: nil) as! [String: AnyObject]
            testVPNLog(self.TAG + "properties received: \(properties)")
        }
        catch {
            testVPNLog("<AINASSINE> testVPN Tunnel.swift: " + "Failed to create the message properties from the packet")
            return false
        }
        
        guard let command = properties[TunnelMessageKey.Command.rawValue] as? Int else{
            testVPNLog("<AINASSINE> testVPN Tunnel.swift: " + "Message command type is missing")
            return false
        }
        guard let commandType = TunnelCommand(rawValue: command) else{
            testVPNLog("<AINASSINE> testVPN Tunnel.swift: " + "Message command type \(command) is invalid")
            return false
        }
        var connection: Connection?
        
        if let connectionIdentifierNumber = properties[TunnelMessageKey.Identifier.rawValue] as? Int, commandType != .open && commandType != .dns {
            connection = connections[connectionIdentifierNumber]
        }
        
        guard let targetConnection = connection else {
            return handleMessage(commandType, properties: properties, connection: connection)
        }
        
        switch commandType {
        case .data:
            guard let data = properties[TunnelMessageKey.Data.rawValue] as? Data else {break}
            /* check if the message has properties for host and port */
            if let host = properties[TunnelMessageKey.Host.rawValue] as? String, let port = properties[TunnelMessageKey.Port.rawValue] as? Int {
                testVPNLog(self.TAG + "Received data for connection \(connection?.identifier) from \(host):\(port)")
                /* UDP case: send peer's address along with data */
                targetConnection.sendDataWithEndPoint(data, host: host, port: port)
            }
            else{
                testVPNLog(self.TAG + "no host specified, sending data on connection \(targetConnection.identifier)")
                targetConnection.sendData(data)
            }
        case .suspend:
            targetConnection.suspend()
        case .resume:
            targetConnection.resume()
        case .close:
            if let closeDirectionNumber = properties[TunnelMessageKey.CloseDirection.rawValue] as? Int, let closeDirection = TunnelConnectionCloseDirection(rawValue: closeDirectionNumber){
                targetConnection.closeConnection(closeDirection)
            }else{
                targetConnection.closeConnection(.all)
            }
        case .packets:
            if let packets = properties[TunnelMessageKey.Packets.rawValue] as? [Data], let protocols = properties[TunnelMessageKey.Protocols.rawValue] as? [NSNumber], packets.count == protocols.count {
                targetConnection.sendPackets(packets, protocols: protocols)
            }
        default:
            return handleMessage(commandType, properties: properties, connection: connection)
        }
        
        return true
    }
    
    // handle the received message
    func handleMessage(_ command: TunnelCommand, properties: [String: AnyObject], connection: Connection?) -> Bool {
        testVPNLog(self.TAG + "handle the received message. command: \(command), properties: \(properties) ")
        return false
    }
}
















