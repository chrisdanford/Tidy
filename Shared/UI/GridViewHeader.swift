//
//  GridViewHeader.swift
//  Tidy iOS
//
//  Created by Chris Danford on 1/22/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import UIKit

class GridViewHeader: UICollectionReusableView {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var progress: UIProgressView!
    
//    func set(indexStatus: Transcode.IndexStatus) {
//        label.text = indexStatus.statusText
//        progress.progress = indexStatus.progress
//    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        label.text = nil
        progress.progress = 0
    }
    
}
