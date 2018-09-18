//
//  Database.swift
//  testVPN
//
//  Created by Joe Liu on 2018/9/3.
//  Copyright © 2018年 NUDT. All rights reserved.
//

import Foundation
import SQLite
import testVPNServices

public enum AppConfigKeys: String {
    case imei = "imei"
    case phone_number = "phone_number"
    case ip = "ip"
    case networkType = "networkType"
    case port = "port"
}

struct Database {
    var db: SQLite.Connection!
    let TAG = "Database: "
    let databaseFilename = "/db.sqlite3"
    var pathToDatabase: String!
    
    init() {
        connectDatabase()
    }
    
    // connect with database
    mutating func connectDatabase() -> Void{
        /* // used to delete database file
        let tmpPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let tmpfm = FileManager.default
        do {
            try tmpfm.removeItem(atPath: tmpPath+"/db.sqlite3")
            testVPNLog(self.TAG + "succeded deleting @\(tmpPath+"/db.sqlite3")")
        } catch {
            testVPNLog(self.TAG + "error occured when delete @\(tmpPath+"/db.sqlite3")")
        }*/
        
        // confirming path of database
        let APPGroupContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.cn.edu.nudt.testVPN")
        if let groupContainerURL = APPGroupContainerURL {
            let groupContainerString = groupContainerURL.path
            pathToDatabase = groupContainerString.appending(databaseFilename)
        }
        let sqlFilePath = pathToDatabase!
        
        do {
            db = try SQLite.Connection(sqlFilePath)
            testVPNLog(self.TAG + "connect database successfully at \(sqlFilePath)")
            
            
            // set for timeout
            db.busyTimeout = 5
            
            db.busyHandler({ tries in
                if tries >= 3 {
                    return false
                }
                return true
            })
        } catch {
            testVPNLog(self.TAG + "connect database failed: \(error) @ \(sqlFilePath)")
        }
    }
    
    // </ ------------------- create table for network flow log ---------------------
    let TABLE_NETWORKFLOWLOG = Table("Network_Flow_Log")
    let TABLE_NETWORKFLOWLOG_ID = Expression<Int>("flow_id")
    let TABLE_NETWORKFLOWLOG_SRCIP = Expression<String>("src_ip")
    let TABLE_NETWORKFLOWLOG_SRCPORT = Expression<String>("src_port")
    let TABLE_NETWORKFLOWLOG_DSTIP = Expression<String>("dst_ip")
    let TABLE_NETWORKFLOWLOG_DSTPORT = Expression<String>("dst_port")
    let TABLE_NETWORKFLOWLOG_TIME = Expression<String>("time")
    let TABLE_NETWORKFLOWLOG_PROTO = Expression<String>("proto")
    let TABLE_NETWORKFLOWLOG_LENGTH = Expression<Int>("length")
    let TABLE_NETWORKFLOWLOG_APP = Expression<String>("app")
    let TABLE_NETWORKFLOWLOG_DIRECTION = Expression<String>("direction")
    // ------------------- create table for network flow log --------------------- />
    
    // </ ------------------- create table for app configuration ---------------------
    let TABLE_APPCONFIG = Table("App_Config")
    let TABLE_APPCONFIG_KEY = Expression<String>("key")
    let TABLE_APPCONFIG_VALUE = Expression<String>("value")
    // ------------------- create table for app configuration --------------------- />
    
    // </ ACTIONs
    
    /*************************************************
     FOR NETWORK FLOW LOG TABLE
     *************************************************/
    // create table for network flow log
    func tableNETWORKFLOWLOGCreate() -> Void{
        do {
            try db.run(TABLE_NETWORKFLOWLOG.create { table in
                table.column(TABLE_NETWORKFLOWLOG_ID, primaryKey: .autoincrement)
                table.column(TABLE_NETWORKFLOWLOG_SRCIP)
                table.column(TABLE_NETWORKFLOWLOG_SRCPORT)
                table.column(TABLE_NETWORKFLOWLOG_DSTIP)
                table.column(TABLE_NETWORKFLOWLOG_DSTPORT)
                table.column(TABLE_NETWORKFLOWLOG_TIME)
                table.column(TABLE_NETWORKFLOWLOG_PROTO)
                table.column(TABLE_NETWORKFLOWLOG_LENGTH)
                table.column(TABLE_NETWORKFLOWLOG_APP)
                table.column(TABLE_NETWORKFLOWLOG_DIRECTION)
            })
            testVPNLog(self.TAG + "create table NETWORKFLOWLOG successfully.")
        } catch {
            testVPNLog(self.TAG + "create table NETWORKFLOWLOG error: \(error)")
        }
    }
    
