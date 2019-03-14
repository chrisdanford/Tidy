//
//  Celebration.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/17/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation

class About {
    struct Info {
        var inlineTitle: String
        var alertTitle: String
        var message: String
        var showLeaveARating: Bool
    }
    
    static func info(state: AppState) -> Info {
        let totalSavingsBytes = state.preferences.totalSavingsBytes
        let inlineTitle: String
        let alertTitle: String
        if totalSavingsBytes > 0 {
            inlineTitle = "You've saved \(totalSavingsBytes.formattedCompactByteString) 🎉"
            alertTitle = "With Tidy, you've permanently saved \(totalSavingsBytes.formattedCompactByteString) 🎉"
        } else {
            if state.badgeCount > 0 {
                inlineTitle = "Let's free some space 👏"
            } else {
                inlineTitle = "No savings yet 🌴"
            }
            alertTitle = "Thanks for trying Tidy"
        }
        
        let showLeaveARating = StoreUtil.shouldAskUserForReview(state: state)
        let message = "Tidy is open-source and 100% free. " + (showLeaveARating ? "Could you please leave us a rating? 💕" : "We hope that you find it useful 💕")

        return Info(inlineTitle: inlineTitle, alertTitle: alertTitle, message: message, showLeaveARating: showLeaveARating)
    }
}
