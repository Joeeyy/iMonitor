//
//  NetlogTableViewCell.swift
//  testVPN
//
//  Created by Joe Liu on 2018/9/15.
//  Copyright © 2018年 NUDT. All rights reserved.
//

/*
 Switch table view cell is used to define a reusable cell, which contains a netlog
 */

import UIKit

class NetlogTableViewCell: UITableViewCell {

    // MARK: Properties
    
    // direction label
    @IBOutlet weak var directionLabel: UILabel!
    // address label
    @IBOutlet weak var addressLabel: UILabel!
    // length label
    @IBOutlet weak var lengthLabel: UILabel!
    // time label
    @IBOutlet weak var timeLabel: UILabel!
    // app label
    @IBOutlet weak var appLabel: UILabel!
    // id label
    @IBOutlet weak var idLabel: UILabel!
    // protocol label
    @IBOutlet weak var protocolLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
