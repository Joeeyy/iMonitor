//
//  TableViewController.swift
//  testVPN
//
//  Created by Joe Liu on 2018/12/1.
//  Copyright © 2018 NUDT. All rights reserved.
//

import UIKit
import testVPNServices

class TableViewController: UITableViewController, BMKLocationAuthDelegate, BMKLocationManagerDelegate {
    
    //let lm: BMKLocationManager = BMKLocationManager()
    
    let tag = "BaiduLocationSDK"
    
    let locateOnSetting = "locateOn"

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        // Auth of Baidu Location SDK
        BMKLocationAuth.sharedInstance()?.checkPermision(withKey: "h64Hdsy6Bz5bIgEOnCymRnWNpCINgRP8", authDelegate: self)
        
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 1
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let userDefaults: UserDefaults = UserDefaults.standard
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "switchTableViewCell", for: indexPath) as? SwitchTableViewCell else{
            fatalError("Unexpected Error")
        }
        cell.toggle.isOn = userDefaults.bool(forKey: locateOnSetting)
        cell.toggle.addTarget(self, action: #selector(self.doLocate(_:)), for: UIControlEvents.allTouchEvents)

        return cell
    }
    
    /************************/
    /*  Baidu Location SDK  */
    /************************/
    
    @IBAction func doLocate(_ sender: UISwitch?){
        let userDefaults: UserDefaults = UserDefaults.standard
        
        userDefaults.set(sender?.isOn, forKey: locateOnSetting)
        print(sender?.isOn)
    }
    /*
    private func startLocating(){
        lm.delegate = self
        lm.coordinateType = BMKLocationCoordinateType.BMK09LL
        lm.distanceFilter = kCLDistanceFilterNone
        lm.desiredAccuracy = kCLLocationAccuracyBest
        lm.activityType = CLActivityType.automotiveNavigation
        lm.pausesLocationUpdatesAutomatically = false
        lm.allowsBackgroundLocationUpdates = true
        lm.locationTimeout = 10
        lm.reGeocodeTimeout = 10
        
        /*
        // locate once
        lm.requestLocation(withReGeocode: true, withNetworkState: true) { location, state, error in
            if error != nil {
                print("Error :( => \(error)")
                return
            }
            print("location: \(location.debugDescription) \n state: \(state)")
            if location?.location != nil{
                print("\(location!.location)")
            }
            if location?.rgcData != nil{
                print("\(location!.rgcData.debugDescription)")
            }
            print("state: \(state.rawValue)")
        }
         \*/
        
        // locate continuously
        lm.locatingWithReGeocode = true
        lm.startUpdatingLocation()
    }
     */
    
    

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

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
