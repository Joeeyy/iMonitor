//
//  NameValueTableViewCell.swift
//  testVPN
//
//  Created by Joe Liu on 2018/9/15.
//  Copyright © 2018年 NUDT. All rights reserved.
//

/*
 Switch table view cell is used to define a reusable cell, which contains a Name-Value pair
 */

import UIKit

class NameValueTableViewCell: UITableViewCell {
    
    // MARK: Properties
    
    // name label
    @IBOutlet weak var nameLabel: UILabel!
    // value text field
    @IBOutlet weak var valueTextField: UITextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
