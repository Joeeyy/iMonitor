//
//  AppProxyProvider.swift
//  appProxy
//
//  Created by Joe Liu on 2018/8/22.
//  Copyright © 2018年 NUDT. All rights reserved.
//

import NetworkExtension

class AppProxyProvider: NEAppProxyProvider {

    override func startProxy(options: [String : Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
    }
    
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
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
    
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        // Add code here to handle the incoming flow.
        return false
    }
}