    // insert a network flow into NETWORKFLOWLOG
    func tableNETWORKFLOWLOGInsertItem(srcIP: String, srcPort: String, dstIP: String, dstPort: String, length: Int, proto: String, time: String, app: String, direction: String){
        let insert = TABLE_NETWORKFLOWLOG.insert(TABLE_NETWORKFLOWLOG_SRCIP <- srcIP,
                                                 TABLE_NETWORKFLOWLOG_SRCPORT <- srcPort,
                                                 TABLE_NETWORKFLOWLOG_DSTIP <- dstIP,
                                                 TABLE_NETWORKFLOWLOG_DSTPORT <- dstPort,
                                                 TABLE_NETWORKFLOWLOG_TIME <- time,
                                                 TABLE_NETWORKFLOWLOG_LENGTH <- length,
                                                 TABLE_NETWORKFLOWLOG_PROTO <- proto,
                                                 TABLE_NETWORKFLOWLOG_APP <- app,
                                                 TABLE_NETWORKFLOWLOG_DIRECTION <- direction)
        do {
            let rowId = try db.run(insert)
            testVPNLog(self.TAG + "insert a record into table NETWORKFLOWLOG: \(rowId)")
        } catch {
            testVPNLog(self.TAG + "insert a record into table NETWORKFLOWLOG failed.")
        }
    }
    
    // check all logs in NETWORKFLOWLOG
    func queryTableNETWORKFLOWLOG() -> [Netlog]{
        var logArray = [Netlog]()
        
        for record in try! db.prepare(TABLE_NETWORKFLOWLOG.order(TABLE_NETWORKFLOWLOG_TIME.desc)){
        //for record in try! db.prepare(query){
            var netlog = Netlog()
            netlog.app = record[TABLE_NETWORKFLOWLOG_APP]
            netlog.id = record[TABLE_NETWORKFLOWLOG_ID]
            netlog.srcIP = record[TABLE_NETWORKFLOWLOG_SRCIP]
            netlog.srcPort = record[TABLE_NETWORKFLOWLOG_SRCPORT]
            netlog.dstIP = record[TABLE_NETWORKFLOWLOG_DSTIP]
            netlog.dstPort = record[TABLE_NETWORKFLOWLOG_DSTPORT]
            netlog.time = record[TABLE_NETWORKFLOWLOG_TIME]
            netlog.direction = record[TABLE_NETWORKFLOWLOG_DIRECTION]
            netlog.proto = record[TABLE_NETWORKFLOWLOG_PROTO]
            netlog.length = record[TABLE_NETWORKFLOWLOG_LENGTH]
            logArray.append(netlog)
        }
        return logArray
    }
    
    // check a certain type of logs by its name
    func queryTableNETWORKFLOWLOGByAppName(AppName: String) -> [Netlog]{
        var logArray = [Netlog]()
        let query = TABLE_NETWORKFLOWLOG.select(*).filter(TABLE_NETWORKFLOWLOG_APP == AppName).order(TABLE_NETWORKFLOWLOG_TIME.desc)
        for record in try! db.prepare(query){
            //for record in try! db.prepare(query){
            var netlog = Netlog()
            netlog.app = record[TABLE_NETWORKFLOWLOG_APP]
            netlog.id = record[TABLE_NETWORKFLOWLOG_ID]
            netlog.srcIP = record[TABLE_NETWORKFLOWLOG_SRCIP]
            netlog.srcPort = record[TABLE_NETWORKFLOWLOG_SRCPORT]
            netlog.dstIP = record[TABLE_NETWORKFLOWLOG_DSTIP]
            netlog.dstPort = record[TABLE_NETWORKFLOWLOG_DSTPORT]
            netlog.time = record[TABLE_NETWORKFLOWLOG_TIME]
            netlog.direction = record[TABLE_NETWORKFLOWLOG_DIRECTION]
            netlog.proto = record[TABLE_NETWORKFLOWLOG_PROTO]
            netlog.length = record[TABLE_NETWORKFLOWLOG_LENGTH]
            logArray.append(netlog)
        }
        
        return logArray
    }
    
    
        
    
    
