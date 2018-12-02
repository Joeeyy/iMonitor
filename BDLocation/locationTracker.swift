//
//  locationTracker.swift
//  testVPN
//
//  Created by Joe Liu on 2018/12/2.
//  Copyright © 2018 NUDT. All rights reserved.
//

import Foundation

class locationTrackor: CLLocationManager, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    
    override init() {
        super.init()
    }
}
