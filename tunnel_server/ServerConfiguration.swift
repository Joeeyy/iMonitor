/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This file contains the ServerConfiguration class. The ServerConfiguration class is used to parse the SimpleTunnel server configuration.
 */

import Foundation
import SystemConfiguration

/// An object containing configuration settings for the SimpleTunnel server.
class ServerConfiguration {
    
    // MARK: Properties
    
    /// A dictionary containing configuration parameters.
    var configuration: [String: Any]
    
    /// A pool of IP addresses to allocate to clients.
    var addressPool: AddressPool?
    
    // MARK: Initializers
    
    init() {
        configuration = [String: Any]()
        addressPool = nil
    }
    
    // MARK: Interface
    
    /// Read the configuration settings from a plist on disk.
    func loadFromFileAtPath(path: String) -> Bool {
        
        guard let fileStream = InputStream(fileAtPath: path) else {
            testVPNLog("Failed to open \(path) for reading")
            return false
        }
        
        fileStream.open()
        
        var newConfiguration: [String: Any]
        do {
            newConfiguration = try PropertyListSerialization.propertyList(with: fileStream, options: .mutableContainers, format: nil) as! [String: Any]
        }
        catch {
            testVPNLog("Failed to read the configuration from \(path): \(error)")
            return false
        }
        
        guard let startAddress = getValueFromPlist(newConfiguration as [NSObject : AnyObject], keyArray: [.IPv4, .Pool, .StartAddress]) as? String else {
            testVPNLog("Missing v4 start address")
            return false
        }
        guard let endAddress = getValueFromPlist(newConfiguration as [NSObject : AnyObject], keyArray: [.IPv4, .Pool, .EndAddress]) as? String else {
            testVPNLog("Missing v4 end address")
            return false
        }
        
        addressPool = AddressPool(startAddress: startAddress, endAddress: endAddress)
        
        // The configuration dictionary gets sent to clients as the tunnel settings dictionary. Remove the IP pool parameters.
        if let value = newConfiguration[SettingsKey.IPv4.rawValue] as? [NSObject: Any] {
            var IPv4Dictionary = value
            
            IPv4Dictionary.removeValue(forKey: SettingsKey.Pool.rawValue as NSObject)
            newConfiguration[SettingsKey.IPv4.rawValue] = IPv4Dictionary as Any?
        }
        
        if !newConfiguration.keys.contains(where: { $0 == SettingsKey.DNS.rawValue }) {
            // The configuration does not specify any DNS configuration, so get the current system default resolver.
            let (DNSServers, DNSSearchDomains) = ServerConfiguration.copyDNSConfigurationFromSystem()
            
            newConfiguration[SettingsKey.DNS.rawValue] = [
                SettingsKey.Servers.rawValue: DNSServers,
                SettingsKey.SearchDomains.rawValue: DNSSearchDomains
            ]
        }
        
        configuration = newConfiguration
        
        return true
    }
    
    /// Copy the default resolver configuration from the system on which the server is running.
    class func copyDNSConfigurationFromSystem() -> ([String], [String]) {
        let globalDNSKey = SCDynamicStoreKeyCreateNetworkGlobalEntity(kCFAllocatorDefault, kSCDynamicStoreDomainState, kSCEntNetDNS)
        var DNSServers = [String]()
        var DNSSearchDomains = [String]()
        
        // The default resolver configuration can be obtained from State:/Network/Global/DNS in the dynamic store.
        
        if let globalDNS = SCDynamicStoreCopyValue(nil, globalDNSKey) as? [NSObject: AnyObject],
            let servers = globalDNS[kSCPropNetDNSServerAddresses as NSString] as? [String]
        {
            if let searchDomains = globalDNS[kSCPropNetDNSSearchDomains as NSString] as? [String] {
                DNSSearchDomains = searchDomains
            }
            DNSServers = servers
        }
        
        return (DNSServers, DNSSearchDomains)
    }
}
