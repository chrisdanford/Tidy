//
//  Cache2.swift
//  Tidy iOS
//
//  Created by Chris Danford on 1/29/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation

class Cache<K, V: Codable> where K : Hashable, K: Codable {
    let queue: DispatchQueue
    let filenamePrefix: String
    let currentCacheVersion: Int
    var dir: URL {
        let dir = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let dir2 = dir.appendingPathComponent(filenamePrefix)
        return try! VersionedDirectory.createDirectory(forBaseDirectory: dir2, version: currentCacheVersion)
    }
    var file: URL {
        return dir.appendingPathComponent(filenamePrefix + ".plist")
    }
    
    var dict: [K: V] = [:]
    var throttledPersistToDisk: () -> () = { }
    
    init(filenamePrefix: String, currentCacheVersion: Int) {
        queue = DispatchQueue(label: "cache-\(filenamePrefix)")
        self.filenamePrefix = filenamePrefix
        self.currentCacheVersion = currentCacheVersion
        
        // lower than the time the app can spend in the background so that will flush before being suspended.
        let flushInterval: Double = 5
        
        throttledPersistToDisk = throttle(maxFrequency: flushInterval) { [weak self] in
            self?.writeToDisk()
        }
        loadFromDisk()
    }
    
    func loadFromDisk() {
        queue.sync {
            NSLog("loadFromDisk self.dict 1 \(self.dict)")
            let dataFromDisk = self.readFromDisk()
            self.dict = dataFromDisk ?? [:]
            NSLog("loadFromDisk self.dict 2 \(self.dict)")
        }
    }
    
    func get(key: K) -> V? {
        var value: V?
        queue.sync {
            value = dict[key]
        }
        return value
    }

    func get(key: K, computeValue: () -> V?) -> V? {
        var value: V?
        queue.sync {
            value = dict[key]
            if value == nil {
                value = computeValue()
                if value != nil {
                    dict[key] = value
                    self.throttledPersistToDisk()
                }
            }
        }
        return value
    }

    func put(key: K, value: V) {
        queue.sync {
            dict[key] = value
        }
        self.throttledPersistToDisk()
    }
    
    func filterToKeys(keys: Set<K>) {
        var changed = false
        queue.sync {
            let count = dict.count
            dict = dict.filter({ keys.contains($0.key) })
            if count != dict.count {
                changed = true
                NSLog("before \(count) and after \(dict.count)")
            }
        }
        if changed {
            self.throttledPersistToDisk()
        }
    }
    
    private func readFromDisk() -> [K: V]? {
        do {
            let data = try Data(contentsOf: file)
            let decoder = PropertyListDecoder()
            return try decoder.decode([K:V].self, from: data)
        } catch let error {
            NSLog("readFromDisk error: \(error)")
            return nil
        }
    }
    
    private func writeToDisk() {
        var dictCopy: [K: V]?
        queue.sync {
            dictCopy = self.dict
        }
        let encoder = PropertyListEncoder()
        do {
            let data = try encoder.encode(dictCopy)
            try data.write(to: file)
        } catch let error {
            NSLog("writeToDisk error: \(error)")
        }
    }
}
