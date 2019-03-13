//
//  State.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/15/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import ReSwift

// MARK:- STATE
struct AppState: StateType {
    var sizes: Sizes.State
    var duplicates: Duplicates.State
    var transcode: Transcode.State
    var largeFiles: LargeFiles.State
    var recentlyDeleted: RecentlyDeleted.State
    var preferences: Preferences.State

    var badgeCount: Int {
        return duplicates.badgeCount + transcode.badgeCount + recentlyDeleted.badgeCount
    }
    var notificationLines: [String] {
        var notifications: [String] = []
        if duplicates.badgeCount > 0 {
            notifications.append("Delete \(duplicates.badgeCount) exact duplicates to save \(duplicates.briefStatus.readySavingsBytes.formattedCompactByteString)")
        }
        if transcode.badgeCount > 0 {
            notifications.append("Upgrade compression of \(transcode.badgeCount) videos to save \(transcode.briefStatus.readySavingsBytes.formattedCompactByteString)")
        }
        return notifications
    }

    static func empty() -> AppState {
        return AppState(sizes: .empty(),
                        duplicates: .empty(),
                        transcode: .empty(),
                        largeFiles: .empty(),
                        recentlyDeleted: .empty(),
                        preferences: .empty())
    }
}

enum AppAction : Action {
    case setTranscode(Transcode.State)
    case setDuplicates(Duplicates.State)
    case setSizes(Sizes.State)
    case setLargeFiles(LargeFiles.State)
    case setRecentlyDeleted(RecentlyDeleted.State)
    case setLastReviewRequestedAppVersion(String)
    case setPreferences(Preferences.State)
    case appliedTranscode(Savings.Stats)
    case appliedDeleteDuplicates(Savings.Stats)
    case deletedAsset(Savings.Stats)
}

// MARK:- REDUCERS
func appReducer(action: Action, state: AppState?) -> AppState {
    NSLog("appReducer action \(type(of: action))")
    var newState = state!
    let appAction = action as! AppAction
    switch appAction {
    case .setDuplicates(let duplicates):
        newState.duplicates = duplicates
    case .setTranscode(let transcode):
        newState.transcode = transcode
    case .setSizes(let sizes):
        newState.sizes = sizes
    case .setLargeFiles(let largeFiles):
        newState.largeFiles = largeFiles
    case .setRecentlyDeleted(let recentlyDeleted):
        newState.recentlyDeleted = recentlyDeleted
    case .appliedTranscode(let savingsStats):
        newState.preferences.totalSavingsBytes += savingsStats.savingsBytes
        Preferences.Persistence.instance.save(state: newState.preferences)
    case .appliedDeleteDuplicates(let savingsStats):
        newState.preferences.totalSavingsBytes += savingsStats.savingsBytes
        Preferences.Persistence.instance.save(state: newState.preferences)
    case .deletedAsset(let savingsStats):
        newState.preferences.totalSavingsBytes += savingsStats.savingsBytes
        Preferences.Persistence.instance.save(state: newState.preferences)
    case .setPreferences(let preferences):
        newState.preferences = preferences
    case .setLastReviewRequestedAppVersion(let lastVersionPromptedForReview):
        newState.preferences.lastVersionPromptedForReview = lastVersionPromptedForReview
        Preferences.Persistence.instance.save(state: newState.preferences)
    }
    
    // return the new state
    return newState
}

let mainStore = ReSwift.Store<AppState>(
    reducer: appReducer,
    state: AppState.empty()
)

func dispatch(_ action: Action) {
    // dumb.  All this needs to be dispatches on Main.
    // https://github.com/ReSwift/ReSwift/issues/103
    DispatchQueue.main.async {
        mainStore.dispatch(action)
    }
}

