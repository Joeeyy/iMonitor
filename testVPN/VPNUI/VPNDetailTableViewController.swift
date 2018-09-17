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
    var delete: Bool = false
    
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
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.edit, target: self, action: #selector(self.enterEditMode(_:)))
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
            cell.button.addTarget(self, action: #selector(self.deleteVPNConfiguration(_:)), for: UIControlEvents.touchUpInside)
            
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
    
    // save vpn configuration
    @IBAction func saveVPNCongfiguration(_ sender: Any){
    //private func saveVPNConfiguration(){
        let name = (tableView.cellForRow(at: [0,0]) as? NameValueTableViewCell)?.valueTextField.text
        let ip = (tableView.cellForRow(at: [0,1]) as? NameValueTableViewCell)?.valueTextField.text
        let port = (tableView.cellForRow(at: [0,2]) as? NameValueTableViewCell)?.valueTextField.text
        
        let vpnConfiguration = VPNConfiguration(vpnName: name!, vpnIP: ip!, vpnPort: port!, enabled: inited ? false : true)
        if vpnConfiguration.checkIPFormat() && vpnConfiguration.checkPortFormat(){
            self.vpn = vpnConfiguration
            if !inited{
                saveVPNConfiguration(vpnConfiguration: self.vpn!)
            }else{
                performSegue(withIdentifier: "unwindToConfigurationTableView", sender: sender)
            }
        }else{
            let alert = UIAlertController(title: "Error", message: "Save VPN configuration failed, please check ip and port format.", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default) {action in
                
            }
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // create an app vpn configuration
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
            
            self.performSegue(withIdentifier: "unwindToConfigurationTableView", sender: nil)
        }
    }
    
    // come into edit mode
    @IBAction func enterEditMode(_ sender: Any?) {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.cancel, target: self, action: #selector(self.cancelEdit(_:)))
        enableCellAt(indexPath: [0,0])
        enableCellAt(indexPath: [0,1])
        enableCellAt(indexPath: [0,2])
        enableCellAt(indexPath: [0,3])
    }
    
    private func enableCellAt(indexPath: IndexPath) {
        if indexPath == [0,3] {
            guard let cell = tableView.cellForRow(at: indexPath) as? ButtonTableViewCell else {
                fatalError("Error creating a NameValueTableViewCell.")
            }
            cell.button.setTitle("Save Changes", for: .normal)
            cell.button.setTitleColor(UIColor.blue, for: .normal)
            cell.button.removeTarget(self, action: #selector(self.deleteVPNConfiguration(_:)), for: UIControlEvents.touchUpInside)
            cell.button.addTarget(self, action: #selector(self.editVPNConfiguration(_:)), for: UIControlEvents.touchUpInside)
            
            return
        }
        
        guard let cell = tableView.cellForRow(at: indexPath) as? NameValueTableViewCell else {
            fatalError("Error creating a NameValueTableViewCell.")
        }
        cell.valueTextField.isEnabled = true
        if indexPath == [0,0] {
            cell.valueTextField.delegate = self
            cell.valueTextField.becomeFirstResponder()
        }
    }
    
    // cancel edition
    @IBAction func cancelEdit(_ sender: Any?) {
        guard let cell = tableView.cellForRow(at: [0,3]) as? ButtonTableViewCell else {
            fatalError("Error creating a NameValueTableViewCell.")
        }
        cell.button.removeTarget(self, action: #selector(self.editVPNConfiguration(_:)), for: UIControlEvents.touchUpInside)
        
        self.viewDidLoad()
        self.tableView.reloadData()
    }
    
    // edit a vpn configuration
    @IBAction func editVPNConfiguration(_ sender: Any?) {
        print("edit")
        let name = (tableView.cellForRow(at: [0,0]) as? NameValueTableViewCell)?.valueTextField.text
        let ip = (tableView.cellForRow(at: [0,1]) as? NameValueTableViewCell)?.valueTextField.text
        let port = (tableView.cellForRow(at: [0,2]) as? NameValueTableViewCell)?.valueTextField.text
        
        // if no changes, cancel
        if name == vpn?.VPNName && ip == vpn?.VPNIP && port == vpn?.VPNPort {
            self.cancelEdit(nil)
            
            return
        }
        
        let tmpVPNConfiguration = VPNConfiguration(vpnName: name!, vpnIP: ip!, vpnPort: port!, enabled: (vpn?.enabled)!)
        if tmpVPNConfiguration.checkIPFormat() && tmpVPNConfiguration.checkPortFormat(){
            //saveVPNConfigurationChanges(vpnConfiguration: tmpMyVPNConfiguration, vpnManager: vpnConfiguration)
            vpn = tmpVPNConfiguration
            performSegue(withIdentifier: "unwindToConfigurationTableView", sender: sender)
        }else{
            let alert = UIAlertController(title: "Error", message: "Save VPN configuration changes failed, please check ip and port format.", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default) {action in
                
            }
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
        }
    }

    // delete a vpn configuration
    @IBAction func deleteVPNConfiguration(_ sender: Any?) {
        self.delete = true
        performSegue(withIdentifier: "unwindToConfigurationTableView", sender: sender)
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
