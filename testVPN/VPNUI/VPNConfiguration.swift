//
//  VPNConfiguration.swift
//  testVPNUIDesign
//
//  Created by Joe Liu on 2018/9/10.
//  Copyright © 2018年 NUDT. All rights reserved.
//

import Foundation

class VPNConfiguration: NSObject, NSCoding {
    
    // MARK: Properties
    
    var VPNName: String
    var VPNIP: String
    var VPNPort: String
    var enabled: Bool
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("VPNConfigurations")
    
    init(vpnName: String, vpnIP: String, vpnPort: String, enabled: Bool) {
        self.VPNName = vpnName
        self.VPNIP = vpnIP
        self.VPNPort = vpnPort
        self.enabled = enabled
    }
    
    // MARK: Types
    struct  PropertyKey {
        static let name = "name"
        static let ip = "ip"
        static let port = "port"
        static let enabled = "enabled"
    }
    
    // MARK: Actions
    
    // check if ip is correct
    func checkIPFormat() -> Bool{
        let ipAddrPattern = "^(1\\d{2}|2[0-4]\\d|25[0-5]|[1-9]\\d|[1-9])\\.(1\\d{2}|2[0-4]\\d|25[0-5]|[1-9]\\d|\\d)\\.(1\\d{2}|2[0-4]\\d|25[0-5]|[1-9]\\d|\\d)\\.(1\\d{2}|2[0-4]\\d|25[0-5]|[1-9]\\d|\\d)$"
        let matcher = myRegex(ipAddrPattern)
        let testAddr = VPNIP
        if matcher.match(input: testAddr){
            return true
        }
        
        return false
    }
    
    
    // check if port is correct
    func checkPortFormat() -> Bool{
        if let portNumber = Int(VPNPort) {
            if portNumber >= 0 && portNumber < 65536 {
                return true
            }
        }
        return false
    }
    
    // MARK: Coder suport
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(VPNName, forKey: PropertyKey.name)
        aCoder.encode(VPNIP, forKey: PropertyKey.ip)
        aCoder.encode(VPNPort, forKey: PropertyKey.port)
        aCoder.encode(enabled, forKey: PropertyKey.enabled)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        // The name is required, if we cannot decode a name string, the initializer should fail.
        guard let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String else{
            NSLog("Unable to decode the name for vpn object. ")
            return nil
        }
        
        // Because photo is an optional property of Meal, just use conditional cast
        guard let ip = aDecoder.decodeObject(forKey: PropertyKey.ip) as? String else {
            NSLog("Unable to decode the ip for vpn object. ")
            return nil
        }
        
        guard let port = aDecoder.decodeObject(forKey: PropertyKey.port) as? String else {
            NSLog("Unable to decode the port for vpn object. ")
            return nil
        }
        
        let enabled = aDecoder.decodeBool(forKey: PropertyKey.enabled)
        
        // Must Call designated initializer
        self.init(vpnName: name, vpnIP: ip, vpnPort: port, enabled: enabled)
    }
}
