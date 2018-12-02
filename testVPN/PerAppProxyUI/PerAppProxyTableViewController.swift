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
import testVPNServices
import AdSupport

extension Notification.Name{
    static let AppSettingDidChanged = Notification.Name("AppSettingDidChanged")
}

class PerAppProxyTableViewController: UITableViewController, BMKLocationAuthDelegate, BMKLocationManagerDelegate {
    
    // MAKR: Properties
    
    // all perAppProxy
    var perAppProxys = [NEAppProxyProviderManager]()
    // selected perAppProxy
    var targetAppProxy = NEAppProxyProviderManager.shared()
    
    // for baiduLocate SDK
    let locateOnSetting = "locateOn"
    
    
    // for locatiing, locationManager
    let lm = BMKLocationManager()
    let baiduLocationSDKTag = "baiduLocationSDKTag"

    override func viewDidLoad() {
        super.viewDidLoad()

        // load all per-app proxy of this app
        loadPerAppProxy()
        
        // Baidu Location SDK Auth
        BMKLocationAuth.sharedInstance()?.checkPermision(withKey: "h64Hdsy6Bz5bIgEOnCymRnWNpCINgRP8", authDelegate: self)
        
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
            return 2
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
        let userDefaults: UserDefaults = UserDefaults.standard
        
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
        }
        else if indexPath == [0,1] {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "switchTableViewCell", for: indexPath) as? SwitchTableViewCell else{
                fatalError("Unexpected Error")
            }
            cell.startLabel.text = "Locate"
            cell.toggle.isOn = false
            userDefaults.set(false, forKey: locateOnSetting)
            cell.toggle.addTarget(self, action: #selector(self.doLocate(_:)), for: UIControlEvents.allTouchEvents)
            
            return cell
        }
        else{
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
    
    /************************/
    /*  Baidu Location SDK  */
    /************************/
    
    @IBAction func doLocate(_ sender: UISwitch){
        let userDefaults: UserDefaults = UserDefaults.standard
        userDefaults.set(sender.isOn, forKey: locateOnSetting)
        print(sender.isOn)
        if sender.isOn {
            startLocating()
        }
        else{
            lm.stopUpdatingLocation()
        }
    }
    
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
    
    func bmkLocationManager(_ manager: BMKLocationManager, didUpdate location: BMKLocation?, orError error: Error?) {
        if error != nil {
            testVPNLog(self.baiduLocationSDKTag + " Error \(error)")
            return
        }
        
        // to get certain about IP address of this device
        let idfa = ASIdentifierManager.shared()?.advertisingIdentifier
        
        let jsonDic: NSMutableDictionary = NSMutableDictionary()
        let locationStr: String
        let rgcStr: String
        
        if location != nil {
            if location!.location != nil {
                /*
                 * 参照：https://developer.apple.com/documentation/corelocation/cllocation
                 * location 属于iOS原生的CLLocation类型，是Baidu定位SDK调用iOS系统服务产生的结果。
                 * 属性：
                 * coordinate: CLLocationCoordinate2D, 二维地理坐标，常说的经纬度
                 * altitude: CLLocationDistance, 海拔，单位为米
                 * floor: CLFloor?, 楼层
                 * horizontalAccuracy: CLLocationAccuracy, 水平误差半径，单位为米
                 * timestamp: Date, 定位时间
                 * speed: CLLocationSpeed: 速度，单位为米每秒
                 * course: CLLocationDirection: 设备方向，以与正北方的相对夹角衡量
                 * verticalAccuracy: CLLocationAccuracy, 垂直误差半径，单位为米
                 */
                testVPNLog(self.baiduLocationSDKTag + " \(location?.location)")
                /*testVPNLog(self.baiduLocationSDKTag + " location: \n"
                 + "coordinate: \(location?.location?.coordinate.latitude as! Double),\(location?.location?.coordinate.longitude as! Double)\n"
                 + "accuracy: \(location?.location?.horizontalAccuracy as! Double)\n"
                 + "floor: \(location?.location?.floor as? Int)\n"
                 + "altitude: \(location?.location?.altitude as! Double)\n"
                 + "time: \(location?.location?.timestamp)\n"
                 + "speed: \(location?.location?.speed as! Double)\n"
                 + "direction: \(location?.location?.course as! Double)\n"
                 + "accuracy2:\(location?.location?.verticalAccuracy as! Double)\n"
                 )*/
                let locationDic: NSMutableDictionary = NSMutableDictionary()
                locationDic["coordinate"] = "(\(location?.location?.coordinate.longitude as! Double), \(location?.location?.coordinate.latitude as! Double))"
                locationDic["horizontalAccuracy"] = "\(location?.location?.horizontalAccuracy as! Double)"
                locationDic["altitude"] = "\(location?.location?.altitude as! Double)"
                locationDic["verticalAccuracy"] = "\(location?.location?.verticalAccuracy as! Double)"
                if location?.location?.floor != nil{
                    locationDic["floor"] = "\(location?.location?.floor?.level)"
                }
                locationDic["speed"] = "\(location?.location?.speed as! Double)"
                locationDic["course"] = "\(location?.location?.course as! Double)"
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
                let date_time = timeFormatter.string(from: (location?.location?.timestamp)!)
                locationDic["timestamp"] = date_time
                locationStr = toJSONString(dict: locationDic)
            }
            else {
                locationStr = ""
            }
            if location?.rgcData != nil {
                /*
                 * 参照：http://wiki.lbsyun.baidu.com/cms/iosloc/docs/v1_2_1/html/interface_b_m_k_location_re_geocode.html
                 * rgcData属于Baidu定位SDK定义的BMKLocationReGeocode类，是对iOS定位结果的一种补充，对定位结果进行了语义解释。
                 * country: NSString, 定位所在国家
                 * countryCode: NSString, 国家编码
                 * province: NSString, 省份名称
                 * city: NSString, 城市名称
                 * district: NSString, 区名称
                 * street: NSString, 街道名称
                 * streetNumber: NSString, 街区号码
                 * cityCode: NSString, 城市编码
                 * adCode: NSString, 行政区划编码
                 * locationDescribe: NSString, 定位地点在什么地方周围的语义化描述信息
                 * poiList: NSArray<BMKLocationPoi*>, 语义化结果，表示该定位点周围的poi列表。
                 */
                testVPNLog(self.baiduLocationSDKTag + "\(location?.rgcData.debugDescription)")
                /*testVPNLog(self.baiduLocationSDKTag + "rcgData: \n"
                 + "country: \(location?.rgcData?.country!), \(location?.rgcData?.countryCode!)\n"
                 + "province: \(location?.rgcData?.province!)\n"
                 + "city: \(location?.rgcData?.city!), \(location?.rgcData?.cityCode!)\n"
                 + "district: \(location?.rgcData?.district!)\n"
                 + "street: \(location?.rgcData?.street!), \(location?.rgcData?.streetNumber)\n"
                 + "adCode: \(location?.rgcData?.adCode!)\n"
                 + "locationDescribe: \(location?.rgcData?.locationDescribe!)\n"
                 + "poiList: \(location?.rgcData?.poiList.debugDescription)\n"
                 //+ ": \()\n"
                 )*/
                let rgcDataDic: NSMutableDictionary = NSMutableDictionary()
                rgcDataDic["country"] = location?.rgcData?.country
                rgcDataDic["countryCode"] = location?.rgcData?.countryCode
                rgcDataDic["province"] = location?.rgcData?.province
                rgcDataDic["city"] = location?.rgcData?.city
                rgcDataDic["cityCode"] = location?.rgcData?.cityCode
                rgcDataDic["district"] = location?.rgcData?.district
                rgcDataDic["street"] = location?.rgcData?.street
                rgcDataDic["streetNumber"] = location?.rgcData?.streetNumber
                rgcDataDic["adCode"] = location?.rgcData?.adCode
                rgcDataDic["locationDescribe"] = location?.rgcData?.locationDescribe
                var poiStr = "["
                for (i, poi) in (location?.rgcData?.poiList.enumerated())!{
                    if i != (location?.rgcData?.poiList.count)! - 1{
                        poiStr += "\(poi.name!), "
                    }
                    else{
                        poiStr += "\(poi.name!)]"
                    }
                }
                rgcDataDic["poiList"] = poiStr
                rgcStr = toJSONString(dict: rgcDataDic)
            }
            else{
                rgcStr = ""
            }
            
            jsonDic["idfa"] = idfa?.uuidString
            jsonDic["location"] = locationStr
            jsonDic["rgcData"] = rgcStr
            print("Going to send request")
            var jsonData:NSData? = nil
            do {
                jsonData  = try JSONSerialization.data(withJSONObject: jsonDic, options:JSONSerialization.WritingOptions.prettyPrinted) as NSData
            } catch {
            }
            
            postRequest(url: "http://119.23.215.159/test/checkin/locRec.php", jsonData: jsonData) { retStr in
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
