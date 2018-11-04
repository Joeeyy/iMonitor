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
import CocoaAsyncSocket

// A NEAppProxyProvider sub-class that implements the client side of the SimpleTunnel tunneling protocol.
class AppProxyProvider: NEAppProxyProvider, TunnelDelegate, GCDAsyncSocketDelegate, GCDAsyncUdpSocketDelegate {
    
    // MARK: Properties
    
    // A reference to the tunnel object
    var tunnel: ClientTunnel?
    
    /// The completion handler to call when the tunnel is fully established.
    var pendingStartCompletion: ((NSError?) -> Void)?
    
    /// The completion handler to call when the tunnel is fully disconnected.
    var pendingStopCompletion: ((Void) -> Void)?
    
    // MARK: NEAppProxyProvider
    let TAG = "AppProxyProvider: "
    
    var flows = [GCDAsyncSocket:NEAppProxyFlow]()
    var udpSocks = [GCDAsyncSocket: GCDAsyncUdpSocket]()
    var udpflows = [GCDAsyncUdpSocket: NEAppProxyFlow]()

    // begin the process of establishing the tunnel
    override func startProxy(options: [String : Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        testVPNLog(self.TAG + "starting PER_APP_PROXY tunnel")
        let newTunnel = ClientTunnel()
        newTunnel.delegate = self
        
        if let error = newTunnel.startTunnel(self) {
            completionHandler(error as NSError)
            testVPNLog(self.TAG + "start new Tunnel failed.")
            return
        }
        testVPNLog(self.TAG+"PER_APP_PROXY started successfully!")
        pendingStartCompletion = completionHandler
        tunnel = newTunnel
    }
    
    // begin the process of stop the proxy
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        // Clear out any pending start completion handler.
        testVPNLog(self.TAG + "Stopping PER_APP_VPN.")
        pendingStartCompletion = nil
        
        pendingStopCompletion = completionHandler
        tunnel?.closeTunnel()
        testVPNLog(self.TAG + "PER_APP_VPN stopped.")
    }
    
    // Handle a new flow of network data created by an application
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        // Add code here to handle the incoming flow.
        testVPNLog(self.TAG+"A new PER_APP_PROXY_FLOW comes, start handling it.")
        var newConnection: ClientAppProxyConnection?
        var conn: Conn?
        
        guard let clientTunnel = tunnel else { return false }
        
        let socket = GCDAsyncSocket()
        socket.delegate = self
        socket.delegateQueue = DispatchQueue.main
        do{
            testVPNLog("TRY TO CONNECT")
            try socket.connect(toHost: "119.23.215.159", onPort: UInt16(10808))
            //try socket.connect(toHost: "172.20.10.10", onPort: UInt16(1080))
            
        } catch let error as NSError {
            testVPNLog("Error:\(error)")
        }
        flows[socket] = flow
        testVPNLog("flows length: \(flows.count)")
        testVPNLog("sock: \(socket), flow: \(flow)")
        
        if let TCPFlow = flow as? NEAppProxyTCPFlow {
            testVPNLog(self.TAG + "it's a TCP Flow, description: \(TCPFlow.description), from app: \(TCPFlow.metaData.sourceAppSigningIdentifier).")
            //newConnection = ClientAppProxyTCPConnection(tunnel: clientTunnel, newTCPFlow: TCPFlow
        }
        else if let UDPFlow = flow as? NEAppProxyUDPFlow {
            testVPNLog(self.TAG + "it's a UDP Flow, description: \(UDPFlow.description), from app: \(UDPFlow.metaData.sourceAppSigningIdentifier).")
            //newConnection = ClientAppProxyUDPConnection(tunnel: clientTunnel, newUDPFlow: UDPFlow)
        }
        
        //guard newConnection != nil else { testVPNLog(self.TAG + "new connection established failed."); return false }
        //guard conn != nil else { testVPNLog(self.TAG + "new connection established failed."); return false }
        //newConnection!.open()
        testVPNLog(self.TAG + "new connection established.")
        
