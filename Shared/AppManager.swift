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
        fetchSavings()
        NSLog("clearAndFetchAll 7")
    }

    func appliedDeletedDuplicates(stats: Savings.Stats) {
        internalDispatch(AppAction.AppliedDeleteDuplicates(savingsStats: stats))
    }
    
    func appliedTranscode(stats: Savings.Stats) {
        internalDispatch(AppAction.AppliedTranscode(savingsStats: stats))
    }
    
    func deletedAsset(stats: Savings.Stats) {
        internalDispatch(AppAction.DeletedAsset(savingsStats: stats))
    }

    private func fetchTranscode(cancellationToken: CancellationToken) {
        self.internalDispatch(AppAction.SetTranscode(transcode: .empty()))
        Transcode.fetch(cancellationToken: cancellationToken) { [weak self] transcode2 in
            self?.internalDispatch(AppAction.SetTranscode(transcode: transcode2))
        }
    }
    private func fetchDuplicates() {
        self.internalDispatch(AppAction.SetDuplicates(duplicates: .empty()))
        Duplicates.fetch() { [weak self] duplicates2 in
            self?.internalDispatch(AppAction.SetDuplicates(duplicates: duplicates2))
        }
    }
    private func fetchSizes() {
        self.internalDispatch(AppAction.SetSizes(sizes: .empty()))
        Sizes.fetch() { [weak self] sizes2 in
            self?.internalDispatch(AppAction.SetSizes(sizes: sizes2))
        }
    }
    private func fetchLargeFiles() {
        self.internalDispatch(AppAction.SetLargeFiles(largeFiles: .empty()))
        LargeFiles.fetch { [weak self] largeFiles in
            self?.internalDispatch(AppAction.SetLargeFiles(largeFiles: largeFiles))
        }
    }
    func fetchRecentlyDeleted() {
        self.internalDispatch(AppAction.SetRecentlyDeleted(recentlyDeleted: .empty()))
        RecentlyDeleted.fetch() { [weak self] recentlyDeleted2 in
            self?.internalDispatch(AppAction.SetRecentlyDeleted(recentlyDeleted: recentlyDeleted2))
        }
    }
    private func fetchSavings() {
//        if let savings = SavingsFilePersistence.read() {
//            self.internalDispatch(SetSavings(savings: savings))
//        }
        let totalSavingsBytes = SavingsiCloudPersistence.instance.totalSavingsBytes
        self.internalDispatch(AppAction.SetTotalSavingsBytes(totalSavingsBytes: totalSavingsBytes))
    }
}
