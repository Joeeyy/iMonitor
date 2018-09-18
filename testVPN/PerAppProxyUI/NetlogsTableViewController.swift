//
//  NetlogsTableViewController.swift
//  testVPN
//
//  Created by Joe Liu on 2018/9/17.
//  Copyright © 2018年 NUDT. All rights reserved.
//

import UIKit
import testVPNServices

class NetlogsTableViewController: UITableViewController {
    
    // MARK: Properties
    
    var logs = [Netlog]()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
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
        return logs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "netlogTableViewCell", for: indexPath) as? NetlogTableViewCell else{
            fatalError("convert cell to NameValueTableView failed.")
        }
        let log = logs[indexPath.row]
        cell.timeLabel.text = log.time
        cell.lengthLabel.text = "\(log.length) B"
        cell.protocolLabel.text = log.proto
        cell.directionLabel.text = log.direction
        cell.appLabel.text = log.app
        switch log.direction {
        case "out":
            cell.directionLabel.text = "To"
            cell.addressLabel.text = "\(log.dstIP):\(log.dstPort)"
        case "in":
            cell.directionLabel.text = "From"
            cell.addressLabel.text = "\(log.srcIP):\(log.srcPort)"
        default:
            myLog("unknown direction of network flow")
        }
        
        // Configure the cell...
        
        return cell
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
