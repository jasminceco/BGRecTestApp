//
//  recordingsTableView.swift
//  BGRecordingTestApp
//
//  Created by Jasmin Ceco on 16/04/2018.
//  Copyright © 2018 Jasmin Ceco. All rights reserved.
//

import UIKit

class recordingsTableView: UITableViewCell {
    @IBOutlet weak var recTitle: UILabel!

    @IBOutlet weak var fileName: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    var index : Int = 0
    var recording : URL!  {
        didSet{
            self.recTitle.text = recording.lastPathComponent
            self.fileName.text = recording.path
        }
    }
    
}