    // update tableNETWORKFLOWLOG target key with value
    func tableNETWORKFLOWLOGUpdateItem(key: String, value: String){
        let record = TABLE_NETWORKFLOWLOG.filter(TABLE_NETWORKFLOWLOG_SRCPORT == key||TABLE_NETWORKFLOWLOG_DSTPORT == key)
        do {
            if try db.run(record.update(TABLE_NETWORKFLOWLOG_SRCPORT <- value)) > 0{
                testVPNLog(self.TAG + "update reocrd of key: \(key) succeeded to value: \(value). ")
            }
            else {
                testVPNLog(self.TAG + "update record of key: \(key) failed. no such record with that key.")
            }
        } catch {
            testVPNLog(self.TAG + "error occured when update record with key: \(key), error: \(error)")
        }
    }
    
    // Delete an item in NETWORKFLOWLOG by id
    func tableNETWORKFLOWLOGDeleteItem(id: Int){
        let record = TABLE_NETWORKFLOWLOG.filter(TABLE_NETWORKFLOWLOG_ID == id)
        do {
            if try db.run(record.delete()) > 0 {
                testVPNLog(self.TAG + "delete record with id: \(id) succeeded.")
            }
            else{
                testVPNLog(self.TAG + "delete record with id: No Such Record.")
            }
        } catch {
            testVPNLog(self.TAG + "delete record with id: \(id) failed. error: \(error)")
        }
    }
    
    /*************************************************
     FOR APP CONFIG TABLE
     *************************************************/
    // create app config table
    func tableAPPCONFIGCreate() {
        do {
            try db.run(TABLE_APPCONFIG.create { table in
                table.column(TABLE_APPCONFIG_KEY, primaryKey: true)
                table.column(TABLE_APPCONFIG_VALUE)
            })
            testVPNLog(self.TAG + "create table APPCONFIG successfully.")
        } catch {
            testVPNLog(self.TAG + "create table APPCONFIG error: \(error)")
        }
    }
    
    // insert a record into APP CONFIG table
    func tableAPPCONFIGInsertItem(key: String, value: String){
        let insert = TABLE_APPCONFIG.insert(
            TABLE_APPCONFIG_KEY <- key,
            TABLE_APPCONFIG_VALUE <- value
        )
        do {
            try db.run(insert)
            testVPNLog(self.TAG + "insert a record into table APPCONFIG succeeded. key: \(key), value: \(value)")
        } catch {
            testVPNLog(self.TAG + "insert a record into table APPCONFIG failed.")
        }
    }
    
    // delete a record from APP CONFIG table by key name
    func tableAPPCONFIGDeleteItem(key: String) {
        let record = TABLE_APPCONFIG.filter(TABLE_APPCONFIG_KEY == key)
        do {
            try db.run(record.delete())
            testVPNLog(self.TAG + "delete record with key: \(key) successfully.")
        } catch {
            testVPNLog(self.TAG + "delete record with key: \(key) failed.")
        }
    }
    
    // update a record in APP CONFIG table by key name
    func tableAPPCONFIGUpdateItem(key: String, value: String) {
        let record = TABLE_APPCONFIG.filter(TABLE_APPCONFIG_KEY == key)
        do {
            if try db.run(record.update(TABLE_APPCONFIG_VALUE <- value)) > 0{
                testVPNLog(self.TAG + "update reocrd of key: \(key) succeeded to value: \(value). ")
            }
            else {
                testVPNLog(self.TAG + "update record of key: \(key) failed. no such record with that key.")
            }
        } catch {
            testVPNLog(self.TAG + "error occured when update record with key: \(key), error: \(error)")
        }
    }
    
    // get value of a record in APP CONFIG table by key name
    func tableAPPCONFIGQueryItem(key: String) -> String?{
        let filtered_table = TABLE_APPCONFIG.filter(TABLE_APPCONFIG_KEY == key)
        
        let records = try! db.prepare(filtered_table)
        for record in records{
            testVPNLog(self.TAG + "checked: key: \(key), value: \(record[TABLE_APPCONFIG_VALUE])")
            return record[TABLE_APPCONFIG_VALUE]
        }

        return nil
    }
    
    // ACTIONs />
}
