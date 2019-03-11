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
