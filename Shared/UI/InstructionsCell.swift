//
//  GridAssetCell.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/9/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import UIKit

class InstructionsCell: UICollectionViewCell {
    
    @IBOutlet weak var label: UILabel!
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let fittedSize = label.sizeThatFits(size)
        return fittedSize
    }
    
    struct Model : Hashable {
        var text: String
        var learnMore: String?
        enum Style {
            case instructions
            case emptyPlaceholder
        }
        var style: Style
    }
    
    func set(model: Model) {
        let color: UIColor?
        let font: UIFont?
        switch model.style {
        case .emptyPlaceholder:
            color = UIColor.gray
            font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
        case .instructions:
            color = nil
            font = nil
        }
        var text = NSAttributedString(string: model.text + " ", color: color, font: font)
        if model.learnMore != nil {
            text = text + NSAttributedString(string: "Learn more", color: color, font: font, url: URL(string: "dummy:"))
        }
        label.attributedText = text
    }
}
