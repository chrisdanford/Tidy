//
//  AppManager.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/10/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation
import ReSwift

struct BriefStatus {
    var isScanning: Bool
    enum Badge {
        case none
        case bytes(UInt64)
        case count(Int)
        
        var message: String? {
            switch self {
            case .none:
                return nil
            case .bytes(let bytes):
                return (bytes == 0) ? nil : bytes.formattedCompactByteString
            case .count(let count):
                return (count == 0) ? nil : count.formattedDecimalString
            }
        }
    }
    var badge: Badge
    
    static func empty() -> BriefStatus {
        return BriefStatus(isScanning: true, badge: .none)
    }
}

class AppManager {
    static let queue = DispatchQueue(label: "AppManager")
    static var privateInstance = AppManager()
    static var instance: AppManager {
        var copy: AppManager?
        queue.sync {
            copy = privateInstance
        }
        return copy!
    }

    static func resetAndFetch() {
        queue.sync {
            privateInstance.cancel()
            FetchAssets.clear()
            privateInstance = AppManager()
            privateInstance.fetchAll()
        }
    }

    var store = mainStore
    private var cancellationTokenSource = CancellationTokenSource()

    func cancel() {
        cancellationTokenSource.cancel()
    }
    
    private func internalDispatch(_ action: Action) {
        if !cancellationTokenSource.isCancelling {
            dispatch(action)
        }
    }
    
    func fetchAll() {
        NSLog("clearAndFetchAll start")
        cancellationTokenSource = CancellationTokenSource()
        NSLog("clearAndFetchAll 1")
        fetchTranscode(cancellationToken: cancellationTokenSource.token)
        NSLog("clearAndFetchAll 3")
        fetchDuplicates()
        NSLog("clearAndFetchAll 4")
        fetchSizes()
        fetchLargeFiles()
        NSLog("clearAndFetchAll 5")
        fetchRecentlyDeleted()
        NSLog("clearAndFetchAll 6")
        fetchPreferences()
        NSLog("clearAndFetchAll 7")
    }

    func appliedDeletedDuplicates(stats: Savings.Stats) {
        internalDispatch(AppAction.appliedDeleteDuplicates(stats))
    }
    func appliedTranscode(stats: Savings.Stats) {
        internalDispatch(AppAction.appliedTranscode(stats))
    }
    func deletedAsset(stats: Savings.Stats) {
        internalDispatch(AppAction.deletedAsset(stats))
    }
    func setLastReviewRequestedAppVersion(currentVer: String) {
        internalDispatch(AppAction.setLastReviewRequestedAppVersion(currentVer))
    }
    func setPreferences(preferences: Preferences.State) {
        internalDispatch(AppAction.setPreferences(preferences))
    }
    private func fetchTranscode(cancellationToken: CancellationToken) {
        self.internalDispatch(AppAction.setTranscode(.empty()))
        Transcode.fetch(cancellationToken: cancellationToken) { [weak self] transcode2 in
            self?.internalDispatch(AppAction.setTranscode(transcode2))
        }
    }
    private func fetchDuplicates() {
        self.internalDispatch(AppAction.setDuplicates(.empty()))
        Duplicates.fetch() { [weak self] duplicates2 in
            self?.internalDispatch(AppAction.setDuplicates(duplicates2))
        }
    }
    private func fetchSizes() {
        self.internalDispatch(AppAction.setSizes(.empty()))
        Sizes.fetch() { [weak self] sizes2 in
            self?.internalDispatch(AppAction.setSizes(sizes2))
        }
    }
    private func fetchLargeFiles() {
        self.internalDispatch(AppAction.setLargeFiles(.empty()))
        LargeFiles.fetch { [weak self] largeFiles in
            self?.internalDispatch(AppAction.setLargeFiles(largeFiles))
        }
    }
    func fetchRecentlyDeleted() {
        self.internalDispatch(AppAction.setRecentlyDeleted(.empty()))
        RecentlyDeleted.fetch() { [weak self] recentlyDeleted2 in
            self?.internalDispatch(AppAction.setRecentlyDeleted(recentlyDeleted2))
        }
    }
    private func fetchPreferences() {
//        if let savings = SavingsFilePersistence.read() {
//            self.internalDispatch(SetSavings(savings: savings))
//        }
        let preferences = Preferences.Persistence.instance.read()
        self.internalDispatch(AppAction.setPreferences(preferences))
    }
}
