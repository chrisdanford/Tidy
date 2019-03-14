//
//  ActivityAndBadge.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/18/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import UIKit

class ActivityAndBadge: UIStackView {
    let activityView = UIActivityIndicatorView(style: .gray)
    let label = UILabel()

    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()

        for view in [activityView, label] {
            self.addArrangedSubview(view)
        }
    }
    
    func commonInit() {
        activityView.startAnimating()

        let fontSize = CGFloat(14)
        // Create label
        label.font = UIFont.systemFont(ofSize: fontSize)
        label.textAlignment = NSTextAlignment.center;
        label.textColor = UIColor.white
        label.backgroundColor = UIColor.red
    }

    func set(showActivity: Bool, badgeMessage: String?) {
        let stackView = self

        var visibleSubviews = [UIView]()

        visibleSubviews.append(activityView)
        if showActivity {
            activityView.startAnimating()
            activityView.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        } else {
            activityView.stopAnimating()
            activityView.frame = CGRect.zero
        }
        
        visibleSubviews.append(label)
        let showBadge = badgeMessage != nil
        label.isHidden = !showBadge
        label.text = badgeMessage ?? ""
    
        // Add count to label and size to fit
        label.sizeToFit()
        
        // Adjust frame to be square for single digits or elliptical for numbers > 9
        var frame = label.frame
        let toAdd = (0.5 * label.font.pointSize).rounded()
        frame.size.height = frame.size.height + toAdd
        frame.size.width = frame.size.width + toAdd
        label.frame = frame

        // Set radius and clip to bounds
        label.layer.cornerRadius = frame.size.height/2.0;
        label.clipsToBounds = true

        
        let width = visibleSubviews.reduce(0, { max($0, $1.frame.size.width) })
        let height = visibleSubviews.reduce(0, { $0 + $1.frame.size.height })
        
        stackView.axis = .vertical
        stackView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        stackView.sizeToFit()
        stackView.spacing = 4
    }
}
