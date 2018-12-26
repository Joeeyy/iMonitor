//
//  AppProxyProvider.swift
//  appProxy
//
//  Created by Joe Liu on 2018/8/22.
//  Copyright © 2018年 NUDT. All rights reserved.
//
//  本文件包含AppProxyProvider类。AppProxyProvider是NEAppProxyProvider的子类，是NetworkExtension和SimpleTunnel隧道协议的连接点。
//  @author Ainassine @2018.10
//  基于CocoaAsyncSocket提供SOCKS5协议通信支持，抛弃原有的SimpleTunnel协议的通信过程。
//


/*
 * There's always something wrong with my UDP session support,
 * like "Unexpected nil" or directly reboot incident.
 * I thinkg there must be something wrong with my error handling,
 * I'm not sure if my closeSock() is the right thing to do for all situations,
 * maybe that's the solution to all my wired problems.
 * -- 2018.11.06 19:05
 */

import NetworkExtension
import testVPNServices
import CocoaAsyncSocket
import AdSupport
import Foundation


// Indicating data type
public enum SOCK_TAG: Int {
    case DATA = 0
    case AUTH_NEGO = 1
    case TCP_CONNECT = 2
    case UDP_ASSOCIATE = 3
    case BIND = 4
    case UNKNOWN = -1
}

// A NEAppProxyProvider sub-class that implements the client side of the SimpleTunnel tunneling protocol.
class AppProxyProvider: NEAppProxyProvider, TunnelDelegate, GCDAsyncSocketDelegate, GCDAsyncUdpSocketDelegate {
    
    
    //////////////////////
    // MARK: Properties //
    //////////////////////
    
    // A reference to the tunnel object
    var tunnel: ClientTunnel?
    
    /// The completion handler to call when the tunnel is fully established.
    var pendingStartCompletion: ((NSError?) -> Void)?
    
    /// The completion handler to call when the tunnel is fully disconnected.
    var pendingStopCompletion: ((Void) -> Void)?
    
    /// support for socks5 communication
    
    //let queue = DispatchQueue.init(label: "PerAppProxy")
    
    let idfa = ASIdentifierManager.shared()?.advertisingIdentifier
    
    var recordFlow = false
    
    // to listen to network state
    let reachability = Reachability()
    
    //var database: Database!
    var wifiConnected = false
    var currentPublicIP: String = ""
    
    // basically, for every flow, there must be a TCP connection established between this flow to SOCKS5 server tcp listener port, and we need to determine to which flow this tcp socket belongs.
    var flows = [GCDAsyncSocket:NEAppProxyFlow]()
    // This is built for UDP support. Every UDP flow should have a UDP session with SOCKS5 server, and due to SOCKS5 protocol, this UDP session is binded with a certain TCP connection. If this TCP connection corrupts, our UDP session will not be existing any more. This `udpSocks` is used when firstly establish a UDP session.
    var udpSocks = [GCDAsyncSocket: GCDAsyncUdpSocket]()
    // This is built for UDP support. We need to determine to which flow this udp socket belongs.
    var udpflows = [GCDAsyncUdpSocket: NEAppProxyUDPFlow]()
    // This is built for UDP support. It's a map from udp sock to tcp sock
    var utSocks = [GCDAsyncUdpSocket: GCDAsyncSocket]()
    // This is built for UDP support. Datagrams that need to be sent out but haven't
    var datagramsOutstanding = [GCDAsyncUdpSocket: Int]()
    var udpSocketLastUsedTime = [GCDAsyncUdpSocket: Double]()
    
    // MARK: NEAppProxyProvider
    let TAG = "AppProxyProvider: "
 
    // begin the process of establishing the tunnel
    override func startProxy(options: [String : Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        testVPNLog(self.TAG + "starting PER_APP_PROXY tunnel")
        let newTunnel = ClientTunnel()
        newTunnel.delegate = self
        //database = Database()
        
        networkStatusListener()
        //currentPublicIP = database.tableAPPCONFIGQueryItem(key: "ip")!
        
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
        
        //*********************//
        // close all the socks //
        //*********************//
        
        testVPNLog(self.TAG + "PER_APP_VPN stopped.")
    }
    
    // Handle a new flow of network data created by an application
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        let currentTimeStamp = Date().timeIntervalSince1970
        for (k,v) in self.udpSocketLastUsedTime.enumerated(){
            if currentTimeStamp - v.value >= 5{
                self.udpflows[v.key]?.closeReadWithError(nil)
                self.udpflows[v.key]?.closeWriteWithError(nil)
                if self.utSocks[v.key] != nil {
                    closeSock(self.utSocks[v.key]!, forFlow: nil, reason: "udp timeout")
                }
            }
        }
        testVPNLog("TEST MEM \(self.utSocks.count),\(self.udpflows.count), \(self.udpSocks.count), \(self.flows.count), \(self.datagramsOutstanding.count), \(self.udpSocketLastUsedTime.count)")
        // Add code here to handle the incoming flow.
        testVPNLog(self.TAG+"A new PER_APP_PROXY_FLOW comes, start handling it. flow: \(flow)")
        // @deprecate var newConnection: ClientAppProxyConnection?
        
        guard tunnel != nil else { return false }
        let serverEndpoint = tunnel?.connection?.endpoint as! NWHostEndpoint
        let serverIP = serverEndpoint.hostname
        let serverPort = serverEndpoint.port

        let socket = GCDAsyncSocket()
        socket.delegate = self
        //socket.delegateQueue = queue
        socket.delegateQueue = DispatchQueue.main

        flows[socket] = flow
        do{
            testVPNLog(self.TAG + "try to establish a TCP connection for a new flow.")
            try socket.connect(toHost: serverIP, onPort: UInt16(serverPort)!)
        } catch let error as NSError {
            testVPNLog(self.TAG + "Error happened while establishing a TCP connection for a new flow:\(error)")
            flows.remove(at: flows.index(forKey: socket)!)
            socket.disconnect()
            return false
        }
        
        testVPNLog(self.TAG + "new connection established.")
        
        return true
    }
    
    // Actions
    
