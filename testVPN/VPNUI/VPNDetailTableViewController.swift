//
//  VPNDetailTableViewController.swift
//  testVPN
//
//  Created by Joe Liu on 2018/9/16.
//  Copyright © 2018年 NUDT. All rights reserved.
//

/*
 UI to show the detail of a vpn, or to add a vpn configuration
 */

import UIKit
import NetworkExtension

class VPNDetailTableViewController: UITableViewController, UITextFieldDelegate {
    
    // MARK: Properties
    
    var addMode: Bool = true
    var inited: Bool = true
    var vpn: VPNConfiguration?
    
    var ipNotNil = false
    var portNotNil = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        if addMode{
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.save, target: self, action: #selector(self.saveVPNCongfiguration(_:)))
            self.navigationItem.rightBarButtonItem?.isEnabled = false
        }
        else {
            
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
        if addMode {
            return 3
        }
        else{
            return 4
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath == [0,0] {
            // vpn name
            let cell = createNameValueCell("Name", indexPath)
            return cell
        }
        else if indexPath == [0,1] {
            // vpn ip
            let cell = createNameValueCell("IP", indexPath)
            return cell
        }
        else if indexPath == [0,2] {
            // vpn port
            let cell = createNameValueCell("Port", indexPath)
            return cell
        }
        else {
            // that god damn button, for delete purpose
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "buttonTableViewCell", for: indexPath) as? ButtonTableViewCell else {
                fatalError("Error creating a ButtonTableViewCell. ")
            }
            cell.button.setTitle("Delete VPN Configuration", for: UIControlState.normal)
            cell.button.setTitleColor(UIColor.red, for: UIControlState.normal)
            
            return cell
        }
    }
    
    // to deal with repeated work of creating cell
    private func createNameValueCell(_ name: String, _ indexPath: IndexPath) -> UITableViewCell{
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "nameValueTableViewCell", for: indexPath) as? NameValueTableViewCell else {
            fatalError("Error creating a NameValueTableViewCell. ")
        }
        cell.nameLabel.text = name
        if !addMode {
            cell.valueTextField.isEnabled = false
            switch name {
            case "Name":
                cell.valueTextField.text = self.vpn?.VPNName
            case "IP":
                cell.valueTextField.text = self.vpn?.VPNIP
            case "Port":
                cell.valueTextField.text = self.vpn?.VPNPort
            default:
                NSLog("Unexpected name label")
            }
        }
        
