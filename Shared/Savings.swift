//
//  Savings.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/16/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation

struct Savings: Codable {
    struct Stats: Codable {
        var count: Int  // converted or deleted
        var beforeBytes: UInt64
        var afterBytes: UInt64
        
        var savingsBytes: UInt64 {
            let diff = beforeBytes - afterBytes
            let clamped = diff > 0 ? diff : 0
            return UInt64(clamped)
        }
        
        static func + (lhs: Stats, rhs: Stats) -> Stats {
            return Stats(count: lhs.count + rhs.count, beforeBytes: lhs.beforeBytes + rhs.beforeBytes, afterBytes: lhs.afterBytes + rhs.afterBytes)
        }
        
        static func empty() -> Stats {
            return Stats(count: 0, beforeBytes: 0, afterBytes: 0)
        }
    }
    
    var transcode: Stats
    var duplicates: Stats
    
    var total: Stats {
        return transcode + duplicates
    }

    static func empty() -> Savings {
        return Savings(transcode: .empty(), duplicates: .empty())
    }
}

//class SavingsFilePersistence {
//    private static let fname = "applyTranscodeStats.json"
//
//    static func read() -> Savings? {
//        if let transcodeStats = try? Storage.retrieve(fname, from: .documents, as: Savings.self) {
//            return transcodeStats
//        }
//        return nil
//    }
//
//    static func write(savings: Savings) {
//        Storage.store(savings, to: .documents, as: fname)
//    }
//}

class SavingsiCloudPersistence {
    static var instance = SavingsiCloudPersistence()
    
    private let key = "totalSavingsBytes"
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(onUbiquitousKeyValueStoreDidChangeExternally(notification:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)
        readRemoteChanges()
    }
    
    func readRemoteChanges() {
        if !NSUbiquitousKeyValueStore.default.synchronize() {
            NSLog("NSUbiquitousKeyValueStoresynchronize failed")
        }
    }
    
    func set(totalSavingsBytes: UInt64) {
        let value = Int64(totalSavingsBytes)
        NSUbiquitousKeyValueStore.default.set(value, forKey: key)
    }

    var totalSavingsBytes: UInt64 {
        let hasValue = NSUbiquitousKeyValueStore.default.object(forKey: key) != nil
        let totalStorageBytes = hasValue ? NSUbiquitousKeyValueStore.default.longLong(forKey: key) : 0
        return UInt64(totalStorageBytes)
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
        dispatch(SetTotalSavingsBytesFromiCloud(totalSavingsBytes: totalSavingsBytes))
    }
}
