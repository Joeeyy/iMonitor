//
//  ImageLabelTableViewCell.swift
//  testVPN
//
//  Created by Joe Liu on 2018/9/16.
//  Copyright © 2018年 NUDT. All rights reserved.
//

import UIKit

class ImageLabelTableViewCell: UITableViewCell {
    
    // MARK: Properties
    
    // image
    @IBOutlet var headerImage: UIImageView!
    // label
    @IBOutlet weak var label: UILabel!
    

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
