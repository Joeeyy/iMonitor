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
            db = try Connection(sqlFilePath)
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
    
    
    // </ ACTIONs
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
            testVPNLog(self.TAG + "create table error: \(error)")
        }
    }
    
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
    
    func queryTableNETWORKFLOWLOG(){
        for record in try! db.prepare(TABLE_NETWORKFLOWLOG){
            testVPNLog(self.TAG + "\nid: \(record[TABLE_NETWORKFLOWLOG_ID]), srcIP: \(record[TABLE_NETWORKFLOWLOG_SRCIP]), srcPort: \(record[TABLE_NETWORKFLOWLOG_SRCPORT]), dstIP: \(record[TABLE_NETWORKFLOWLOG_DSTIP]), dstPort: \(record[TABLE_NETWORKFLOWLOG_DSTPORT]), length: \(record[TABLE_NETWORKFLOWLOG_LENGTH]), protocol: \(record[TABLE_NETWORKFLOWLOG_PROTO]), time: \(record[TABLE_NETWORKFLOWLOG_TIME]), app: \(record[TABLE_NETWORKFLOWLOG_APP]), direction: \(record[TABLE_NETWORKFLOWLOG_DIRECTION])")
        }
    }
    
    /*func readTableNETWORKFLOWLog(address: Int) -> Void {
        for record in try! db.prepare(TABLE_LAMP.filter(TABLE_LAMP_ADDRESS == address)) {
            print("\nid: \(record[TABLE_NETWORKFLOWLOG_ID]), srcIP: \(record[TABLE_NETWORKFLOWLOG_SRCIP]), srcPort: \(record[TABLE_NETWORKFLOWLOG_SRCPORT]), dstIP: \(record[TABLE_NETWORKFLOWLOG_DSTIP]), dstPort: \(record[TABLE_NETWORKFLOWLOG_DSTPORT]), length: \(record[TABLE_NETWORKFLOWLOG_LENGTH]), protocol: \(record[TABLE_NETWORKFLOWLOG_PROTO]), time: \(record[TABLE_NETWORKFLOWLOG_TIME])")
        }
        
    }*/
    
    /*func tableLampUpdateItem(address: Int, newName: String) -> Void {
        let item = TABLE_LAMP.filter(TABLE_LAMP_ADDRESS == address)
        do {
            if try db.run(item.update(TABLE_LAMP_NAME <- newName)) > 0 {
                print("灯光\(address) 更新成功")
            } else {
                print("没有发现 灯光条目 \(address)")
            }
        } catch {
            print("灯光\(address) 更新失败：\(error)")
        }
    }*/
    
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
    // ACTIONs />
}