        return true
    }
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        testVPNLog("EMMM CONECTED")
        let flow = flows[sock]
        testVPNLog("sock: \(sock), flow: \(flow)")
        testVPNLog("TRY TO OPEN FLOW: \(flow)")
        if let TCPFlow = flow as? NEAppProxyTCPFlow {
            let localAddress = NWHostEndpoint(hostname: sock.localHost!, port: "\(sock.localPort)")
            flow!.open(withLocalEndpoint: localAddress){ error in
                if error != nil {
                    testVPNLog("Error open flow: \(error)")
                    return
                }
                testVPNLog("FLOW OPENED!!! Start procedure of socks5 protocol")
                sock.write(Data.init(bytes: [0x05,0x01,0x00] as [UInt8]), withTimeout: TimeInterval(-1), tag: 0)
                sock.readData(withTimeout: -1, tag: 0)
            }
        }
        else if let UDPFlow = flow as? NEAppProxyUDPFlow {
            sock.write(Data.init(bytes: [0x05,0x01,0x00] as [UInt8]), withTimeout: TimeInterval(-1), tag: 0)
            sock.readData(withTimeout: -1, tag: 0)
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        testVPNLog("EMMM WRITE")
        let flow = flows[sock]
        testVPNLog("sock: \(sock), flow: \(flow)")
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        testVPNLog("EMMM READ")
        let flow = flows[sock]
        testVPNLog("sock: \(sock), flow: \(flow)")
        testVPNLog("DATA READ: \(data) \(NSMutableData.init(data: data))")
        // if 0x05 0x00
        // go send target ip
        // request for read
        if data.elementsEqual([0x05,0x00] as [UInt8]){
            testVPNLog("GOT 0x0500 REPLY")
            if let TCPFlow = flow as? NEAppProxyTCPFlow {
                let dst = TCPFlow.remoteEndpoint as! NWHostEndpoint
                let dstIP = dst.hostname
                let dstPort = dst.port
                testVPNLog("host: \(dstIP), port: \(dstPort)")
                let VER = [0x05] as [UInt8]
                let CMD = [0x01] as [UInt8] // TCP Connect
                let RSV = [0x00] as [UInt8]
                let ATYP: [UInt8]
                let hostHex: [UInt8]
                if checkIPFormat(ip: dstIP){
                    ATYP = [0x01] as [UInt8]
                    hostHex = string2Hex(input: dstIP, mod: "ip")
                }
                else{
                    ATYP = [0x03] as [UInt8]
                    let lengthHex = [UInt8(dstIP.count)]
                    hostHex = lengthHex + Array(dstIP.utf8) as [UInt8]
                }
                let portHex = string2Hex(input: dstPort, mod: "port")
                var payload = [UInt8]()
                payload += VER
                payload += CMD
                payload += RSV
                payload += ATYP
                payload += hostHex
                payload += portHex
                testVPNLog("\(NSMutableData.init(data: Data.init(bytes: payload)))")
                
                sock.write(Data.init(bytes: payload), withTimeout: TimeInterval(-1), tag: 0)
                sock.readData(withTimeout: 60, tag: 0)
            }
            else if let UDPFlow = flow as? NEAppProxyUDPFlow {
                //let dst = TCPFlow.remoteEndpoint as! NWHostEndpoint
                //let dstIP =
                //let dstPort = dst.port
                //testVPNLog("host: \(dstIP), port: \(dstPort)")
                
                // open up a udp socket
                testVPNLog("ABCD EFG try to open up a udp socket.")
                let udpsock = GCDAsyncUdpSocket()
                udpsock.setDelegate(self)
                udpsock.setDelegateQueue(DispatchQueue.main)
                do {
                    testVPNLog("ABCD EFG - \(sock.localHost!)")
                    var sa = sockaddr_in()
                    sa.sin_len = UInt8(MemoryLayout.size(ofValue: sa))
                    sa.sin_family = sa_family_t(AF_INET)
                    sa.sin_addr.s_addr = inet_addr(sock.localHost!)
                    //sa.sin_port.
                    try udpsock.bind(toAddress: NSData.init(bytes: &sa, length: MemoryLayout<sockaddr_in>.size) as Data)
                    testVPNLog("ABCD EFG udp socket opened")
                }
                catch let error as NSError {
                    testVPNLog("ABCD EFG \(error)\n\(NSMutableData.init(data: Data.init(bytes: string2Hex(input: sock.localHost!, mod: "ip"))))")
                    return
                }
                
                testVPNLog("ABCD EFG + \(udpsock.localHost()!)" )
                testVPNLog("ABCD EFG \(udpsock.localPort())")
                //udpsock.bind
                
                let VER = [0x05] as [UInt8]
                let CMD = [0x03] as [UInt8] // UDP Associate
                let RSV = [0x00] as [UInt8]
                let ATYP = [0x01] as [UInt8]
                let hostHex = [0x00,0x00,0x00,0x00] as [UInt8]
                let portHex = string2Hex(input: String(udpsock.localPort()), mod: "port")
                var payload = [UInt8]()
                payload += VER
                payload += CMD
                payload += RSV
                payload += ATYP
                payload += hostHex
                payload += portHex
                testVPNLog("\(NSMutableData.init(data: Data.init(bytes: payload)))")
                udpSocks[sock] = udpsock
                udpflows[udpsock] = flow
                
                sock.write(Data.init(bytes: payload), withTimeout: TimeInterval(-1), tag: 0)
                sock.readData(withTimeout: -1, tag: 0)
            }
        }else if data.count == 10 {
            testVPNLog("ABCD REPLY GOT MAYBE: \(NSMutableData.init(data: data))")
            //testVPNLog("TRANSFER DATA: \(NSMutableData.init(data: ))")
            if let TCPFlow = flow as? NEAppProxyTCPFlow {
                testVPNLog("ABCD read data from tcpflow: \(TCPFlow)")
                TCPFlow.readData { data, error in
                    guard let readData = data , error == nil else {
                        testVPNLog("ABCD Failed to read data from the TCP flow. error = \(error)")
                        return
                    }
                    guard readData.count > 0 else{
                        testVPNLog(" received EOF on the TCP flow. Closing the flow...")
                        TCPFlow.closeReadWithError(nil)
                        return
                    }
                    testVPNLog("ABCD Data has been read from TCPFlow: \(TCPFlow), TRANSFER DATA: \(NSMutableData.init(data: readData))")
                    sock.write(data!, withTimeout: TimeInterval(-1), tag: 0)
                    sock.readData(withTimeout: TimeInterval(60), tag: 0)
                }
            }
            else if let UDPFlow = flow as? NEAppProxyUDPFlow {
                testVPNLog("ABCD set updsock for udpflow: \(UDPFlow)")
                
                let udpsock = udpSocks[sock]
                // parse udp reply
                testVPNLog("ABCD EFG udp reply: \(NSMutableData.init(data: data))")
                // 0x05 0x00 0x00 0x01 0x-- 0x-- 0x-- 0x-- 0x++ 0x++
                //let ipString = "\(data[4]).\(data[5]).\(data[6]).\(data[7])"
                let ipString = "119.23.215.159"
                let port: UInt16 = UInt16(data[8])*256 + UInt16(data[9])
                do{
                    try udpsock?.connect(toHost: ipString, onPort: port)
                    testVPNLog("ABCD EFG connect to upd sock: \(ipString):\(port) Succeeded!")
                }
                catch let error as NSError{
                    testVPNLog("ABCD EFG connect to upd sock: \(ipString):\(port) FAILED!")
                }
                sock.readData(withTimeout: TimeInterval(-1), tag: 0)
            }
        }
        else{
            // got data replied
            testVPNLog("ABCD GOT DATA REPLIED, WRITE IT TO APP.")
            if let TCPFlow = flow as? NEAppProxyTCPFlow {
                TCPFlow.write(data) { error in
                    if error != nil {
                        testVPNLog("ABCD \(TCPFlow) Error when write back to app: \(error)\n\(sock.isConnected)")
                        TCPFlow.closeWriteWithError(nil)
                    }
                    else{
                        testVPNLog("ABCD \(TCPFlow) Has write data \(data) back.")
                    }
                    sock.readData(withTimeout: TimeInterval(60), tag: 0)
                }
            }
            else if let UDPFlow = flow as? NEAppProxyUDPFlow {
                testVPNLog("ABCD EFG UDP REPLY: \(NSMutableData.init(data: data))")
            }
            
        }
        
        // if got 10 bytes reply
        // got send data
        // listen for reply
        
        // if received stop command, close the socket
    }
    
    /// MARK: UDP Socket Delegate
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) {
        testVPNLog("ABCD EFG - did send data with tag: \(tag)")
    }
    
    func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?) {
        testVPNLog("ABCD EFG - Socket did closed.")
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?) {
        
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
        var addr:sockaddr_in = sockaddr_in()
        NSData.init(data: address).getBytes(&addr, length: MemoryLayout<sockaddr>.size)
        let tmpPort = in_port_t(bigEndian: addr.sin_port)
        let tmpAddr = in_addr_t(bigEndian: addr.sin_addr.s_addr)
        testVPNLog("ABCD EFG - did connect to address: \(tmpAddr>>24&0xff).\(tmpAddr>>16&0xff).\(tmpAddr>>8&0xff).\(tmpAddr>>0&0xff):\(tmpPort)")
        testVPNLog("ABCD EFG - Did connect to address: \(NSMutableData.init(data: address))")
        testVPNLog("\(sock.localHost()),\(sock.localPort())")
        let flow = udpflows[sock]
        let localAddress = NWHostEndpoint(hostname: sock.localHost()!, port: "\(sock.localPort())")
        flow!.open(withLocalEndpoint: localAddress){ error in
            if error != nil {
                testVPNLog("ABCD EFG - Error open flow: \(error)")
                return
            }
            testVPNLog("ABCD EFG - FLOW OPENED!!! Start procedure of socks5 protocol")
            //sock.write(Data.init(bytes: [0x05,0x01,0x00] as [UInt8]), withTimeout: TimeInterval(-1), tag: 0)
            //sock.readData(withTimeout: -1, tag: 0)
        }
        
        guard let UDPFlow = flow as? NEAppProxyUDPFlow else {
            testVPNLog("ABBCD EFG - cast flow to udp flow failed.")
            return
        }
        
        UDPFlow.readDatagrams { datagrams, remoteEndPoints, readError in
            testVPNLog("ABBCD EFG - Read from udp flow.")
            guard let readDatagrams = datagrams,
                let readEndpoints = remoteEndPoints
                , readError == nil else
            {
                testVPNLog("ABCD EFG - Failed to read data from the UDP flow. error = \(readError)")
                return
            }
            
            testVPNLog("ABCD EFG - \(UDPFlow)")
            testVPNLog("ABCD EFG - \(sock.localPort())")
            testVPNLog("ABCD EFG - \(readDatagrams.isEmpty)")
            testVPNLog("ABCD EFG - \(readEndpoints, readDatagrams.count)")
            
            guard !readDatagrams.isEmpty && readEndpoints.count == readDatagrams.count else {
                testVPNLog("ABCD EFG - \(sock): Received EOF on the UDP flow. Close the flow from read direction...")
                UDPFlow.closeReadWithError(nil)
                return
            }
            
            for (index, datagram) in readDatagrams.enumerated() {
                guard let endpoint = readEndpoints[index] as? NWHostEndpoint else { continue }
                
                testVPNLog("ABCD EFG - \(sock): Sending a \(datagram.count)-byte datagram to \(endpoint.hostname):\(endpoint.port)")
                
                let rsvHex = [0x00,0x00] as [UInt8]
                let FRAG = [0x00] as [UInt8]
                let ATYP: [UInt8]
                let hostHex: [UInt8]
                if self.checkIPFormat(ip: endpoint.hostname) {
                    ATYP = [0x01] as [UInt8]
                    hostHex = self.string2Hex(input: endpoint.hostname, mod: "ip")
                }else{
                    // domain name
                    // may never used
                    ATYP = [0x03] as [UInt8]
                    let lengthHex = [UInt8(endpoint.hostname.count)]
                    hostHex = lengthHex + Array(endpoint.hostname.utf8) as [UInt8]
                    
                }
                
                let portHex = self.string2Hex(input: endpoint.port, mod: "port")
                let data = [UInt8](datagram)
                var payload = [UInt8]()
                payload += rsvHex
                payload += FRAG
                payload += ATYP
                payload += hostHex
                payload += portHex
                payload += data
                //payload +=
                //udpsock.write(Data.init(bytes: payload), withTimeout: TimeInterval(-1), tag: 0)
                sock.send(Data.init(bytes: payload), withTimeout: TimeInterval(-1), tag: 0)
                
                testVPNLog(self.TAG + "[Send Data To SERVER] time: \(getTime()), length: \(datagram.count), from app: \(UDPFlow.metaData.sourceAppSigningIdentifier), to: \(endpoint)")
                //self.database.tableNETWORKFLOWLOGInsertItem(srcIP: ((self.UDPFlow.localEndpoint as? NWHostEndpoint)?.hostname)!, srcPort: ((self.UDPFlow.localEndpoint as? NWHostEndpoint)?.port)!, dstIP: endpoint.hostname, dstPort: endpoint.port, length: datagram.count, proto: "UDP", time: getTime(), app: self.UDPFlow.metaData.sourceAppSigningIdentifier, direction: "out")
                //self.database.queryTableNETWORKFLOWLOG()
            }
            
            //sock.
            
            do {
                testVPNLog("ABCD EFG - try to start receiving for udp socket.")
                let res = try sock.beginReceiving()
                testVPNLog("ABCD EFG - start receiving for udp socket result: \(res)")
            }
            catch let error as NSError {
                testVPNLog("ABCD EFG - start receiving for udp socket failed: \(error)")
            }
        }
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) {
        testVPNLog("ABCD EFG - Did not send data with tag: \(tag) due to error: \(error)")
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        testVPNLog("ABCD EFG - received udp data!! data: \(NSMutableData.init(data: data))")
        guard let flow = udpflows[sock] as? NEAppProxyUDPFlow else{
            testVPNLog("cast flow to NEAppProxyUDPFlow failed.")
            return
        }
        
        testVPNLog("ABCD EFG filterContext: \(filterContext)")
        let header = data[0...9]
        let udpIPHex = header[4...7]
        let udpPortHex = header[8...9]
        let udpIP = "\(udpIPHex[4]).\(udpIPHex[5]).\(udpIPHex[6]).\(udpIPHex[7])"
        let udpPort = UInt32(udpPortHex[8])*256+UInt32(udpPortHex[9])
        let datagram = data[10...]
        testVPNLog("ABCD EFG header: \(NSMutableData.init(data: header)),ip: \(udpIP), port: \(udpPort)")
        testVPNLog("ABCD EFG datagram: \(NSMutableData.init(data: datagram))")
        var addr:sockaddr_in = sockaddr_in()
        NSData.init(data: address).getBytes(&addr, length: MemoryLayout<sockaddr>.size)
        let tmpPort = in_port_t(bigEndian: addr.sin_port)
        let tmpAddr = in_addr_t(bigEndian: addr.sin_addr.s_addr)
        testVPNLog("ABCD EFG address: \(tmpAddr>>24&0xff).\(tmpAddr>>16&0xff).\(tmpAddr>>8&0xff).\(tmpAddr>>0&0xff):\(tmpPort)")
        testVPNLog("ABCD EFG ADDRESS: \( NSMutableData.init(data: address) )")
        let endpoint = NWHostEndpoint(hostname: udpIP, port: "\(udpPort)")
        
        flow.writeDatagrams([datagram], sentBy: [endpoint]) { error in
            if error != nil {
                testVPNLog("Failed to write datagram(s) to the UDP flow: \(error)")
                sock.close()
                flow.closeWriteWithError(nil)
            }
            testVPNLog("ABCD EFG - write UDP Datagrams back to app succeeded!")
        }
        
        /*
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
         
         //let currentIP = self.database.tableAPPCONFIGQueryItem(key: "ip")
         //var currentPort = self.database.tableAPPCONFIGQueryItem(key: "port")
         //if currentPort == nil{
         //    currentPort = "localPort"
         //}
         testVPNLog(self.TAG + "[Send Back To APP] time: \(getTime()), length: \(data.count), to app: \(UDPFlow.metaData.sourceAppSigningIdentifier), from: \(host):\(port)")
         self.database.tableNETWORKFLOWLOGInsertItem(srcIP: host, srcPort: String(port), dstIP: ((UDPFlow.localEndpoint as? NWHostEndpoint)?.hostname)!, dstPort: ((UDPFlow.localEndpoint as? NWHostEndpoint)?.port)!, length: data.count, proto: "UDP", time: getTime(), app: self.UDPFlow.metaData.sourceAppSigningIdentifier, direction: "in")
         self.database.queryTableNETWORKFLOWLOG()
        */
        
    }
    
    
    /// MARK: Utils
    
    open func checkIPFormat(ip: String) -> Bool{
        let ipAddrPattern = "^(1\\d{2}|2[0-4]\\d|25[0-5]|[1-9]\\d|[1-9])\\.(1\\d{2}|2[0-4]\\d|25[0-5]|[1-9]\\d|\\d)\\.(1\\d{2}|2[0-4]\\d|25[0-5]|[1-9]\\d|\\d)\\.(1\\d{2}|2[0-4]\\d|25[0-5]|[1-9]\\d|\\d)$"
        let matcher = myRegex(ipAddrPattern)
        let testAddr = ip
        if matcher.match(input: testAddr){
            return true
        }
        
        return false
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
            result.append(UInt8((portNum!>>8)&0xff))
            result.append((UInt8(portNum!&0xff)))
            
        default:
            return result
        }
        return result
    }
    
    // MARK: Tunnel Delegate
    
    /// Handle the event of the tunnel being fully established.
    func tunnelDidOpen(_ targetTunnel: Tunnel) {
        guard let clientTunnel = targetTunnel as? ClientTunnel else {
            pendingStartCompletion?(SimpleTunnelError.internalError as NSError)
            pendingStartCompletion = nil
            return
        }
        testVPNLog(self.TAG + "Tunnel opened, fetching configuration")
        //clientTunnel.sendFetchConfiguation()
        self.tunnelDidSendConfiguration(clientTunnel, configuration: [:])
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
        testVPNLog(self.TAG + "Tunnel closed.")
        tunnel = nil
    }
    
    /// Handle the server sending a configuration.
    func tunnelDidSendConfiguration(_ targetTunnel: Tunnel, configuration: [String : AnyObject]) {
        testVPNLog(self.TAG + "Server sent configuration: \(configuration)")
        
        
        //        testVPNLog(self.TAG + "creating tunnel settings from configuration" )
        //        guard let tunnelAddress = tunnel?.remoteHost
        //            //let address = getValueFromPlist(configuration, keyArray: [.IPv4, .Address]) as? String,
        //            //let netmask = getValueFromPlist(configuration, keyArray: [.IPv4, .Address]) as? String
        //            else {return nil}
        //        let address = "10.1.1.2"
        //        let netmask = "255.255.255.255"
        //
        //        let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: tunnelAddress)
        //        var fullTunnel = true
        //
        //        newSettings.iPv4Settings = NEIPv4Settings(addresses: [address], subnetMasks: [netmask])
        //
        //        /*
        //         if let routes = getValueFromPlist(configuration, keyArray: [.IPv4, .Routes]) as? [[String: AnyObject]] {
        //         var includedRoutes = [NEIPv4Route]()
        //
        //         for route in routes {
        //         if let netAddress = route[SettingsKey.Address.rawValue] as? String,
        //         let netMask = route[SettingsKey.Address.rawValue] as? String{
        //         includedRoutes.append(NEIPv4Route(destinationAddress: netAddress, subnetMask: netMask))
        //         }
        //         }
        //
        //         newSettings.iPv4Settings?.includedRoutes = includedRoutes
        //         fullTunnel = false
        //         }
        //         else{
        //         // No route specified, use the default route
        //         newSettings.iPv4Settings?.includedRoutes = [NEIPv4Route.default()]
        //         }*/
        //        var includedRoutes = [NEIPv4Route]()
        //        includedRoutes.append(NEIPv4Route(destinationAddress: "192.168.1.0", subnetMask: "255.255.255.0"))
        //        newSettings.iPv4Settings?.includedRoutes = includedRoutes
        //        fullTunnel = false
        //
        //        /*
        //         if let DNSDictionary = configuration[SettingsKey.DNS.rawValue as NSString] as? [String: AnyObject],
        //         let DNSServers = DNSDictionary[SettingsKey.Servers.rawValue] as? [String]
        //         {
        //         newSettings.dnsSettings = NEDNSSettings(servers: DNSServers)
        //         if let DNSSearchDomains = DNSDictionary[SettingsKey.SearchDomains.rawValue] as? [String] {
        //         newSettings.dnsSettings?.searchDomains = DNSSearchDomains
        //         if !fullTunnel {
        //         newSettings.dnsSettings?.matchDomains = DNSSearchDomains
        //         }
        //         }
        //         }*/
        //        let DNSServers = ["202.102.154.3","202.102.152.3"]
        //        newSettings.dnsSettings = NEDNSSettings(servers: DNSServers)
        //        let DNSSearchDomains = ["DHCP","HOST"]
        //        newSettings.dnsSettings?.searchDomains = DNSSearchDomains
        //        if !fullTunnel {
        //            newSettings.dnsSettings?.matchDomains = DNSSearchDomains
        //        }
        //
        //        newSettings.tunnelOverheadBytes = 150
        //        return newSettings
        
        guard let tunnelAddress = tunnel?.remoteHost else {
            let error = SimpleTunnelError.badConnection
            pendingStartCompletion?(error as NSError)
            pendingStartCompletion = nil
            return
        }
        
        /*
         guard let DNSDictionary = configuration[SettingsKey.DNS.rawValue] as? [String: AnyObject], let DNSServers = DNSDictionary[SettingsKey.Servers.rawValue] as? [String] else {
         self.pendingStartCompletion?(nil)
         self.pendingStartCompletion = nil
         return
         }
         */
        
        let newSettings = NETunnelNetworkSettings(tunnelRemoteAddress: tunnelAddress)
        let DNSServers = ["202.102.154.3","202.102.152.3"]
        newSettings.dnsSettings = NEDNSSettings(servers: DNSServers)
        if let DNSSearchDomains = ["DHCP","HOST"] as? [String] {
            newSettings.dnsSettings?.searchDomains = DNSSearchDomains
        }
        
        testVPNLog(self.TAG + "Calling setTunnelNetworkSettings")
        
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
