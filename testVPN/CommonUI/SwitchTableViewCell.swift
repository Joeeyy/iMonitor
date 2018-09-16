//
//  SwitchTableViewCell.swift
//  testVPN
//
//  Created by Joe Liu on 2018/9/15.
//  Copyright © 2018年 NUDT. All rights reserved.
//

/*
 Switch table view cell is used to define a reusable cell, which contains a switch
 */

import UIKit

class SwitchTableViewCell: UITableViewCell {
    
    // MARK: Properties
    
    // start label
    @IBOutlet weak var startLabel: UILabel!
    // toggle switch
    @IBOutlet weak var toggle: UISwitch!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
