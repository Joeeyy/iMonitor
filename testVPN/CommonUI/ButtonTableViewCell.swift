//
//  ButtonTableViewCell.swift
//  testVPN
//
//  Created by Joe Liu on 2018/9/15.
//  Copyright © 2018年 NUDT. All rights reserved.
//

import UIKit

class ButtonTableViewCell: UITableViewCell {
    
    // MARK: Properties
    
    // button
    @IBOutlet weak var button: UIButton!
    

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
