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
    var readySavingsBytes: UInt64
    var estimatedEventualSavingsBytes: UInt64?
    var badgeMessage: String? {
        if let bytes = estimatedEventualSavingsBytes {
            if bytes > 0 {
                return "~" + bytes.formattedCompactByteString
            }
        }
        if readySavingsBytes > 0 {
            return readySavingsBytes.formattedCompactByteString
        }
        return nil
    }
    
    static func + (lhs: BriefStatus, rhs: BriefStatus) -> BriefStatus {
        let estimatedEventualSavingsBytesItems = [lhs, rhs].compactMap({$0.estimatedEventualSavingsBytes})
        let estimatedEventualSavingsBytes: UInt64?
        if estimatedEventualSavingsBytesItems.count == 0 {
            estimatedEventualSavingsBytes = nil
        } else {
            estimatedEventualSavingsBytes = estimatedEventualSavingsBytesItems.reduce(0, { $0 + $1 } )
        }
        
        return BriefStatus(isScanning: lhs.isScanning || rhs.isScanning, readySavingsBytes: lhs.readySavingsBytes + rhs.readySavingsBytes, estimatedEventualSavingsBytes: estimatedEventualSavingsBytes)
    }
    static func empty() -> BriefStatus {
        return BriefStatus(isScanning: true, readySavingsBytes: 0, estimatedEventualSavingsBytes: nil)
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
        DispatchQueue.global().async {
            self.fetchAllInternal()
        }
    }
    func fetchAllInternal() {
        NSLog("clearAndFetchAll start")
        cancellationTokenSource = CancellationTokenSource()
        NSLog("clearAndFetchAll 1")
        fetchTranscode(cancellationToken: cancellationTokenSource.token)
        NSLog("clearAndFetchAll 3")
        fetchDuplicates()
        NSLog("clearAndFetchAll 4")
        fetchSizes()
        NSLog("clearAndFetchAll 5")
        fetchLargeFiles()
        NSLog("clearAndFetchAll 6")
        fetchRecentlyDeleted()
        NSLog("clearAndFetchAll 7")
        fetchPreferences()
        NSLog("clearAndFetchAll 8")
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
        let preferences = Preferences.Persistence.instance.read()
        self.internalDispatch(AppAction.setPreferences(preferences))
    }
}
