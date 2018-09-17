//
//  PerAppProxyConfigurationTableViewController.swift
//  testVPN
//
//  Created by Joe Liu on 2018/9/15.
//  Copyright © 2018年 NUDT. All rights reserved.
//

import UIKit
import NetworkExtension

class PerAppProxyConfigurationTableViewController: UITableViewController {
    
    // MARK: Properties
    
    // target per app proxy
    var targetPerAppProxy = NEAppProxyProviderManager.shared()
    // target apps
    var targetApps = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        getTargetApps()
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
        return 2 + targetApps.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print(indexPath)
        if indexPath == [0,0] {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "nameValueTableViewCell", for: indexPath) as? NameValueTableViewCell else {
                fatalError("create NameValueTableViewCell failed.")
            }
            cell.nameLabel.text = "Name"
            cell.valueTextField.text = targetPerAppProxy.localizedDescription
            cell.valueTextField.isEnabled = false
            
            return cell
        }
        else if indexPath == [0,1] {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "nameValueTableViewCell", for: indexPath) as? NameValueTableViewCell else {
                fatalError("create NameValueTableViewCell failed.")
            }
            cell.nameLabel.text = "Server"
            cell.valueTextField.text = targetPerAppProxy.protocolConfiguration?.serverAddress
            cell.valueTextField.isEnabled = false
            
            return cell
        }
        else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "imageLabelCell", for: indexPath) as? ImageLabelTableViewCell else {
                fatalError("create ImageLabelCell failed.")
            }
            //cell.appIcon.image = UIImage(named: "AppIcon")
            cell.label.text = targetApps[indexPath.row - 2]
            
            return cell
        }
    }
    
    // MARK: Actions
    
    // get target apps of a per-app proxy
    private func getTargetApps() {
        //print("protocol: \r\n\(targetPerAppProxy.protocolConfiguration)")
        var tmpAppRules = (targetPerAppProxy as! NEAppProxyProviderManager).copyAppRules()
        for rule in tmpAppRules!{
            targetApps.append(rule.matchSigningIdentifier)
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
