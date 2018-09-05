/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This file contains the AddressPool class. The AddressPool class is used to manage a pool of IP addresses.
 AddressPool 类，用于管理IP地址池。
 */

import Foundation

/// An object that contains a pool of IP addresses to assign to tunnel clients.
class AddressPool {
    
    // MARK: Properties
    private let TAG = "AddressPool: "
    
    /// The start address of the pool.
    let baseAddress: SocketAddress
    
    /// The number of addresses in the pool.
    var size: UInt64 = 0
    
    /// A list of flags indicating which addresses in the pool are currently allocated to clients.
    var inUseMask: [Bool]
    
    /// A dispatch queue for serializing access to the pool.
    let queue: DispatchQueue
    
    // MARK: Initializers
    
    init(startAddress: String, endAddress: String) {
        testVPNLog(self.TAG + "initializing AddressPool, startAddress: \(startAddress), endAddress: \(endAddress)")
        baseAddress = SocketAddress()
        inUseMask = [Bool](repeating: false, count: 0)
        queue = DispatchQueue(label: "AddressPoolQueue")
        
        let start = SocketAddress()
        let end = SocketAddress()
        
        // Verify that the address pool is specified correctly.
        
        guard start.setFromString(startAddress) &&
            end.setFromString(endAddress) &&
            start.sin.sin_family == end.sin.sin_family
            else { return }
        
        guard start.sin.sin_family == sa_family_t(AF_INET) else {
            testVPNLog(self.TAG + "IPv6 is not currently supported")
            return
        }
        guard (start.sin.sin_addr.s_addr & 0xffff) == (end.sin.sin_addr.s_addr & 0xffff) else {
            testVPNLog(self.TAG + "start address (\(startAddress)) is not in the same class B network as end address (\(endAddress)) ")
            return
        }
        
        let difference = end.difference(start)
        guard difference >= 0 else {
            testVPNLog(self.TAG + "start address (\(startAddress)) is greater than end address (\(endAddress))")
            return
        }
        
        baseAddress.sin = start.sin
        size = UInt64(difference)
        inUseMask = [Bool](repeating: false, count: Int(size))
    }
    
    /// Allocate an address from the pool.
    func allocateAddress() -> String? {
        testVPNLog(self.TAG + "TRY TO ALLOCATE IP ADDRESS")
        var result: String?
        
        queue.sync() {
            let address = SocketAddress(otherAddress: self.baseAddress)
            
            // Look for an address that is not currently allocated
            for (index, inUse) in self.inUseMask.enumerated() {
                if !inUse {
                    address.increment(UInt32(index))
                    self.inUseMask[index] = true
                    result = address.stringValue
                    break
                }
            }
        }
        
        testVPNLog(self.TAG + "Allocated address \(result)")
        return result
    }
    
    /// Deallocate an address in the pool.
    func deallocateAddress(addrString: String) {
        testVPNLog(self.TAG + "TRY TO DEALLOCATE IP ADDRESS \(addrString)")
        queue.sync() {
            let address = SocketAddress()
            
            guard address.setFromString(addrString) else { return }
            
            let difference = address.difference(self.baseAddress)
            if difference >= 0 && difference < Int64(self.inUseMask.count) {
                self.inUseMask[Int(difference)] = false
                testVPNLog(self.TAG + "Deallocate IP Address: \(addrString) finished.")
            }
        }
    }
}
