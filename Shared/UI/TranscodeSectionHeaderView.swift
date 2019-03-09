//
//  TranscodeSectionHeaderView.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/21/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import UIKit

class TranscodeSectionHeaderView: UICollectionReusableView {
    @IBOutlet weak var spaceToRecover: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    func load(model: ViewModel.TranscodeSectionHeader) {
        spaceToRecover.text = model.spaceToRecover
        statusLabel.text = model.status
    }
}
