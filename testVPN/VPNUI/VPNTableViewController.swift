//
//  VPNTableViewController.swift
//  testVPN
//
//  Created by Joe Liu on 2018/9/15.
//  Copyright © 2018年 NUDT. All rights reserved.
//

/*
 Main UI of this app.
 */

import UIKit
import NetworkExtension
import testVPNServices
import AdSupport

class VPNTableViewController: UITableViewController {
    
    // MARK: Properties
    
    var app_vpn: NEVPNManager?
    
    var database: Database!

    override func viewDidLoad() {
        super.viewDidLoad()

        // database settings
        
        // create database
        database = Database()
        database.tableNETWORKFLOWLOGCreate()
        database.tableAPPCONFIGCreate()
        
        // to get certain about IP address of this device
        let idfa = ASIdentifierManager.shared()?.advertisingIdentifier
        
        let params: NSMutableDictionary = NSMutableDictionary()
        params["idfa"] = idfa?.uuidString
        var jsonData:NSData? = nil
        do {
            jsonData  = try JSONSerialization.data(withJSONObject: params, options:JSONSerialization.WritingOptions.prettyPrinted) as NSData
        } catch {
        }
        
        postRequest(url: "http://119.23.215.159/test/checkin/checkin.php", jsonData: jsonData) { retStr in
            do{
                //if let json = try JSONSerialization.jsonObject(with: retStr.data, options: []) as? NSDictionary {
                //    self.database.tableAPPCONFIGInsertItem(key: "ip", value: json.value(forKey: "ip") as! String)
                //}
                if let json = try JSONSerialization.jsonObject(with: retStr as! Data, options: []) as? NSDictionary {
                    let lastIP = self.database.tableAPPCONFIGQueryItem(key: "ip")
                    if lastIP == nil {
                        self.database.tableAPPCONFIGInsertItem(key: "ip", value: json.value(forKey: "ip") as! String)
                    }else if lastIP == json.value(forKey: "ip") as? String{
                        // do nothing
                    }else {
                        self.database.tableAPPCONFIGUpdateItem(key: "ip", value: json.value(forKey: "ip") as! String)
                    }
                }
            }
            catch{
                
            }
        }
        
        
        // load vpn configurations
        loadAppVPNCongigurations()
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // remove notification of vpn status
        // NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // return the number of sections
        
        // section 1 for control
        // section 2 for meal list
        
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // return the number of rows
        if section == 0 { // for control section
            return 1
        }
        else if section == 1 { // for meal list section
            return 1
        }
        else {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath == [0,0] {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "switchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                fatalError("Error creating a SwitchTableViewCell.")
            }
            cell.toggle.addTarget(self, action: #selector(self.startStopVPN), for: .allTouchEvents)
            cell.toggle.isOn = app_vpn?.connection.status == .connected
            if app_vpn?.connection.status == .connected{
                cell.startLabel.text = "Connected"
            }else if app_vpn?.connection.status == .disconnected{
                cell.startLabel.text = "Disconnected"
            }else if app_vpn?.connection.status == .disconnecting{
                cell.startLabel.text = "Disconnecting"
            }else if app_vpn?.connection.status == .connecting{
                cell.startLabel.text = "Connecting"
            }
            
            return cell
        }
        else if indexPath == [1,0] { // 1st item of menu list, vpn
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "imageLabelCell", for: indexPath) as? ImageLabelTableViewCell else {
                fatalError("Error creating an ImageLabelTableViewCell.")
            }
            cell.label.text = "VPN Configurations"
            cell.label.textColor = UIColor.gray
            cell.accessoryType = .disclosureIndicator
            
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        // Configure the cell...

        return cell
    }
    
    // MARK: Actions
    
    // load all vpn configurations from shared property
    func loadAppVPNCongigurations(){
        NETunnelProviderManager.loadAllFromPreferences() { vpnManagers, _ in
            
            guard let tmpVPNManagers = vpnManagers else {
                return
            }
            
            if tmpVPNManagers.count != 0 {
                (self.tableView.cellForRow(at: [0,0]) as? SwitchTableViewCell)?.toggle.isEnabled = true
                self.app_vpn = tmpVPNManagers.first!
                // notification of vpn status
                NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: self.app_vpn?.connection, queue: OperationQueue.main, using: { notification in
                    guard let toggleCell = self.tableView.cellForRow(at: [0,0]) as? SwitchTableViewCell else {
                        fatalError()
                    }
                    if self.app_vpn!.connection.status == .connected {
                        toggleCell.startLabel.text = "Connected"
                        toggleCell.toggle.isOn = true
                    }
                    else if self.app_vpn!.connection.status == .disconnected || !self.app_vpn!.isEnabled{
                        toggleCell.startLabel.text = "Disconnected"
                        toggleCell.toggle.isOn = false
                    }
                    else if self.app_vpn?.connection.status == .connecting {
                        toggleCell.startLabel.text = "Connecting"
                        toggleCell.toggle.isOn = false
                    }
                    else if self.app_vpn?.connection.status == .disconnecting {
                        toggleCell.startLabel.text = "Disconnecting"
                        toggleCell.toggle.isOn = true
                    }
                })
            } else {
                self.app_vpn = nil
                (self.tableView.cellForRow(at: [0,0]) as? SwitchTableViewCell)?.toggle.isEnabled = false
            }
            self.tableView.reloadData()
        }
    }
    
    // start or stop vpn
    @IBAction func startStopVPN() {
        if app_vpn?.isEnabled == false{
            app_vpn?.isEnabled = true
            app_vpn?.saveToPreferences(){ error in
                if error != nil {
                    self.app_vpn?.isEnabled = false
                    (self.tableView.cellForRow(at: [0,0]) as? SwitchTableViewCell)?.toggle.isOn = false
                }
                self.startStopAfterEnable()
            }
        }else{
            startStopAfterEnable()
        }
    }
    
    private func startStopAfterEnable(){
        if app_vpn?.connection.status == .disconnected {
            do{
                try self.app_vpn?.connection.startVPNTunnel()
            }catch {
                
            }
        }
        else if app_vpn?.connection.status == .connected {
            self.app_vpn?.connection.stopVPNTunnel()
        }
    }

    // MARK: - Navigation
    
    @IBAction func unwindToVPNTableView(_ sender: UIStoryboardSegue){
        self.viewDidLoad()
    }

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        
        switch segue.identifier ?? "" {
        case "showVPNConfigurationsTable":
            guard let dstVewController = segue.destination as? VPNConfigurationTableViewController else {
                fatalError("Error creating a VPNConfigurationTableViewController.")
            }
            if app_vpn != nil {
                dstVewController.inited = true
                dstVewController.app_vpn = self.app_vpn
            }
            else {
                dstVewController.inited = false
            }
        default:
            fatalError("unexpected segue id: \(segue.identifier)")
        }
    }

}