        cell.valueTextField.addTarget(self, action: #selector(self.textChange(textField:)), for: .editingChanged)
        cell.valueTextField.addTarget(self, action: #selector(self.textFieldTapped(textField:)), for: .editingDidBegin)
        if indexPath.row == 2 {
            cell.valueTextField.returnKeyType = .done
        }else {
            cell.valueTextField.returnKeyType = .next
        }
        
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
    
    // MARK: TextFieldDelegate
    
    // textField return button pressed
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == (tableView.cellForRow(at: [0,0]) as? NameValueTableViewCell)?.valueTextField { // name finished, next item
            (tableView.cellForRow(at: [0,1]) as? NameValueTableViewCell)?.valueTextField.delegate = self
            (tableView.cellForRow(at: [0,1]) as? NameValueTableViewCell)?.valueTextField.becomeFirstResponder()
        }
        else if textField == (tableView.cellForRow(at: [0,1]) as? NameValueTableViewCell)?.valueTextField { // IP finished, next item
            (tableView.cellForRow(at: [0,2]) as? NameValueTableViewCell)?.valueTextField.delegate = self
            (tableView.cellForRow(at: [0,2]) as? NameValueTableViewCell)?.valueTextField.becomeFirstResponder()
        }
        else if textField == (tableView.cellForRow(at: [0,2]) as? NameValueTableViewCell)?.valueTextField { // Port finished, done
            textField.resignFirstResponder()
        }
        
        return true
    }
    
    // text change
    @IBAction func textChange( textField: UITextField){
        if textField == (tableView.cellForRow(at: [0,1]) as? NameValueTableViewCell)?.valueTextField{
            
            if textField.text == "" {
                ipNotNil = false
            }
            else {
                ipNotNil = true
            }
        }else if textField == (tableView.cellForRow(at: [0,2]) as? NameValueTableViewCell)?.valueTextField{
            if textField.text == "" {
                ipNotNil = false
            }
            else {
                ipNotNil = true
            }
        }
        
        // check if save button should be enabled
        if(shouldSaveButtonEnbled()){
            self.navigationItem.rightBarButtonItem?.isEnabled = true
        }
        else{
            self.navigationItem.rightBarButtonItem?.isEnabled = false
        }
    }
    
    // text field is tapped
    @IBAction func textFieldTapped(textField: UITextField){
        textField.delegate = self
        textField.becomeFirstResponder()
    }
    
    // check should save button in add mode be enabled
    private func shouldSaveButtonEnbled() -> Bool {
        //check ip
        if (tableView.cellForRow(at: [0,1]) as? NameValueTableViewCell)?.valueTextField.text == "" {
            ipNotNil = false
        }
        else {
            ipNotNil = true
        }
        // check port
        if (tableView.cellForRow(at: [0,2]) as? NameValueTableViewCell)?.valueTextField.text == "" {
            portNotNil = false
        }
        else {
            portNotNil = true
        }
        
        return ipNotNil && portNotNil
    }

    
    
    // MARK: Actions
    
    // window to alert an error
    func alertError(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default) { action in
        }
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func unwind(_ sender: Any?){
        print("ABC")
        performSegue(withIdentifier: "unwindToConfigurationTableView", sender: sender)
    }
    
    @IBAction func saveVPNCongfiguration(_ sender: Any){
    //private func saveVPNConfiguration(){
        let name = (tableView.cellForRow(at: [0,0]) as? NameValueTableViewCell)?.valueTextField.text
        let ip = (tableView.cellForRow(at: [0,1]) as? NameValueTableViewCell)?.valueTextField.text
        let port = (tableView.cellForRow(at: [0,2]) as? NameValueTableViewCell)?.valueTextField.text
        
        let vpnConfiguration = VPNConfiguration(vpnName: name!, vpnIP: ip!, vpnPort: port!, enabled: inited ? true : false)
        if vpnConfiguration.checkIPFormat() && vpnConfiguration.checkPortFormat(){
            //saveVPNConfiguration(vpnConfiguration: vpnConfiguration)
            //vpns.append(vpnConfiguration)
            //self.navigationController?.popViewController(animated: true)
            self.vpn = vpnConfiguration
            if !inited{
                saveVPNConfiguration(vpnConfiguration: self.vpn!)
            }
            performSegue(withIdentifier: "unwindToConfigurationTableView", sender: sender)
        }else{
            let alert = UIAlertController(title: "Error", message: "Save VPN configuration failed, please check ip and port format.", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default) {action in
                
            }
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func saveVPNConfiguration(vpnConfiguration: VPNConfiguration){
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "testVPN"
        manager.protocolConfiguration = NETunnelProviderProtocol()
        manager.protocolConfiguration?.serverAddress = "\(vpnConfiguration.VPNIP):\(vpnConfiguration.VPNPort)"
        manager.saveToPreferences() { error in
            if error != nil {
                // error occurred while saving vpn configuration successfully
                self.alertError("Error occurred while adding configuration, please check your settings.")
            }
            // saving vpn configuration successfully
            let alert = UIAlertController(title: "Success", message: "Add VPN Configuration succeeded!", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default) { action in
                self.navigationController?.popViewController(animated: true)
            }
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
        }
    }
    

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        super.prepare(for: segue, sender: sender)
        
        // configure the destination view controller only when the save button is pressed
        switch segue.identifier ?? "" {
        case "unwindToConfigurationTableView":
            guard let dstViewController = segue.destination as? VPNConfigurationTableViewController else {
                fatalError("wrong dst view controller")
            }
            dstViewController.inited = true
        default:
            fatalError("unexpected segue: \(segue.identifier)")
        }
    }

}
