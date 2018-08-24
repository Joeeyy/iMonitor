//
//  ViewController.swift
//  testVPN
//
//  Created by Joe Liu on 2018/8/21.
//  Copyright © 2018年 NUDT. All rights reserved.
//

/*
 1. 添加VPN配置
 2. 读取VPN配置
 3. 启动VPN配置
 4. 停止VPN配置
 5. 修改VPN配置（可选）
 6. 删除VPN配置（可选）
 */

import UIKit

import NetworkExtension
import testVPNServices

class ViewController: UIViewController {
    let TAG = "<AINASSINE> ViewController: "
    
    // </ VPN related stuffs
    var VPNManagers = [NEVPNManager]()
    var VPNManager: NEVPNManager = NEVPNManager.shared()
    
    let VPNName = "simpleTunnelVPN2"
    let serverAddr = "192.168.43.137"
    let serverPort = "6668"
    // VPN related stuffs />
    
    // </ UIs for test utility
    @IBOutlet var debugConsole: UITextView!
    
    @IBAction func loadBtn(_ sender: Any) {
        getVPNConfiguration()
        debugConsoleLog( log: "[ACTION!] Load Button is pressed, getting configurations as follows: \n")
        var counter = 0
        var tmpserverName = ""
        var tmpserverAddr = ""
        for manager in VPNManagers{
            counter = counter + 1
            tmpserverName = manager.localizedDescription!
            tmpserverAddr = (manager.protocolConfiguration?.serverAddress)!
            debugConsoleLog( log: "[VPN Configuration \(counter)] \(tmpserverName) \n")
            debugConsoleLog( log: "[VPN Configuration \(counter)] \(tmpserverAddr) \n")
        }
    }
    
    @IBAction func addBtn(_ sender: Any) {
        addVPNConfiguration()
        debugConsoleLog( log: "[ACTION!] Add Button is pressed, adding a configuration as follows: \n")
        debugConsoleLog( log: "[VPN Name ] \(self.VPNName) \n")
        debugConsoleLog( log: "[VPN Server] \(self.serverAddr+":"+self.serverPort) \n")
    }
    
    @IBAction func deleteBtn(_ sender: Any) {
        debugConsoleLog( log: "[ACTION!] Delete Button is pressed, deleting the last configuration as follows: \n")
        let numOfVPNs = VPNManagers.count
        let deleteIndex = numOfVPNs - 1
        let deleteManager = VPNManagers[deleteIndex]
        let deleteVPNName = deleteManager.localizedDescription
        let deleteVPNServer = deleteManager.protocolConfiguration?.serverAddress
        deleteVPNConfiguration(manager: VPNManagers[deleteIndex])
        debugConsoleLog( log: "[VPN Name ] \(String(describing: deleteVPNName)) \n")
        debugConsoleLog( log: "[VPN Server] \(String(describing: deleteVPNServer)) \n")
    }
    
    @IBAction func enableBtn(_ sender: Any) {
        debugConsoleLog( log: "[ACTION!] Enable Button is pressed, enabling the first configuration as follows: \n")
        if VPNManagers.count != 0{
            enableVPN(manager: VPNManagers[0])
            debugConsoleLog( log: "[VPN Name ] \(self.VPNName) \n")
            debugConsoleLog( log: "[VPN Server] \(self.serverAddr+":"+self.serverPort) \n")
        }
        else{
            debugConsoleLog( log: "[WARNING!] There's no vpn configuration, cannot enable anyone. \n")
        }
    }
    
    @IBAction func startBtn(_ sender: Any) {
        debugConsoleLog( log: "[ACTION!] Start Button is pressed, starting the first configuration as follows: \n")
        if VPNManagers.count != 0{
            startVPN(manager: VPNManagers[0])
            debugConsoleLog( log: "[VPN Name ] \(self.VPNName) \n")
            debugConsoleLog( log: "[VPN Server] \(self.serverAddr+":"+self.serverPort) \n")
        }
        else{
            debugConsoleLog( log: "[WARNING!] There's no vpn configuration, cannot start anyone. \n")
        }
    }
    
