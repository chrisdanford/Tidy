//
//  StoreUtil.swift
//  Tidy iOS
//
//  Created by Chris Danford on 3/9/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import StoreKit

class StoreUtil {
    private static var currentVersion: String? {
        guard let currentVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String else {
            return nil
        }
        return currentVersion
    }

    static let key = "lastVersionPromptedForReview"

    static func shouldAskUserForReview(state: AppState) -> Bool {
        let minSavingsBytes: UInt64 = 2 * 1024 * 1024 * 1024
        if state.preferences.totalSavingsBytes < minSavingsBytes {
            return false
        }
        
        guard let version = StoreUtil.currentVersion else {
            return false
        }
        
        let lastVersionPromptedForReview = UserDefaults.standard.string(forKey: key)
        if lastVersionPromptedForReview == version {
            return false
        }
        
        return true
    }
    
    static func requestReview() {
        if let currentVer = currentVersion {
            SKStoreReviewController.requestReview()
            dispatch(AppAction.SetLastReviewRequestedAppVersion(lastReviewRequestedAppVersion: currentVer))
        }
    }
}