    // please call this method with a TCP socket and a NEAppProxyTCPFlow
    private func closeSock(_ sock: GCDAsyncSocket, forFlow: NEAppProxyFlow?, reason: String){
        testVPNLog(self.TAG + "\(sock) \ncalling closeSock\n\(reason)")
        if let udpSock = self.udpSocks[sock]{
            //udpSock.close()
            if udpflows.index(forKey: udpSock) != nil{
                udpflows.remove(at: udpflows.index(forKey: udpSock)!)
            }
            if utSocks.index(forKey: udpSock) != nil {
                utSocks.remove(at: utSocks.index(forKey: udpSock)!)
            }
            if udpSocks.index(forKey: sock) != nil {
                udpSocks.remove(at: udpSocks.index(forKey: sock)!)
            }
            if datagramsOutstanding.index(forKey: udpSock) != nil {
                datagramsOutstanding.remove(at: datagramsOutstanding.index(forKey: udpSock)!)
            }
            if self.udpSocketLastUsedTime[udpSock] != nil {
                self.udpSocketLastUsedTime.removeValue(forKey: udpSock)
            }
            udpSock.close()
            
        }
        guard flows.index(forKey: sock) != nil else{
            sock.disconnect()
            return
        }
        flows.remove(at: flows.index(forKey: sock)!)
        sock.disconnect()
    }
    
    ////////////////////////////////////////
    /// MARK: Delegate for GCDAsyncSocket //
    ////////////////////////////////////////