    @IBAction func stopBtn(_ sender: Any) {
        debugConsoleLog( log: "[ACTION!] Stop Button is pressed, stopping the first configuration as follows: \n")
        if VPNManagers.count != 0{
            stopVPN(manager: VPNManagers[0])
            debugConsoleLog( log: "[VPN Name ] \(self.VPNName) \n")
            debugConsoleLog( log: "[VPN Server] \(self.serverAddr+":"+self.serverPort) \n")
        }
        else{
            debugConsoleLog( log: "[WARNING!] There's no vpn configuration, cannot stop anyone. \n")
        }
    }
    // UIs for test utility />

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        debugConsoleLog( log: "[ATTENSION!] This is DEBUG CONSOLE for testVPN APP \n")
        debugConsoleLog( log: "[ATTENSION!] For test purpose, actions should be conducted with a certian sequence. \n")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // Used to add VPN configuraion, still at the test phase
    func addVPNConfiguration(){
        // Make configuration
        let manager = NETunnelProviderManager()
        manager.localizedDescription = VPNName
        manager.protocolConfiguration = NETunnelProviderProtocol()
        manager.protocolConfiguration?.serverAddress = serverAddr+":"+serverPort
        VPNManager = manager
        // Save the configuration
        VPNManager.saveToPreferences() { error in
            if error != nil{
                print(self.TAG+"Saving VPN configuraion failed. \(String(describing: error))")
                return
            }
            print(self.TAG+"Saving VPN configuration successfully!")
        }
    }
    
    // Used to get VPN configurations, still at the test phase
    func getVPNConfiguration(){
        NETunnelProviderManager.loadAllFromPreferences() { managers, error in
            CFRunLoopStop(CFRunLoopGetMain())
            guard let tmpVPNManagers = managers else {
                return
            }
            self.VPNManagers = tmpVPNManagers
            print(self.TAG+"we have \(self.VPNManagers.count) vpn configurations in total")
        }
        CFRunLoopRun()
    }
    
    // Used to modify VPN configuration, still not implemented
    func setVPNConfiguration(){
        
    }
    
    // Used to delete a certain VPN configuration, still at the test phase
    func deleteVPNConfiguration(manager: NEVPNManager){
        manager.removeFromPreferences(){ error in
            if error != nil {
                print(self.TAG+"remove VPN configuration \(String(describing: manager.localizedDescription)) failed. \(String(describing: error))")
                return
            }
            print(self.TAG+"remove VPN configuration successfully!")
        }
    }
    
    // Used to enable a certain VPN, still at the test phase
    func enableVPN(manager: NEVPNManager){
        VPNManager = manager
        VPNManager.isEnabled = true
        VPNManager.saveToPreferences() { error in
            if error != nil {
                self.VPNManager.isEnabled = false
                print(self.TAG+"enable vpn failed.\(String(describing: error))")
            }
            print(self.TAG+"enable vpn succeeded!")
        }
    }
    
    // Used to start a certain VPN, still at the test phase
    func startVPN(manager: NEVPNManager){
        if manager.isEnabled {
            do {
                try manager.connection.startVPNTunnel()
                print("VPN started!")
            }
            catch{
                print("failed while starting vpn")
            }
        }else{
            print("this vpn manager is not enabled, please enable it at first.")
        }
    }
    
    // Used to stop a certain VPN, still at the test phase
    func stopVPN(manager: NEVPNManager){
        if manager.connection.status == .connected{
            manager.connection.stopVPNTunnel()
        }else{
            print("this vpn is not connected, cannot stop it.")
        }
    }
    
    func debugConsoleLog(log: String){
        debugConsole.text.append(log)
        debugConsole.scrollRangeToVisible(debugConsole.selectedRange)
    }
}

