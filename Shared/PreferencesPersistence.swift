//
//  PreferencesPersistence.swift
//  Tidy iOS
//
//  Created by Chris Danford on 3/10/19.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation

struct Preferences {
    struct State {
        var totalSavingsBytes: UInt64
        var lastVersionPromptedForReview: String?
        
        static func empty() -> State {
            return State(totalSavingsBytes: 0, lastVersionPromptedForReview: nil)
        }
    }
    
    class Persistence {
        static var instance = Persistence()
        
        private let totalSavingsBytesKey = "totalSavingsBytes"
        private let lastVersionPromptedForReviewKey = "lastVersionPromptedForReview"

        init() {
            NotificationCenter.default.addObserver(self, selector: #selector(onUbiquitousKeyValueStoreDidChangeExternally(notification:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)
            readRemoteChanges()
        }
        
        func readRemoteChanges() {
            if !NSUbiquitousKeyValueStore.default.synchronize() {
                NSLog("NSUbiquitousKeyValueStoresynchronize failed")
            }
        }
        
        func read() -> State {
            return State(totalSavingsBytes: totalSavingsBytes, lastVersionPromptedForReview: lastVersionPromptedForReview)
        }
        
        func save(state: State) {
            save(totalSavingsBytes: state.totalSavingsBytes)
            save(lastVersionPromptedForReview: state.lastVersionPromptedForReview)
        }

        private func save(totalSavingsBytes: UInt64) {
            let value = Int64(totalSavingsBytes)
            NSUbiquitousKeyValueStore.default.set(value, forKey: totalSavingsBytesKey)
        }

        private func save(lastVersionPromptedForReview: String?) {
            NSUbiquitousKeyValueStore.default.set(lastVersionPromptedForReview, forKey: lastVersionPromptedForReviewKey)
        }

        private var totalSavingsBytes: UInt64 {
            let hasValue = NSUbiquitousKeyValueStore.default.object(forKey: totalSavingsBytesKey) != nil
            let totalStorageBytes = hasValue ? NSUbiquitousKeyValueStore.default.longLong(forKey: totalSavingsBytesKey) : 0
            return UInt64(totalStorageBytes)
        }
        
        private var lastVersionPromptedForReview: String? {
            return NSUbiquitousKeyValueStore.default.string(forKey: lastVersionPromptedForReviewKey)
        }
        
        private var state: State {
            return State(totalSavingsBytes: totalSavingsBytes, lastVersionPromptedForReview: lastVersionPromptedForReview)
        }

        @objc func onUbiquitousKeyValueStoreDidChangeExternally(notification:Notification)
        {
            print("onUbiquitousKeyValueStoreDidChangeExternally")
            //        if let userInfo = notification.userInfo {
            //            if let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber {
            //                print("Change reason = \(changeReason)")
            //            }
            //            if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            //                print("ChangedKeys = \(changedKeys)")
            //            }
            //        }
            dispatch(AppAction.SetPreferences(preferences: state))
        }
    }
}
