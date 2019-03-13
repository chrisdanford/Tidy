//
//  DuplicatesSectionHeaderView.swift
//  Tidy iOS
//
//  Created by Chris Danford on 3/5/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import UIKit

extension UIView {
    func clone() -> UIView {
        let data = NSKeyedArchiver.archivedData(withRootObject: self)
        return NSKeyedUnarchiver.unarchiveObject(with: data) as! UIView
    }
}

class DuplicatesSectionHeaderView: UICollectionReusableView {
    @IBOutlet weak var outerStackView: UIStackView!
    
    func load(model: ViewModel.DuplicatesSectionHeader) {
        for stackView in outerStackView.subviews {
            let toDeleteLabel = stackView.subviews[1]
            toDeleteLabel.layer.borderColor = UIColor.red.cgColor
            toDeleteLabel.layer.borderWidth = 3
        }
    }
    
    func set(columnCount: Int) {
        let numColumnPairs = columnCount / 2
        let template = outerStackView.subviews[0]

        let numToAdd = numColumnPairs - outerStackView.subviews.count
        if numToAdd > 0 {
            for _ in 0..<numToAdd {
                outerStackView.addArrangedSubview(template.clone())
            }
        } else if numToAdd < 0 {
            for _ in numToAdd..<0 {
                outerStackView.subviews.last!.removeFromSuperview()
            }
        }
    }
}