    // when tcp connection established, make socks5 auth negotiation request, here I just provide NO_AUTH support.
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        testVPNLog(self.TAG + "TCP connection has established, going to negotiate for auth method")
        let flow = flows[sock]
        if let TCPFlow = flow as? NEAppProxyTCPFlow{
            TCPFlow.open(withLocalEndpoint: NWHostEndpoint.init(hostname: sock.localHost!, port: "\(sock.localPort)")) { error in
                if error != nil {
                    testVPNLog(self.TAG + "Error happened while opening up TCP flow with address: \(sock.localHost!):\(sock.localPort). \(error)")
                    self.closeSock(sock, forFlow: TCPFlow, reason: "Error happened while opening up TCP flow with address: \(sock.localHost!):\(sock.localPort). \(error)")
                    return
                }
                // auth method negotiation request
                var authNegoRequest = [UInt8]()
                authNegoRequest.append(SOCKS5_VER)
                authNegoRequest.append(0x01 as UInt8)
                authNegoRequest.append(SOCKS5_AUTH_METHOD.NO_AUTH.rawValue)
                testVPNLog(self.TAG + "write authNegorequest1 : \(NSMutableData.init(data: Data.init(bytes: authNegoRequest)))")
                sock.write(Data.init(bytes: authNegoRequest), withTimeout: TimeInterval(5), tag: SOCK_TAG.AUTH_NEGO.rawValue)
                sock.readData(withTimeout: TimeInterval(5), tag: 0)
            }
        }else{
            // auth method negotiation request
            var authNegoRequest = [UInt8]()
            authNegoRequest.append(SOCKS5_VER)
            authNegoRequest.append(0x01 as UInt8)
            authNegoRequest.append(SOCKS5_AUTH_METHOD.NO_AUTH.rawValue)
            testVPNLog(self.TAG + "write authNegorequest2 : \(NSMutableData.init(data: Data.init(bytes: authNegoRequest)))")
            sock.write(Data.init(bytes: authNegoRequest), withTimeout: TimeInterval(5), tag: SOCK_TAG.AUTH_NEGO.rawValue)
            sock.readData(withTimeout: TimeInterval(5), tag: 0)
            
        }
    }

    // some data is written to a TCP connection, here we need to insert a record to database
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        if tag == SOCK_TAG.DATA.rawValue{
            let flow = flows[sock]
            testVPNLog(self.TAG + "Did write data.\n\(sock)\n\(flow)")
            if let TCPFlow = flow as? NEAppProxyTCPFlow {
                TCPFlow.readData { data, error in
                    testVPNLog(self.TAG + "data read: \(NSMutableData.init(data: data!))\n\(TCPFlow)")
                    guard let readData = data, error == nil else {
                        testVPNLog(self.TAG + "Failed to read data from TCP flow due to: \(error)")
                        self.closeSock(sock, forFlow: TCPFlow, reason: "Failed to read data from TCP flow due to: \(error)")
                        TCPFlow.closeReadWithError(nil)
                        return
                    }
                    guard readData.count > 0 else {
                        testVPNLog(self.TAG + "EOF received on TCP flow, closing it from read direction.")
                        TCPFlow.closeReadWithError(nil)
                        self.closeSock(sock, forFlow: TCPFlow, reason: "EOF received on TCP flow, closing it from read direction.")
                        return
                    }
                    testVPNLog(self.TAG + "going to write data to sock: \(NSMutableData.init(data: readData))")
                    sock.write(readData, withTimeout: TimeInterval(5), tag: SOCK_TAG.DATA.rawValue)
                    sock.readData(withTimeout: TimeInterval(5), tag: 0)

                    /// Going to record this packet
                    let timeStr = getTime()
                    let srcIP = self.currentPublicIP
                    let srcPort: String
                    if self.wifiConnected {
                        srcPort = "0"
                    }
                    else{
                        srcPort = "\(sock.localPort)"
                    }
                    let dstIP = (TCPFlow.remoteEndpoint as! NWHostEndpoint).hostname
                    let dstPort = (TCPFlow.remoteEndpoint as! NWHostEndpoint).port
                    let length = readData.count
                    let app = TCPFlow.metaData.sourceAppSigningIdentifier

                    let labDic: NSMutableDictionary = NSMutableDictionary()
                    let dataDic: NSMutableDictionary = NSMutableDictionary()
                    labDic["idfa"] = self.idfa?.uuidString
                    labDic["app"] = app
                    dataDic["srcIP"] = srcIP
                    dataDic["srcPort"] = srcPort
                    dataDic["dstIP"] = dstIP
                    dataDic["dstPort"] = dstPort
                    dataDic["time"] = timeStr
                    dataDic["length"] = length
                    dataDic["protocol"] = "TCP"
                    let dataDicStr = toJSONString(dict: dataDic)
                    labDic["record"] = dataDicStr
                    var jsonData:NSData? = nil

                    do {
                        jsonData  = try JSONSerialization.data(withJSONObject: labDic, options:JSONSerialization.WritingOptions.prettyPrinted) as NSData
                        postRequestWithNoResponse(url: "http://119.23.215.159/test/checkin/labRec.php", jsonData: jsonData)
                    } catch {}
                    if self.recordFlow{
                        //self.database.tableNETWORKFLOWLOGInsertItem(srcIP: srcIP, srcPort: srcPort, dstIP: dstIP, dstPort: dstPort, length:length, proto: "TCP", time: timeStr, app: app, direction: "out")
                    }
                }
            }
        }
    }

    // data is read from a TCP connection, here we could get many possibilities
    // 1. it's reply of auth_nego_request
    // 2. it's reply of TCP_CONNECT or UDP_ASSOCIATE reqest
    // 3. it's data of former TCP request.
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {

        if data.count == 2 {    // parse as AUTH_NEGO_REPLY
            let VER = data[0] as UInt8
            let METHOD = data[1] as UInt8
            guard VER == SOCKS5_VER else {
                testVPNLog(self.TAG + "SOCKS version return [\(VER)] not matched.")
                if let flow = self.flows[sock]{
                    flow.closeWriteWithError(nil)
                    flow.closeReadWithError(nil)
                    closeSock(sock, forFlow: flow, reason: "SOCKS version return [\(VER)] not matched.")
                }
                return
            }
            guard METHOD == SOCKS5_AUTH_METHOD.NO_AUTH.rawValue else {
                testVPNLog(self.TAG + "Auth_method[\(METHOD)] offered by server is not supported by this app.")
                if let flow = self.flows[sock]{
                    flow.closeWriteWithError(nil)
                    flow.closeReadWithError(nil)
                    closeSock(sock, forFlow: flow, reason: "Auth_method[\(METHOD)] offered by server is not supported by this app.")
                }
                return
            }
            // safe here, go send request according to actual flow type
            if let TCPFlow = flows[sock] as? NEAppProxyTCPFlow {  // send TCP_CONNECT_REQ
                var TCP_CONNECT_REQ = [UInt8]()
                TCP_CONNECT_REQ += [SOCKS5_VER, SOCKS5_CMD.CONNECT.rawValue, SOCKS5_RSV]
                let dst = TCPFlow.remoteEndpoint as! NWHostEndpoint
                let dstIP = dst.hostname
                let dstPort = dst.port
                if checkIPFormat(ip: dstIP) {
                    TCP_CONNECT_REQ += [SOCKS5_ATYP.IPV4.rawValue]
                    TCP_CONNECT_REQ += string2Hex(input: dstIP, mod: "ip")
                    TCP_CONNECT_REQ += string2Hex(input: dstPort, mod: "port")
                }else{
                    TCP_CONNECT_REQ += [SOCKS5_ATYP.DOMAINNAME.rawValue, UInt8(dstIP.count)]
                    TCP_CONNECT_REQ += Array(dstIP.utf8) as [UInt8]
                    TCP_CONNECT_REQ += string2Hex(input: dstPort, mod: "port")
                }
                testVPNLog(self.TAG + "TCP connect request to: \(dstIP):\(dstPort)")
                testVPNLog(self.TAG + "write TCP Connect request: \(NSMutableData.init(data: Data.init(bytes: TCP_CONNECT_REQ)))")
                sock.write(Data.init(bytes: TCP_CONNECT_REQ), withTimeout: TimeInterval(5), tag: SOCK_TAG.TCP_CONNECT.rawValue)
                sock.readData(withTimeout: TimeInterval(5), tag: 0)
            }
            else if let UDPFlow = flows[sock] as? NEAppProxyUDPFlow {// send UDP_ASSOCIATE_REQ

                // open up a new UDP socket
                let udpsock = GCDAsyncUdpSocket()
                udpsock.setDelegate(self)
                //udpsock.setDelegateQueue(DispatchQueue.main)
                udpsock.setDelegateQueue(DispatchQueue.init(label: "UDP"))

                udpSocks[sock] = udpsock
                utSocks[udpsock] = sock
                udpflows[udpsock] = UDPFlow
                testVPNLog("test mem just new udp \(self.utSocks.count),\(self.udpflows.count), \(self.udpSocks.count), \(self.flows.count), \(self.datagramsOutstanding.count) , \(self.udpSocketLastUsedTime.count)")
                
                testVPNLog("Before open: \(UDPFlow.localEndpoint)")
                let tempUDPFlowLocalEndpoint = UDPFlow.localEndpoint as! NWHostEndpoint
                // bind UDP socket with local ip
                do {

                    var sa = sockaddr_in()
                    sa.sin_len = UInt8(MemoryLayout.size(ofValue: sa))
                    sa.sin_family = sa_family_t(AF_INET)
                    sa.sin_addr.s_addr = inet_addr(sock.localHost!)
                    try udpsock.bind(toAddress: NSData.init(bytes: &sa, length: MemoryLayout<sockaddr_in>.size) as Data)

                    let localAddress = tempUDPFlowLocalEndpoint.port != "0" ? NWHostEndpoint(hostname: tempUDPFlowLocalEndpoint.hostname, port: "\(tempUDPFlowLocalEndpoint.port)") : NWHostEndpoint(hostname: udpsock.localHost()!, port: "\(udpsock.localPort())")
                    
                    if tempUDPFlowLocalEndpoint.port != "0"{
                        testVPNLog("Before open _, open with \(localAddress)")
                    }
                    UDPFlow.open(withLocalEndpoint: localAddress){ error in
                        if error != nil {
                            testVPNLog(self.TAG + "Error happened while opening UDP flow: \(error)")
                            UDPFlow.closeReadWithError(nil)
                            UDPFlow.closeWriteWithError(nil)
                            self.closeSock(sock, forFlow: UDPFlow, reason: "Error happened while opening UDP flow: \(error)")
                            return
                        }

//                        do {
//                            try udpsock.beginReceiving()
//                        }
//                        catch let receiveError as NSError {
//                            testVPNLog(self.TAG + "Error happened when UDP socket begin receiving. \(receiveError)")
//                            UDPFlow.closeReadWithError(nil)
//                            UDPFlow.closeWriteWithError(nil)
//                            self.closeSock(sock, forFlow: self.flows[sock]!, reason: "Error happened when UDP socket begin receiving. \(receiveError)")
//                            return
//                        }

                        var UDP_ASSOCIATE_REQ = [UInt8]()
                        UDP_ASSOCIATE_REQ += [SOCKS5_VER, SOCKS5_CMD.UDP_ASSOCIATE.rawValue, SOCKS5_RSV, SOCKS5_ATYP.IPV4.rawValue]
                        UDP_ASSOCIATE_REQ += string2Hex(input: "0.0.0.0", mod: "ip")
                        UDP_ASSOCIATE_REQ += string2Hex(input: "\(udpsock.localPort())", mod: "port")
                        testVPNLog("Before open, request address: \(udpsock.localHost()) request port: \(udpsock.localPort())")
                        //UDP_ASSOCIATE_REQ += string2Hex(input: "0", mod: "port")

                        testVPNLog(self.TAG + "write UDP ASSOCIATE REQUEST: \(NSMutableData.init(data: Data.init(bytes: UDP_ASSOCIATE_REQ)))")
                        sock.write(Data.init(bytes: UDP_ASSOCIATE_REQ), withTimeout: TimeInterval(5), tag: SOCK_TAG.UDP_ASSOCIATE.rawValue)
                        sock.readData(withTimeout: TimeInterval(5), tag: 0)
                    }
                }
                catch let error as NSError {
                    testVPNLog(self.TAG + "Error happened when bind UDP socket to local address. \(error)")
                    closeSock(sock, forFlow: flows[sock]!, reason: "Error happened when bind UDP socket to local address. \(error)")
                    return
                }
            }
        }
        else if data.count == 10 {  // parse as a TCP_CONNECT_REPLY or UDP_ASSOCIATE_REPLY
            let VER = data[0] as UInt8
            let REP = data[1] as UInt8
            guard VER == SOCKS5_VER else {
                testVPNLog(self.TAG + "SOCKS version return [\(VER)] not matched.")
                if let flow = self.flows[sock]{
                    flow.closeReadWithError(nil)
                    flow.closeWriteWithError(nil)
                    closeSock(sock, forFlow: flow, reason: "SOCKS version return [\(VER)] not matched.")
                }
                return
            }
            if REP == SOCKS5_REP.SUCCEEDED.rawValue {
                testVPNLog(self.TAG + "Got reply, success.")
            }else{
                switch REP {
                case SOCKS5_REP.SERVER_FAILURE.rawValue:
                    testVPNLog(self.TAG + "SOCKS5 request failed due to \"General SOCKS server failure\"")
                case SOCKS5_REP.CONNECTION_NOT_ALLOWED.rawValue:
                    testVPNLog(self.TAG + "SOCKS5 request failed due to \"Connection not allowed by ruleset\"")
                case SOCKS5_REP.NETWORK_UNREACHABLE.rawValue:
                    testVPNLog(self.TAG + "SOCKS5 request failed due to \"Network unreachable\"")
                case SOCKS5_REP.HOST_UNREACHABLE.rawValue:
                    testVPNLog(self.TAG + "SOCKS5 request failed due to \"Host unreachable\"")
                case SOCKS5_REP.CONNECTION_REFUSED.rawValue:
                    testVPNLog(self.TAG + "SOCKS5 request failed due to \"Connection refused\"")
                case SOCKS5_REP.TTL_EXPIRED.rawValue:
                    testVPNLog(self.TAG + "SOCKS5 request failed due to \"TTL expired\"")
                case SOCKS5_REP.COMMAND_NOT_SUPPORTED.rawValue:
                    testVPNLog(self.TAG + "SOCKS5 request failed due to \"Command not supported\"")
                case SOCKS5_REP.ADDRESS_NOT_SUPPORTED.rawValue:
                    testVPNLog(self.TAG + "SOCKS5 request failed due to \"Address type not supported\"")
                case SOCKS5_REP.TO_FF_UNASSIGNED.rawValue:
                    testVPNLog(self.TAG + "SOCKS5 request failed due to \"to X'FF' unassigned\"")
                default:
                    testVPNLog(self.TAG + "Unexpected reply code.\(REP)")
                }
                flows[sock]!.closeReadWithError(nil)
                flows[sock]!.closeWriteWithError(nil)
                closeSock(sock, forFlow: flows[sock]!, reason: "\(REP)")
                return
            }

            if let TCPFlow = flows[sock] as? NEAppProxyTCPFlow {
                TCPFlow.readData { data, error in
                    testVPNLog(self.TAG + "data read from TCP Flow: \(NSMutableData.init(data: data!))\n\(TCPFlow)")
                    guard let readData = data, error == nil else {
                        testVPNLog(self.TAG + "Failed to read data from TCP flow due to: \(error!)")
                        self.closeSock(sock, forFlow: TCPFlow, reason: "Failed to read data from TCP flow due to: \(error!)")
                        TCPFlow.closeReadWithError(nil)
                        return
                    }
                    guard readData.count > 0 else {
                        testVPNLog(self.TAG + "EOF received on TCP flow, closing it from read direction.")
                        TCPFlow.closeReadWithError(nil)
                        self.closeSock(sock, forFlow: TCPFlow, reason: "EOF received on TCP flow, closing it from read direction.")
                        return
                    }
                    testVPNLog(self.TAG + "going to write data to sock: \(NSMutableData.init(data: readData))")
                    sock.write(readData, withTimeout: TimeInterval(5), tag: SOCK_TAG.DATA.rawValue)
                    sock.readData(withTimeout: TimeInterval(5), tag: 0)

                    /// Going to record this packet
                    let timeStr = getTime()
                    let srcIP = self.currentPublicIP
                    let srcPort: String
                    if self.wifiConnected {
                        srcPort = "0"
                    }
                    else{
                        srcPort = "\(sock.localPort)"
                    }
                    let dstIP = (TCPFlow.remoteEndpoint as! NWHostEndpoint).hostname
                    let dstPort = (TCPFlow.remoteEndpoint as! NWHostEndpoint).port
                    let length = readData.count
                    let app = TCPFlow.metaData.sourceAppSigningIdentifier
                    
                    let labDic: NSMutableDictionary = NSMutableDictionary()
                    let dataDic: NSMutableDictionary = NSMutableDictionary()
                    labDic["idfa"] = self.idfa?.uuidString
                    labDic["app"] = app
                    dataDic["srcIP"] = srcIP
                    dataDic["srcPort"] = srcPort
                    dataDic["dstIP"] = dstIP
                    dataDic["dstPort"] = dstPort
                    dataDic["time"] = timeStr
                    dataDic["length"] = length
                    dataDic["protocol"] = "TCP"
                    let dataDicStr = toJSONString(dict: dataDic)
                    labDic["record"] = dataDicStr
                    var jsonData:NSData? = nil

                    do {
                        jsonData  = try JSONSerialization.data(withJSONObject: labDic, options:JSONSerialization.WritingOptions.prettyPrinted) as NSData
                        postRequestWithNoResponse(url: "http://119.23.215.159/test/checkin/labRec.php", jsonData: jsonData)
                    } catch {}
                    if self.recordFlow{
                        //self.database.tableNETWORKFLOWLOGInsertItem(srcIP: self.currentPublicIP, srcPort: srcPort, dstIP: dstIP, dstPort: dstPort, length:length, proto: "TCP", time: timeStr, app: app, direction: "out")
                    }
                }
            }
            else if let UDPFlow = flows[sock] as? NEAppProxyUDPFlow {
                guard let udpSock = udpSocks[sock] else{
                    fatalError("UDP Sock missing!")
                }
                
                let ATYP = data[3]
                // for TCP BND_ADDR and BND_PORT are of no use
                var BND_ADDR = [UInt8]()
                var BND_PORT = [UInt8]()
                switch ATYP {
                case SOCKS5_ATYP.IPV4.rawValue:
                    BND_ADDR += [data[4],data[5],data[6],data[7]] as [UInt8]
                    BND_PORT += [data[8],data[9]] as [UInt8]
                case SOCKS5_ATYP.DOMAINNAME.rawValue:
                    let length = UInt32(data[4])
                    BND_ADDR += data[5...4+length]
                    BND_PORT += data[5+length...7+length]
                case SOCKS5_ATYP.IPV6.rawValue:
                    testVPNLog(self.TAG + "IPv6 address not supported for this app.")
                    self.closeSock(sock, forFlow: self.flows[sock]!, reason: "IPv6 address not supported for this app.")
                    UDPFlow.closeReadWithError(nil)
                    return
                default:
                    testVPNLog(self.TAG + "Unexpected address type: \(ATYP)")
                    self.closeSock(sock, forFlow: self.flows[sock]!, reason: "Unexpected address type: \(ATYP)")
                    UDPFlow.closeReadWithError(nil)
                    return
                }

                // going to connect to udp server socket
                let ipString = (self.tunnel?.connection?.endpoint as! NWHostEndpoint).hostname
                let port: UInt16 = UInt16(BND_PORT[0]) * 256 + UInt16(BND_PORT[1])
                do{
                    try udpSock.connect(toHost: ipString, onPort: port)
                    testVPNLog("UDP socket connected to \(ipString):\(port)")
                }catch let error as NSError {
                    testVPNLog(self.TAG + "Error happened while connecting to UDP soket \(ipString):\(port). \(error)")
                    self.closeSock(sock, forFlow: UDPFlow, reason: "Error happened while connecting to UDP soket \(ipString):\(port). \(error)")
                    UDPFlow.closeReadWithError(nil)
                    return
                }

                // ! TCP connection should never be disconnected
                // should consider how make this TCP socket alive for long
                sock.readData(withTimeout: TimeInterval(-1), tag: 0)
            }
        }
        else{
            // got data replied for TCP flow
            //testVPNLog(self.TAG + "get data reply from TCP socket: \(NSMutableData.init(data: data)) \nfor flow: \(flows[sock])")
            testVPNLog(self.TAG + "get data reply from TCP \nfor flow: \(flows[sock])")
            if let TCPFlow = flows[sock] as? NEAppProxyTCPFlow {
                TCPFlow.write(data) { error in
                    if error != nil {
                        testVPNLog(self.TAG + "Error happened while writing TCP data back to app: \(error), \nsock: \(sock), \nflow: \(TCPFlow)")
                        TCPFlow.closeWriteWithError(nil)
                        self.closeSock(sock, forFlow: TCPFlow, reason: "Error happened while writing data back to app: \(error)")
                        return
                    }

                    /// Going to record this packet
                    let timeStr = getTime()
                    let srcIP = (TCPFlow.remoteEndpoint as! NWHostEndpoint).hostname
                    let srcPort = (TCPFlow.remoteEndpoint as! NWHostEndpoint).port
                    let dstIP = self.currentPublicIP
                    let dstPort: String
                    if self.wifiConnected {
                        dstPort = "0"
                    }
                    else{
                        dstPort = "\(sock.localPort)"
                    }
                    let length = data.count
                    let app = TCPFlow.metaData.sourceAppSigningIdentifier

                    let labDic: NSMutableDictionary = NSMutableDictionary()
                    let dataDic: NSMutableDictionary = NSMutableDictionary()
                    labDic["idfa"] = self.idfa?.uuidString
                    labDic["app"] = app
                    dataDic["srcIP"] = srcIP
                    dataDic["srcPort"] = srcPort
                    dataDic["dstIP"] = dstIP
                    dataDic["dstPort"] = dstPort
                    dataDic["time"] = timeStr
                    dataDic["length"] = length
                    dataDic["protocol"] = "TCP"
                    let dataDicStr = toJSONString(dict: dataDic)
                    labDic["record"] = dataDicStr
                    var jsonData:NSData? = nil

                    do {
                        jsonData  = try JSONSerialization.data(withJSONObject: labDic, options:JSONSerialization.WritingOptions.prettyPrinted) as NSData
                        postRequestWithNoResponse(url: "http://119.23.215.159/test/checkin/labRec.php", jsonData: jsonData)
                    } catch {}
                    if self.recordFlow{
                        //self.database.tableNETWORKFLOWLOGInsertItem(srcIP: srcIP, srcPort: srcPort, dstIP: dstIP, dstPort: dstPort, length:length, proto: "TCP", time: timeStr, app: app, direction: "in")
                    }

                    sock.readData(withTimeout: TimeInterval(5), tag: 0)
                }
            }
            else if let UDPFlow = flows[sock] as? NEAppProxyUDPFlow {
                testVPNLog("BOOM!!!!!!!")
            }
        }
    }

    // when tcp connection closed, check all connections and flows having relationship with this tcp sock, and close them all
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        testVPNLog("test MEM socket did disconnect. \(self.utSocks.count),\(self.udpflows.count), \(self.udpSocks.count), \(self.flows.count), \(self.datagramsOutstanding.count) , \(self.udpSocketLastUsedTime.count)")
        guard flows[sock] != nil else{
            return
        }
        closeSock(sock, forFlow: nil, reason: "auto disconnect")
    }

    /////////////////////////////////
    /// MARK: UDP Socket Delegate ///
    /////////////////////////////////

    func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?) {
        testVPNLog("test MEM socket did close. \(self.utSocks.count),\(self.udpflows.count), \(self.udpSocks.count), \(self.flows.count), \(self.datagramsOutstanding.count), \(self.udpSocketLastUsedTime.count) ")
        testVPNLog("UDP Socket did close due to Error [\(sock.localPort())]: \(error)")
        guard self.utSocks[sock] != nil else{
            return
        }
        closeSock(self.utSocks[sock]!, forFlow: nil, reason: "no reason")
    }

    // UDP socket did have connected to an address
    func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
        self.udpSocketLastUsedTime[sock] = Date().timeIntervalSince1970
        var addr:sockaddr_in = sockaddr_in()
        NSData.init(data: address).getBytes(&addr, length: MemoryLayout<sockaddr>.size)
        let tmpPort = in_port_t(bigEndian: addr.sin_port)
        let tmpAddr = in_addr_t(bigEndian: addr.sin_addr.s_addr)
        
        testVPNLog(self.TAG + "UDP socket did connect to address: \(tmpAddr>>24&0xff).\(tmpAddr>>16&0xff).\(tmpAddr>>8&0xff).\(tmpAddr>>0&0xff):\(tmpPort) from \(sock.localHost()):\(sock.localPort())")

        guard let UDPFlow = udpflows[sock] else{
            fatalError("Missing UDP flow...")
        }

        do {
            try sock.beginReceiving()
        }
        catch let receiveError as NSError {
            testVPNLog(self.TAG + "Error happened when UDP socket begin receiving. \(receiveError)")
            UDPFlow.closeReadWithError(nil)
            UDPFlow.closeWriteWithError(nil)
            self.closeSock(self.utSocks[sock]!, forFlow: nil, reason: "Error happened when UDP socket begin receiving. \(receiveError)")
            return
        }

        testVPNLog("+++++++ \(UDPFlow)\n\(sock.localHost()):\(sock.localPort())\n\(UDPFlow.localEndpoint)")
        UDPFlow.readDatagrams { datagrams, remoteEndPoints, readError in
            guard let readDatagrams = datagrams,
                let readEndpoints = remoteEndPoints,
                readError == nil else {
                    testVPNLog(self.TAG + "Failed to read data from the UDP flow. [\(tmpPort)]")
                    self.closeSock(self.utSocks[sock]!, forFlow: UDPFlow, reason: "Failed to read data from the UDP flow. [\(tmpPort)]")
                    UDPFlow.closeReadWithError(nil)

                    return
            }

            guard !readDatagrams.isEmpty && readEndpoints.count == readDatagrams.count else {
                testVPNLog(self.TAG + "[\(sock.localPort())]Received EOF on the UDP flow. Close the flow from read direction...[\(tmpPort)]")
                UDPFlow.closeReadWithError(nil)
                guard self.utSocks[sock] != nil else{
                    return
                }
                self.closeSock(self.utSocks[sock]!, forFlow: UDPFlow, reason: "Received EOF on the UDP flow. Close the flow from read direction...[\(tmpPort)]")
                return
            }

            self.datagramsOutstanding[sock] = readDatagrams.count

            for (index, datagram) in readDatagrams.enumerated() {
                guard let endpoint = readEndpoints[index] as? NWHostEndpoint else { continue }

                let rsvHex = [SOCKS5_RSV,SOCKS5_RSV] as [UInt8]
                let FRAG = [0x00] as [UInt8]
                let ATYP: [UInt8]
                let hostHex: [UInt8]
                if checkIPFormat(ip: endpoint.hostname) {
                    ATYP = [SOCKS5_ATYP.IPV4.rawValue] as [UInt8]
                    hostHex = string2Hex(input: endpoint.hostname, mod: "ip")
                }else{
                    // domain name, may never get used
                    ATYP = [SOCKS5_ATYP.DOMAINNAME.rawValue] as [UInt8]
                    let lengthHex = [UInt8(endpoint.hostname.count)]
                    hostHex = lengthHex + Array(endpoint.hostname.utf8) as [UInt8]
                }

                let portHex = string2Hex(input: endpoint.port, mod: "port")
                let data = [UInt8](datagram)
                var payload = [UInt8]()
                payload += rsvHex
                payload += FRAG
                payload += ATYP
                payload += hostHex
                payload += portHex
                payload += data

                /// Going to record this packet
                let timeStr = getTime()
                let srcIP = self.currentPublicIP
                let srcPort: String
                if self.wifiConnected {
                    srcPort = "0"
                }
                else{
                    srcPort = "\(sock.localPort)"
                }
                let dstIP = endpoint.hostname
                let dstPort = endpoint.port
                let length = datagram.count
                let app = UDPFlow.metaData.sourceAppSigningIdentifier

                let labDic: NSMutableDictionary = NSMutableDictionary()
                let dataDic: NSMutableDictionary = NSMutableDictionary()
                labDic["idfa"] = self.idfa?.uuidString
                labDic["app"] = app
                dataDic["srcIP"] = srcIP
                dataDic["srcPort"] = srcPort
                dataDic["dstIP"] = dstIP
                dataDic["dstPort"] = dstPort
                dataDic["time"] = timeStr
                dataDic["length"] = length
                dataDic["protocol"] = "UDP"
                let dataDicStr = toJSONString(dict: dataDic)
                labDic["record"] = dataDicStr
                var jsonData:NSData? = nil

                do {
                    jsonData  = try JSONSerialization.data(withJSONObject: labDic, options:JSONSerialization.WritingOptions.prettyPrinted) as NSData
                    postRequestWithNoResponse(url: "http://119.23.215.159/test/checkin/labRec.php", jsonData: jsonData)
                } catch {}
                if self.recordFlow{
                    //self.database.tableNETWORKFLOWLOGInsertItem(srcIP: srcIP, srcPort: srcPort, dstIP: dstIP, dstPort: dstPort, length:length, proto: "UDP", time: timeStr, app: app, direction: "out")
                }

                sock.send(Data.init(bytes: payload), withTimeout: TimeInterval(5), tag: 0)
                //sock.send(Data.init(bytes: payload), toHost: sock.connectedHost()!, port: sock.connectedPort(), withTimeout: TimeInterval(-1), tag: 0)
            }
        }
    }

    // UDP socket did have sent data with tag
    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) {
        self.udpSocketLastUsedTime[sock] = Date().timeIntervalSince1970
        //testVPNLog(self.TAG + "utSocks.length: \(utSocks.count)\nudpSocks.length: \(udpSocks.count)\nflows.length: \(flows.count)\nudpflows.length: \(udpflows.count)\ndatagramsOutstanding: \(datagramsOutstanding)")
        testVPNLog("******* did send with sock: \(sock.localHost()):\(sock.localPort()) ==> \(sock.connectedHost()):\(sock.connectedPort())\n\(udpflows[sock])\n\(udpflows[sock]?.localEndpoint)")
        let UDPFlow = udpflows[sock]
        if self.datagramsOutstanding[sock]! > 0{
            self.datagramsOutstanding[sock] = self.datagramsOutstanding[sock]! - 1
        }

        guard self.datagramsOutstanding[sock] == 0 else{
            return
        }
        
        UDPFlow!.readDatagrams { datagrams, remoteEndPoints, readError in
            guard let readDatagrams = datagrams,
                let readEndpoints = remoteEndPoints,
                readError == nil else
            {
                if readError != nil {
                    testVPNLog(self.TAG + "Failed to read data from the UDP flow. [\(sock.localPort())]\nError: \(readError)")
                    if self.utSocks[sock] == nil{
                        testVPNLog("BOOM!!!!!!! no TCP sock for udp sock[\(sock.localPort())]")
                    }else{
                        self.closeSock(self.utSocks[sock]!, forFlow: UDPFlow!, reason: "Failed to read data from the UDP flow. [\(sock.localPort())]")
                    }
                    UDPFlow?.closeReadWithError(nil)
                }
                else{
                    testVPNLog(self.TAG + "Failed to read data from UDP flow.[\(sock.localPort())]")
                    self.closeSock(self.utSocks[sock]!, forFlow: UDPFlow!, reason: "Failed to read data from the UDP flow. [\(sock.localPort())]")
                }
                return
            }

            guard !readDatagrams.isEmpty && readEndpoints.count == readDatagrams.count else {
                testVPNLog(self.TAG + "[\(sock.localPort())]Received EOF on the UDP flow. Close the flow from read direction...[\(sock.localPort())]")
                UDPFlow!.closeReadWithError(nil)
                if self.utSocks[sock] != nil {
                    self.closeSock(self.utSocks[sock]!, forFlow: UDPFlow!, reason: "Received EOF on the UDP flow. Close the flow from read direction...[\(sock.localPort())]")
                }
                return
            }

            self.datagramsOutstanding[sock] = readDatagrams.count

            for (index, datagram) in readDatagrams.enumerated() {
                guard let endpoint = readEndpoints[index] as? NWHostEndpoint else { continue }

                
                let rsvHex = [SOCKS5_RSV,SOCKS5_RSV] as [UInt8]
                let FRAG = [0x00] as [UInt8]
                let ATYP: [UInt8]
                let hostHex: [UInt8]
                if checkIPFormat(ip: endpoint.hostname) {
                    ATYP = [SOCKS5_ATYP.IPV4.rawValue] as [UInt8]
                    hostHex = string2Hex(input: endpoint.hostname, mod: "ip")
                }else{
                    // domain name
                    // may never used
                    ATYP = [SOCKS5_ATYP.DOMAINNAME.rawValue] as [UInt8]
                    let lengthHex = [UInt8(endpoint.hostname.count)]
                    hostHex = lengthHex + Array(endpoint.hostname.utf8) as [UInt8]
                    
                }

                let portHex = string2Hex(input: endpoint.port, mod: "port")
                let data = [UInt8](datagram)
                var payload = [UInt8]()
                payload += rsvHex
                payload += FRAG
                payload += ATYP
                payload += hostHex
                payload += portHex
                payload += data


                /// Going to record this packet
                let timeStr = getTime()
                let srcIP = self.currentPublicIP
                let srcPort: String
                if self.wifiConnected {
                    srcPort = "0"
                }
                else{
                    srcPort = "\(sock.localPort)"
                }
                let dstIP = endpoint.hostname
                let dstPort = endpoint.port
                let length = datagram.count
                let app = UDPFlow!.metaData.sourceAppSigningIdentifier

                let labDic: NSMutableDictionary = NSMutableDictionary()
                let dataDic: NSMutableDictionary = NSMutableDictionary()
                labDic["idfa"] = self.idfa?.uuidString
                labDic["app"] = app
                dataDic["srcIP"] = srcIP
                dataDic["srcPort"] = srcPort
                dataDic["dstIP"] = dstIP
                dataDic["dstPort"] = dstPort
                dataDic["time"] = timeStr
                dataDic["length"] = length
                dataDic["protocol"] = "UDP"
                let dataDicStr = toJSONString(dict: dataDic)
                labDic["record"] = dataDicStr
                var jsonData:NSData? = nil
                
                do {
                    jsonData  = try JSONSerialization.data(withJSONObject: labDic, options:JSONSerialization.WritingOptions.prettyPrinted) as NSData
                    postRequestWithNoResponse(url: "http://119.23.215.159/test/checkin/labRec.php", jsonData: jsonData)
                } catch {}
                if self.recordFlow{
                    //self.database.tableNETWORKFLOWLOGInsertItem(srcIP: srcIP, srcPort: srcPort, dstIP: dstIP, dstPort: dstPort, length:length, proto: "UDP", time: timeStr, app: app, direction: "out")
                }

                sock.send(Data.init(bytes: payload), withTimeout: TimeInterval(5), tag: 0)
                //sock.send(Data.init(bytes: payload), toHost: sock.connectedHost()!, port: sock.connectedPort(), withTimeout: TimeInterval(-1), tag: 0)
            }
        }
    }

    // UDP socket did have received data from address with FilterContext
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        self.udpSocketLastUsedTime[sock] = Date().timeIntervalSince1970
        testVPNLog("[\(sock.localPort())] received data: \(NSMutableData.init(data: data))]")
        var sa = sockaddr_in()
        NSData.init(data: address).getBytes(&sa, length: MemoryLayout<sockaddr>.size)

        let tmpAddr = sa.sin_addr.s_addr
        testVPNLog("[\(sock.localPort())]Received udp data from address: \(tmpAddr>>24&0xff).\(tmpAddr>>16&0xff).\(tmpAddr>>8&0xff).\(tmpAddr>>0&0xff):\(sa.sin_port)!! \ndata: \(NSMutableData.init(data: data))")
        guard let flow = udpflows[sock] as? NEAppProxyUDPFlow else{
            return
        }

        let FRAG = data[2]
        if FRAG != 0x00 as UInt8{
            testVPNLog(self.TAG + "[\(sock.localPort())]UDP datagrams FRAG not supported now.")
        }
        let ATYP = data[3]
        var udpIPHex = [UInt8]()
        var udpPort: UInt16 = 0
        var datagramHex = [UInt8]()

        switch ATYP {
        case SOCKS5_ATYP.IPV4.rawValue:
            udpIPHex += data[4...7]
            udpPort = UInt16(data[8])*256+UInt16(data[9])
            datagramHex += data[10 ... data.count - 1]
        case SOCKS5_ATYP.DOMAINNAME.rawValue:
//            let length = Int(data[4])
//            udpIPHex += data[5...4+length]
//            udpPort = UInt16(data[5+length])*256+UInt16(data[6+length])
//            datagramHex += data[7+length ... data.count - 1]
            testVPNLog(self.TAG + "[\(sock.localPort())]UDP Address type Domainname not supported now.")
        case SOCKS5_ATYP.IPV6.rawValue:
            testVPNLog(self.TAG + "[\(sock.localPort())]UDP Address type IPv6 not supported now.")
        default:
            testVPNLog(self.TAG + "[\(sock.localPort())]Unexpected address type: \(ATYP)")
        }

        let datagram = [ Data.init(bytes: datagramHex) ]
        let endpoint = [ NWHostEndpoint(hostname: "\(udpIPHex[0]).\(udpIPHex[1]).\(udpIPHex[2]).\(udpIPHex[3])", port: "\(udpPort)") ]
        //let endpoint = [ NWHostEndpoint(hostname: sock.connectedHost()!, port: "\(sock.connectedPort())") ]
        testVPNLog("sent by \(endpoint)")

        /// Going to record this packet
        let timeStr = getTime()
        let dstIP = self.currentPublicIP
        let dstPort: String
        if self.wifiConnected {
            dstPort = "0"
        }
        else{
            dstPort = "\(sock.localPort)"
        }
        let srcIP = endpoint[0].hostname
        let srcPort = endpoint[0].port
        let length = datagram[0].count
        let app = flow.metaData.sourceAppSigningIdentifier

        let labDic: NSMutableDictionary = NSMutableDictionary()
        let dataDic: NSMutableDictionary = NSMutableDictionary()
        labDic["idfa"] = self.idfa?.uuidString
        labDic["app"] = app
        dataDic["srcIP"] = srcIP
        dataDic["srcPort"] = srcPort
        dataDic["dstIP"] = dstIP
        dataDic["dstPort"] = dstPort
        dataDic["time"] = timeStr
        dataDic["length"] = length
        dataDic["protocol"] = "UDP"
        let dataDicStr = toJSONString(dict: dataDic)
        labDic["record"] = dataDicStr
        var jsonData:NSData? = nil

        do {
            jsonData  = try JSONSerialization.data(withJSONObject: labDic, options:JSONSerialization.WritingOptions.prettyPrinted) as NSData
            postRequestWithNoResponse(url: "http://119.23.215.159/test/checkin/labRec.php", jsonData: jsonData)
        } catch {}
        if self.recordFlow{
            //self.database.tableNETWORKFLOWLOGInsertItem(srcIP: srcIP, srcPort: srcPort, dstIP: dstIP, dstPort: dstPort, length:length, proto: "UDP", time: timeStr, app: app, direction: "in")
        }

        flow.writeDatagrams(datagram, sentBy: endpoint) { error in
            if error != nil {
                testVPNLog("[\(sock.localPort())]Error happened while writing datagram back to UDP Flow: \(error) \n\(flow)\nremoteEndpoint: \(endpoint[0])")
                sock.pauseReceiving()
                
                flow.closeWriteWithError(nil)
                if self.utSocks[sock] != nil{
                    self.closeSock(self.utSocks[sock]!, forFlow: nil, reason: "[\(sock.localPort())]Error happened while writing datagram back to UDP Flow: \(error) \n\(flow)\nremoteEndpoint: \(endpoint[0])")
                }
                return
            }
            testVPNLog("******++ [\(sock.localPort())]Write UDP Datagram back to app succeeded! \n remoteEndpoint: \(endpoint[0]), datagram: \(NSMutableData.init(data: datagram[0]))\n\(flow)\n\(sock.connectedHost()):\(sock.connectedPort())\n\(sock.localHost()):\(sock.localPort())\n\(flow)\n\(flow.localEndpoint)")
        }
    }
    
    
    ///////////////////////////
    // MARK: Tunnel Delegate //
    ///////////////////////////
    
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
        
        guard let tunnelAddress = tunnel?.remoteHost else {
            let error = SimpleTunnelError.badConnection
            pendingStartCompletion?(error as NSError)
            pendingStartCompletion = nil
            return
        }
        
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
    
    /////////////////////////////////////
    // MARK: To listen to networkState //
    /////////////////////////////////////
    func networkStatusListener() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged), name: Notification.Name.reachabilityChanged, object: reachability)
        do {
            try reachability?.startNotifier()
        }catch{
            testVPNLog("start reachability notifier failed.")
        }
    }
    
    deinit {
        reachability?.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: Notification.Name.reachabilityChanged, object: reachability)
    }
    
    func reachabilityChanged(note: NSNotification){
        let reachability = note.object as! Reachability
        
        if reachability.isReachable {
            if reachability.isReachableViaWiFi{
                testVPNLog("Reachability: WIFI)")
                self.wifiConnected = true
            }
            else{
                testVPNLog("Reachability: MobileNet)")
                self.wifiConnected = false
            }
            
            // update ip record
            
            let params: NSMutableDictionary = NSMutableDictionary()
            params["idfa"] = self.idfa?.uuidString
            var jsonData:NSData? = nil
            do {
                jsonData  = try JSONSerialization.data(withJSONObject: params, options:JSONSerialization.WritingOptions.prettyPrinted) as NSData
            } catch {
            }
            
            postRequest(url: "http://119.23.215.159/test/checkin/checkin.php", jsonData: jsonData) { retStr in
                do{
                    if let json = try JSONSerialization.jsonObject(with: retStr as! Data, options: []) as? NSDictionary {
                        //let lastIP = self.database.tableAPPCONFIGQueryItem(key: "ip")
                        //if lastIP == nil {
//                            self.database.tableAPPCONFIGInsertItem(key: "ip", value: json.value(forKey: "ip") as! String)
//                        }else if lastIP == json.value(forKey: "ip") as? String{
//                            // do nothing
//                        }else {
//                            self.database.tableAPPCONFIGUpdateItem(key: "ip", value: json.value(forKey: "ip") as! String)
//                        }
                        self.currentPublicIP = json.value(forKey: "ip") as! String
                        testVPNLog("Reachability: \(self.currentPublicIP)")
                    }
                }
                catch{
                    
                }
            }
            
        }else{
            // no network
        }
    }
}
