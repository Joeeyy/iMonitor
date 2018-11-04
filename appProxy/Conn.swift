//
//  Conn.swift
//  appProxy
//
//  Created by Joe Liu on 2018/10/30.
//  Copyright © 2018年 NUDT. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import NetworkExtension
import testVPNServices

open class Conn: NSObject, GCDAsyncSocketDelegate {
    let flow: NEAppProxyFlow
    let ss5_ip = "119.23.215.159"
    let ss5_port = 10808
    var clientSocket: GCDAsyncSocket!
    // for socks5 protocol, client connect request
    //    +----+----------+----------+
    //    |VER | NMETHODS | METHODS  |
    //    +----+----------+----------+
    //    | 1  |    1     | 1 to 255 |
    //    +----+----------+----------+
    // 0x05, 0x01, 0x00: version: 5, nmethods: num of method, methods: 0x00, no authentication
    let connectRequest = [0x05, 0x01, 0x00] as [UInt8]
    //    +----+-----+-------+------+----------+----------+
    //    |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
    //    +----+-----+-------+------+----------+----------+
    //    | 1  |  1  |   1   |  1   | Variable |    2     |
    //    +----+-----+-------+------+----------+----------+
    // version: 5, cmd: connect, rsv: reserved, atyp: tcp, dst.addr: ip, dst.port: port
    let ipString = "119.23.215.159"
    let portString = "10808"
    let targetRequestHead = [0x05,0x01, 0x00, 0x01] as [UInt8]
    //let targetRequestIP = string2Hex(input: ipString, mod: "ip")
    //let targetRequestPort = string
    
    init(flow: NEAppProxyFlow){
        self.flow = flow
        super.init()
        clientSocket = GCDAsyncSocket()
        clientSocket.delegate = self
        clientSocket.delegateQueue = DispatchQueue.main
        creatSocketToConnectServer()
    }
    
    // 创建长连接
    func creatSocketToConnectServer() -> Void {
        do {
            //connectStatus = 0
            testVPNLog("Going to make connect")
            
            try clientSocket.connect(toHost: ss5_ip, onPort: UInt16.init(exactly: ss5_port)!)
            testVPNLog("\(clientSocket.isConnected)")
            testVPNLog("Making connect request")
            //try  clientSocket.connect(toHost: kConnectorHost, onPort: UInt16(kConnectorPort), withTimeout: TimeInterval(timeOut))
        } catch {
            print("conncet error")
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        testVPNLog("Connected.")
        clientSocket.write(Data.init(bytes: connectRequest), withTimeout: TimeInterval.init(10), tag: 10)
    }
    
    
    open func string2Hex(input: String, mod: String) -> [UInt8]{
        var result = [UInt8]()
        switch mod {
        case "ip":
            let ipSlices = input.split(separator: ".")
            result.append(UInt8(Int(ipSlices[0])!&0xff))
            result.append(UInt8(Int(ipSlices[1])!&0xff))
            result.append(UInt8(Int(ipSlices[2])!&0xff))
            result.append(UInt8(Int(ipSlices[3])!&0xff))
        case "port":
            let portNum = Int(input)
            result.append((UInt8(portNum!&0xff)))
            result.append(UInt8((portNum!>>8)&0xff))
        default:
            return result
        }
        return result
    }
    
}
