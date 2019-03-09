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
    var recentlyDeleted: RecentlyDeleted.State
    var savings: Savings
    var totalSavingsBytes: UInt64

    var badgeCount: Int {
        return duplicates.badgeCount + transcode.badgeCount + recentlyDeleted.badgeCount
    }
    
    static func empty() -> AppState {
        return AppState(sizes: Sizes.State.empty(),
                        duplicates: Duplicates.State.empty(),
                        transcode: Transcode.State.empty(),
                        recentlyDeleted: RecentlyDeleted.State.empty(),
                        savings: Savings.empty(),
                        totalSavingsBytes: 0)
    }
}

// MARK:- ACTIONS
struct SetTranscode: Action {
    let transcode: Transcode.State
}

struct SetDuplicates: Action {
    let duplicates: Duplicates.State
}

struct SetSizes: Action {
    let sizes: Sizes.State
}

struct SetRecentlyDeleted: Action {
    let recentlyDeleted: RecentlyDeleted.State
}

struct SetSavings: Action {
    let savings: Savings
}

struct SetTotalSavingsBytesFromiCloud: Action {
    let totalSavingsBytes: UInt64
}

struct AppliedTranscode: Action {
    let savingsStats: Savings.Stats
}

struct AppliedDeleteDuplicates: Action {
    let savingsStats: Savings.Stats
}

// MARK:- REDUCERS
func appReducer(action: Action, state: AppState?) -> AppState {
    NSLog("appReducer action \(type(of: action))")
    var newState = state!
    switch action {
    case let action2 as SetTranscode:
        newState.transcode = action2.transcode
    case let action2 as SetDuplicates:
        newState.duplicates = action2.duplicates
    case let action2 as SetSizes:
        newState.sizes = action2.sizes
    case let action2 as SetRecentlyDeleted:
        newState.recentlyDeleted = action2.recentlyDeleted
//    case let action as SetSavings:
//        newState.savings = action.savings
    case let action as SetTotalSavingsBytesFromiCloud:
        newState.totalSavingsBytes = action.totalSavingsBytes
    case let action as AppliedTranscode:
        newState.savings.transcode = newState.savings.transcode + action.savingsStats
//        SavingsFilePersistence.write(savings: newState.savings)

        newState.totalSavingsBytes += action.savingsStats.savingsBytes
        SavingsiCloudPersistence.instance.set(totalSavingsBytes: newState.totalSavingsBytes)
    case let action as AppliedDeleteDuplicates:
        newState.savings.duplicates = newState.savings.duplicates + action.savingsStats
//        SavingsFilePersistence.write(savings: newState.savings)

        newState.totalSavingsBytes += action.savingsStats.savingsBytes
        SavingsiCloudPersistence.instance.set(totalSavingsBytes: newState.totalSavingsBytes)

    default:
        fatalError()
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

