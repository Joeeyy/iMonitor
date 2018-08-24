//
//  Connection.swift
//  testVPNServices
//
//  Created by Joe Liu on 2018/8/24.
//  Copyright © 2018年 NUDT. All rights reserved.
//
//  Connection类。Connection类是用于处理SimpleTunnel协议中每个数据流的抽象基类
//

import Foundation

// Directions in which a flow can be closed for further data
public enum TunnelConnectionCloseDirection: Int, CustomStringConvertible {
    case none = 1
    case read = 2
    case write = 3
    case all = 4
    
    public var description: String {
        switch self {
        case .none: return "none"
        case .read: return "reads"
        case .write: return "writes"
        case .all: return "reads and writes"
        }
    }
}

// The results of opening a connection
public enum TunnelConnectionOpenResult: Int {
    case success = 0
    case invalidParam
    case noSuchHost
    case refused
    case timeout
    case internalError
}

// a logical connection (or flow) of network data in the SimpleTunnel Protocol
open class Connection: NSObject {
    // MARK: Properties
    
    // The connection identifier
    open let identifier: Int
    
    // The tunnel that contains this connection
    open var tunnel: Tunnel?
    
    // The list of data that needs to be written to the connection when it's possible
    let saveData = SavedData()
    
    // The directions in which a connection is closed.
    var currentCloseDirection = TunnelConnectionCloseDirection.none
    
    // indicates that if the tunnel is being used by this connection exclusively
    let isExclusiveTunnel: Bool
    
    // indicates if the tunnel cannot be read from
    open var isClosedForRead: Bool {
        return currentCloseDirection != .none && currentCloseDirection != .write
    }
    
    // indicates if the tunnel cannot be written to
    open var isClosedForWrite: Bool {
        return currentCloseDirection != .none && currentCloseDirection != .read
    }
    
    // indicates if the tunnel is fully closed
    open var isClosedCompletely: Bool {
        return currentCloseDirection == .all
    }
    
    // MARK: Initializers
    public init(connectionIdentifier: Int, parentTunnel: Tunnel) {
        tunnel = parentTunnel
        identifier = connectionIdentifier
        isExclusiveTunnel = false
        super.init()
        if let t = tunnel {
            // add this tunnel to the tunnel's set of connections
            t.addConnection(self)
        }
    }
    
    public init(connectionIdentifier: Int) {
        isExclusiveTunnel = true
        identifier = connectionIdentifier
    }
    
    // MARK: Interfaces
    
    // Set a new tunnel for the connection
    func setNewTunnel(_ newTunnel: Tunnel) {
        tunnel = newTunnel
        if let t = tunnel {
            t.addConnection(self)
        }
    }
    
    // Close the connection
    open func closeConnection(_ direction: TunnelConnectionCloseDirection) {
        if direction != .none && direction != currentCloseDirection {
            currentCloseDirection = .all
        }
        else{
            currentCloseDirection = direction
        }
        
        guard let currentTunnel = tunnel, currentCloseDirection == .all else {return}
        
        if isExclusiveTunnel {
            currentTunnel.closeTunnel()
        }
        else {
            currentTunnel.dropConnection(self)
            tunnel = nil
        }
    }
    
    // Abort the connection
    open func abort(_ error: Int = 0) {
        saveData.clear()
    }
    
    // Send data on the connection
    open func sendData(_ data: Data) {
    }
    
    // Send data and destination host and port on the connection
    open func sendDataWithEndPoint(_ data: Data, host: String, port: Int) {
    }
    
    // Send a list of IP packets and their related protocols on the connection
    open func sendPackets(_ packets: [Data], protocol: [NSNumber]) {
    }
    
    // Send an indication to the remote end of the connection that the caller will not be reading any more data from the connection for a while
    open func suspend() {
    }
    
    // Send an indication to the remote end of the connection that the caller will read more data from the connection
    open func resume() {
    }
    
    // Handle the "open completed" message send by Server side of SimpleTunnel
    open func handleOpenCompleted(_ resultCode: TunnelConnectionOpenResult, properties: [NSObject: AnyObject]) {
    }
}
