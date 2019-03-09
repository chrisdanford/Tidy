//
//  Limiter.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/3/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation

class Limiter {
    private var lastExecution: Date = Date.distantPast
    private var maxFrequency: TimeInterval

    init(maxFrequency: TimeInterval) {
        self.maxFrequency = maxFrequency
    }
    
    func check() -> Bool {
        let now = Date()
        let timeSinceLastExecution = self.lastExecution.timeIntervalSince(now) * -1
        if timeSinceLastExecution > self.maxFrequency {
            self.lastExecution = now
            return true
        } else {
            return false
        }
    }
}
