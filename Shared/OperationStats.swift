//
//  TranscodeStats.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/7/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import UIKit

//struct OperationStats: Codable {
//    var count: Int
//    var beforeBytes: UInt64
//    var afterBytes: UInt64
//
//    func accumulate(other: OperationStats) -> OperationStats {
//        var new = self
//        new.count += other.count
//        new.beforeBytes += other.beforeBytes
//        new.afterBytes += other.afterBytes
//        return new
//    }
//    
//    func empty() -> OperationStats {
//        return OperationStats(count: 0, beforeBytes: 0, afterBytes: 0)
//    }
//}
//
//class OperationStatsStore {
//    private static let fname = "applyTranscodeStats.json"
//    static var curPrivate = read() ?? OperationStats(count: 0, beforeBytes: 0, afterBytes: 0)
//    
//    private class func read() -> OperationStats? {
//        if Storage.fileExists(fname, in: .documents) {
//            let transcodeStats = Storage.retrieve(fname, from: .documents, as: OperationStats.self)
//            return transcodeStats
//        }
//        return nil
//    }
//
//    private class func write(transcodeStats: OperationStats) {
//        Storage.store(transcodeStats, to: .documents, as: fname)
//    }
//    
//    static var current: OperationStats {
//        return curPrivate
//    }
//
//    class func add(transcodeStats: OperationStats) {
//        curPrivate = curPrivate.accumulate(other: transcodeStats)
//        write(transcodeStats: curPrivate)
//    }
//}
