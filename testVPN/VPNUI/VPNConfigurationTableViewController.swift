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
    
    var app_vpns = [NEVPNManager]()
    var vpnConfigurations = [VPNConfiguration]()
    var enabledIndex = -1
    var enabledVPN = NEVPNManager.shared()
    var inited = false

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: UIBarButtonItemStyle.done, target: self, action: #selector(self.addVPNDetail(_:)))
        if !inited {
            self.navigationItem.rightBarButtonItem?.isEnabled = false
        }
        
        loadAppVPNCongigurations()
        if let savedVPNConfigurations = loadVPNConfigurations() {
            vpnConfigurations += savedVPNConfigurations
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
        cell.nameLabel.text = ""
        cell.valueTextField.text = "\(tmpVPNConf.VPNIP):\(tmpVPNConf.VPNPort)"
        cell.valueTextField.isEnabled = false
        
        return cell
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    // MARK: Actions
    
    // show vpn detail
    @IBAction func addVPNDetail(_ sender: Any?){
        performSegue(withIdentifier: "addVPNDetail", sender: sender)
    }
    
    // load all vpn configurations from shared property
    func loadAppVPNCongigurations(){
        NETunnelProviderManager.loadAllFromPreferences() { vpnManagers, _ in
            
            guard let tmpVPNManagers = vpnManagers else {
                return
            }
            
            self.app_vpns = tmpVPNManagers
            if self.app_vpns.count != 0 {
                self.inited = true
            }
            self.tableView.reloadData()
        }
    }
    
    // load vpn configurations
    private func loadVPNConfigurations() -> [VPNConfiguration]?{
        //return NSKeyedUnarchiver.unarchiveObject(withFile: Meal.ArchiveURL.path) as? [Meal]
        return NSKeyedUnarchiver.unarchiveObject(withFile: VPNConfiguration.ArchiveURL.path) as? [VPNConfiguration]
    }
    
    // save vpn configurations
    private func saveVPNConfigurations(){
        let isSuccessfullySaved = NSKeyedArchiver.archiveRootObject(vpnConfigurations, toFile: VPNConfiguration.ArchiveURL.path)
        
        if isSuccessfullySaved {
            NSLog("vpn confiugrations successfully saved")
        }else {
            NSLog("vpn configurations failed to save.")
        }
    }
    
    
    // MARK: - Navigation
    
    // unwind back to last view
    @IBAction func unwindToConfigurationTableView(_ sender: UIStoryboardSegue) {
        if let srcViewController = sender.source as? VPNDetailTableViewController, let vpn = srcViewController.vpn {
            if let selectedIndexPath = tableView.indexPathForSelectedRow{
                // Update an existing Meal
                vpnConfigurations[selectedIndexPath.row] = vpn
                tableView.reloadRows(at: [selectedIndexPath], with: .none)
            }
            else{
                // Add a new meal
                if let fisrtCell = tableView.cellForRow(at: [0,0]) as? ButtonTableViewCell {
                    tableView.deleteRows(at: [[0,0]], with: .automatic)
                }
                let newIndexPath = IndexPath(row: vpnConfigurations.count, section: 0)
                vpnConfigurations.append(vpn)
                tableView.insertRows(at: [newIndexPath], with: .automatic)
                self.navigationItem.rightBarButtonItem?.isEnabled = true
            }
            
            // Save the meals
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
        default:
            print("unhandled segue identifier: \(segue.identifier)")
        }
    }

}
