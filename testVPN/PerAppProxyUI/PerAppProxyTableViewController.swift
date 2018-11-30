//
//  PerAppProxyTableViewController.swift
//  testVPN
//
//  Created by Joe Liu on 2018/9/15.
//  Copyright © 2018年 NUDT. All rights reserved.
//

/*
 */

import UIKit
import NetworkExtension

class PerAppProxyTableViewController: UITableViewController {
    
    // MAKR: Properties
    
    // all perAppProxy
    var perAppProxys = [NEAppProxyProviderManager]()
    // selected perAppProxy
    var targetAppProxy = NEAppProxyProviderManager.shared()

    override func viewDidLoad() {
        super.viewDidLoad()

        // load all per-app proxy of this app
        loadPerAppProxy()
        
        // button to show netlog table view
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Net Logs", style: UIBarButtonItemStyle.plain, target: self, action: #selector(self.showNetlogs(_:)))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if section == 0{
            return 1
        }
        else {
            return perAppProxys.count
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if perAppProxys[indexPath.row].isEnabled == true {
            return
        }
        perAppProxys[indexPath.row].isEnabled = true
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath == [0,0] {
            // for control cell
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "switchTableViewCell") as? SwitchTableViewCell else {
                fatalError("Error creating NameValueTableViewCell.")
            }
            cell.toggle.isOn = self.targetAppProxy.connection.status == .connected ? true : false
            if self.targetAppProxy.connection.status == .connected {
                cell.startLabel.text = "Connected"
            }else if self.targetAppProxy.connection.status == .disconnected {
                cell.startLabel.text = "Disconnected"
            }else if self.targetAppProxy.connection.status == .disconnecting {
                cell.startLabel.text = "Disconnecting"
            }else if self.targetAppProxy.connection.status == .connecting {
                cell.startLabel.text = "connecting"
            }
            cell.toggle.addTarget(self, action: #selector(self.startStopAppProxy), for: .allTouchEvents)
            return cell
        }else{
            // for per-app proxy configuration cells
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "nameValueTableViewCell") as? NameValueTableViewCell else {
                fatalError("Error creating NameValueTableViewCell.")
            }
            cell.valueTextField.isEnabled = false
            cell.nameLabel.text = perAppProxys[indexPath.row].isEnabled ? "✔️" : ""
            cell.valueTextField.text = perAppProxys[indexPath.row].localizedDescription
            cell.accessoryType = UITableViewCellAccessoryType.detailButton
            
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition.none)
    }

    // MARK: Actions
    
    // show netlogs
    @IBAction func showNetlogs(_ sender: Any? ){
        performSegue(withIdentifier: "showNetlogs", sender: sender)
    }
    
    // load per-app proxy
    private func loadPerAppProxy() {
        NEAppProxyProviderManager.loadAllFromPreferences() { managers, error in
            assert(Thread.isMainThread)
            if error != nil {
                myLog("load per app proxy failed.")
                return
            }
            
            guard managers?.first != nil else {
                myLog("No per app proxy loaded.")
                return
            }
            
            self.perAppProxys = managers!
            self.tableView.reloadData()
            for perAppProxy in self.perAppProxys {
                if perAppProxy.isEnabled {
                    self.targetAppProxy = perAppProxy
                }
            }
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: self.targetAppProxy.connection, queue: OperationQueue.main, using: { notification in
                guard let cell = self.tableView.cellForRow(at: [0,0]) as? SwitchTableViewCell else {
                    fatalError("Error creating SwitchTableViewCell.")
                }
                if self.targetAppProxy.connection.status == .connected {
                    cell.startLabel.text = "Connected"
                    cell.toggle.isOn = true
                }else if self.targetAppProxy.connection.status == .disconnected{
                    cell.startLabel.text = "Disconnected"
                    cell.toggle.isOn = false
                }else if self.targetAppProxy.connection.status == .disconnecting{
                    cell.startLabel.text = "Disconnecting"
                    cell.toggle.isOn = false
                }else if self.targetAppProxy.connection.status == .connecting{
                    cell.startLabel.text = "Connecting"
                    cell.toggle.isOn = true
                }
            })
            self.tableView.reloadData()
        }
    }
    
    // start target app proxy
    @IBAction func startStopAppProxy(){
        if targetAppProxy.connection.status == .connected {
            let session = self.targetAppProxy.connection as! NETunnelProviderSession
            
            session.stopTunnel()
        }
        else if targetAppProxy.connection.status == .disconnected {
            let session = self.targetAppProxy.connection as! NETunnelProviderSession
            do {
                try session.startTunnel(options: nil)
            }
            catch {
                
            }
        }
        else if targetAppProxy.connection.status == .connecting {
            let session = self.targetAppProxy.connection as! NETunnelProviderSession
            do{
                try session.stopTunnel()
            }
            catch{
                
            }
        }
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        switch segue.identifier ?? ""{
        case "showPerAppProxyDetail":
            guard let dst = segue.destination as? PerAppProxyConfigurationTableViewController else {
                fatalError("cast to PerAppProxyConfigurationTableViewController failed.")
            }
            guard let selectedCell = sender as? NameValueTableViewCell else {
                fatalError("cast to PerAppProxyItemTableViewCell failed.")
            }
            guard let selectedIndex = tableView.indexPath(for: selectedCell) else{
                fatalError("the selected cell is not shown any more")
            }
            
            dst.targetPerAppProxy = perAppProxys[selectedIndex.row]
        case "showNetlogs":
            guard let dstVC = segue.destination as? NetlogsTableViewController else {
                fatalError("Error creatinga NetlogsTableViewController..")
            }
            dstVC.logs = Database().queryTableNETWORKFLOWLOG()
        default:
            myLog("no such segue identifier")
        }
    }


}
