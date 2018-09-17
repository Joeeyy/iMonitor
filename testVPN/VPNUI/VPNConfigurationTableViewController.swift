//
//  VPNConfigurationTableViewController.swift
//  testVPN
//
//  Created by Joe Liu on 2018/9/15.
//  Copyright © 2018年 NUDT. All rights reserved.
//

/*
 UI to show all configurations of vpn
 */

import UIKit
import NetworkExtension

class VPNConfigurationTableViewController: UITableViewController {
    
    // MARK: Properties
    
    var app_vpn: NEVPNManager?
    var vpnConfigurations = [VPNConfiguration]()
    var enabledIndex = -1
    var inited = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "back", style: UIBarButtonItemStyle.plain, target: self, action: #selector(self.returnToVPNTableView(_:)))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: UIBarButtonItemStyle.plain, target: self, action: #selector(self.addVPNDetail(_:)))
        self.navigationItem.rightBarButtonItem?.isEnabled = inited
        
        if let savedVPNConfigurations = loadVPNConfigurations() {
            vpnConfigurations += savedVPNConfigurations
            tableView.reloadData()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if !inited {
            return 1
        }else {
            return vpnConfigurations.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if !inited {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "buttonTableViewCell", for: indexPath) as? ButtonTableViewCell else{
                fatalError("error creating a ButtonTableViewCell.")
            }
            cell.button.titleLabel?.text = "Add new configuration"
            
            return cell
        }
        
        let tmpVPNConf = vpnConfigurations[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "nameValueTableViewCell", for: indexPath) as? NameValueTableViewCell else {
            fatalError("error creating a NameValueTableViewCell.")
        }
        if vpnConfigurations[indexPath.row].enabled {
            cell.nameLabel.text = "✔️"
            enabledIndex = indexPath.row
        }else{
            cell.nameLabel.text = ""
        }
        cell.valueTextField.text = "\(tmpVPNConf.VPNIP):\(tmpVPNConf.VPNPort)"
        cell.valueTextField.isEnabled = false
        cell.accessoryType = .detailButton
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if enabledIndex == indexPath.row {
            return
        }
        
        let lastEnabledIndex = enabledIndex
        enabledIndex = indexPath.row
        saveVPNConfigurationChanges(vpnConfiguration: vpnConfigurations[enabledIndex], vpnManager: app_vpn!)
        vpnConfigurations[enabledIndex].enabled = true
        tableView.reloadRows(at: [indexPath], with: .automatic)
        
        if lastEnabledIndex >= 0 {
            vpnConfigurations[lastEnabledIndex].enabled = false
            tableView.reloadRows(at: [[0,lastEnabledIndex]], with: .automatic)
        }
        
        saveVPNConfigurations()
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition.none)
    }
    
    // MARK: Actions
    
    // show vpn detail
    @IBAction func addVPNDetail(_ sender: Any?){
        performSegue(withIdentifier: "addVPNDetail", sender: sender)
    }
    
    // return to vpn table view
    @IBAction func returnToVPNTableView(_ sender: Any?) {
        performSegue(withIdentifier: "unwindToVPNTableView", sender: sender)
    }
    
    // load vpn configurations
    private func loadVPNConfigurations() -> [VPNConfiguration]?{
        //return NSKeyedUnarchiver.unarchiveObject(withFile: Meal.ArchiveURL.path) as? [Meal]
        return NSKeyedUnarchiver.unarchiveObject(withFile: VPNConfiguration.ArchiveURL.path) as? [VPNConfiguration]
    }
    
    // save vpn configurations on the disk
    private func saveVPNConfigurations(){
        let isSuccessfullySaved = NSKeyedArchiver.archiveRootObject(vpnConfigurations, toFile: VPNConfiguration.ArchiveURL.path)
        
        if isSuccessfullySaved {
            NSLog("vpn confiugrations successfully saved")
        }else {
            NSLog("vpn configurations failed to save.")
        }
    }
    
    // save to app's vpn
    private func saveVPNConfigurationChanges(vpnConfiguration: VPNConfiguration, vpnManager: NEVPNManager){
        vpnManager.protocolConfiguration?.serverAddress = "\(vpnConfiguration.VPNIP):\(vpnConfiguration.VPNPort)"
        vpnManager.saveToPreferences() { error in
            if error != nil{
                fatalError("Error occurred while adding configuration, please check your settings.")
            }
        }
    }
    
    private func deleteAppVPN(){
        app_vpn!.removeFromPreferences() { error in
            if error != nil {
                
            }
            //self.navigationController?.popViewController(animated: true)
            self.app_vpn = nil
        }
    }
    
    // MARK: - Navigation
    
    // unwind back to this view
    @IBAction func unwindToConfigurationTableView(_ sender: UIStoryboardSegue) {
        if let srcViewController = sender.source as? VPNDetailTableViewController, let vpn = srcViewController.vpn {
            if let selectedIndexPath = tableView.indexPathForSelectedRow{
                // if delete mode
                if srcViewController.delete {
                    vpnConfigurations.remove(at: selectedIndexPath.row)
                    
                    if vpnConfigurations.count == 0 {
                        // if selected item is last vpn
                        self.inited = false
                        deleteAppVPN()
                    }
                    else if vpn.enabled {
                        // if selected item is enabled
                        vpnConfigurations.first?.enabled = true
                        saveVPNConfigurationChanges(vpnConfiguration: vpnConfigurations.first!, vpnManager: app_vpn!)
                    }
                    // if selected item is just a common vpn
                    
                    tableView.reloadData()
                }else{
                    // Update an existing vpn
                    vpnConfigurations[selectedIndexPath.row] = vpn
                    tableView.reloadRows(at: [selectedIndexPath], with: .none)
                    if vpn.enabled {
                        // modify app's vpn
                        saveVPNConfigurationChanges(vpnConfiguration: vpn, vpnManager: app_vpn!)
                    }
                }
            }
            else{
                // Add a new vpn
                if let fisrtCell = tableView.cellForRow(at: [0,0]) as? ButtonTableViewCell {
                    tableView.deleteRows(at: [[0,0]], with: .automatic)
                    NETunnelProviderManager.loadAllFromPreferences(){ vpns, _ in
                        guard let tmpVPNs = vpns else {
                            fatalError()
                        }
                        self.app_vpn = tmpVPNs.first
                    }
                }
                let newIndexPath = IndexPath(row: vpnConfigurations.count, section: 0)
                vpnConfigurations.append(vpn)
                tableView.insertRows(at: [newIndexPath], with: .automatic)
                self.navigationItem.rightBarButtonItem?.isEnabled = true
            }
            
            // Save the vpns
            saveVPNConfigurations()
        }
    }

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        
        switch segue.identifier ?? "" {
        case "initAddVPNDetail":
            guard let dstViewController = segue.destination as? VPNDetailTableViewController else{
                fatalError("get VPNDetailTableViewController failed.")
            }
            dstViewController.addMode = true
            dstViewController.inited = false
        case "addVPNDetail":
            guard let dstViewController = segue.destination as? VPNDetailTableViewController else{
                fatalError("get VPNDetailTableViewController failed.")
            }
            dstViewController.addMode = true
            dstViewController.inited = true
        case "showVPNDetail":
            // dst view controller
            guard let dstViewController = segue.destination as? VPNDetailTableViewController else{
                fatalError("get VPNDetailTableViewController failed.")
            }
            // selected item
            guard let selectedItem = sender as? NameValueTableViewCell else {
                fatalError("unexpected sender: \(sender)")
            }
            // selected item index
            guard let indexPath = tableView.indexPath(for: selectedItem) else {
                fatalError("The selected cell is not being displayed anymore")
            }
            let selectedVPN = vpnConfigurations[indexPath.row]
            
            dstViewController.addMode = false
            dstViewController.inited = true
            dstViewController.vpn = selectedVPN
        case "unwindToVPNTableView":
            print("do nothing")
        default:
            print("unhandled segue identifier: \(segue.identifier)")
        }
    }

}
