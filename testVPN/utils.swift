//
//  utils.swift
//  PacketTunnel
//
//  Created by Joe Liu on 2018/9/11.
//  Copyright © 2018年 NUDT. All rights reserved.
//

import Foundation

// MARK: for regex
struct myRegex{
    let regex: NSRegularExpression?
    
    init(_ pattern: String){
        regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }
    
    func match( input: String) -> Bool {
        if let matches = regex?.matches(in: input, options: [], range: NSMakeRange(0, (input as NSString).length)){
            return matches.count>0
        }
        else{
            return false
        }
    }
}

// log
func myLog(_ message: String) {
    NSLog("<AINASSINE> \(message)")
}
