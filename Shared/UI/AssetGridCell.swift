//
//  GridAssetCell.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/9/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import UIKit
import Photos

class AssetGridCell: UICollectionViewCell {
    
    let assetGridView = AssetGridView()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    func commonInit() {
        addSubview(assetGridView)
        assetGridView.frame = self.bounds
        assetGridView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    func load(imageManager: PHCachingImageManager, model: AssetGridView.Model) {
        assetGridView.load(imageManager: imageManager, model: model)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        assetGridView.unload()
    }
}
