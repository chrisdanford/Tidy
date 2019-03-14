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
    
    var data: [K: V] = [:]
    var throttledPersistToDisk: () -> () = { }
    
    init(filenamePrefix: String, currentCacheVersion: Int) {
        queue = DispatchQueue(label: "cache-\(filenamePrefix)")
        self.filenamePrefix = filenamePrefix
        self.currentCacheVersion = currentCacheVersion
        
        // lower than the time the app can spend in the background so that will flush before being suspended.
        let flushInterval: Double = 5
        
        throttledPersistToDisk = throttle(maxFrequency: flushInterval) { [weak self] in
            self?.persistToDisk()
        }
        loadFromDisk()
    }
    
    func loadFromDisk() {
        // reading from cache is slow.  Do this async.
        queue.sync {
            self.data = self.dataFromDisk() ?? [:]
        }
    }
    
    private func dataFromDisk() -> [K: V]? {
        do {
            let rawData = try Data(contentsOf: file)
            let decoded = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(rawData) as? [K: V]
            if let dict = decoded {
                NSLog("Retrieved \(dict.count) items")
                return dict
            } else {
                NSLog("Unarchive failed")
                return nil
            }
        } catch {
            NSLog("Read file or unarchive failed")
            return nil
        }
    }
    
    func get(key: K) -> V? {
        var value: V?
        queue.sync {
            value = data[key]
        }
        return value
    }

    func get(key: K, computeValue: () -> V?) -> V? {
        var value: V?
        queue.sync {
            value = data[key]
            if value == nil {
                value = computeValue()
                if value != nil {
                    data[key] = value
                    self.throttledPersistToDisk()
                }
            }
        }
        return value
    }

    func put(key: K, value: V) {
        queue.sync {
            data[key] = value
        }
        self.throttledPersistToDisk()
    }
    
    func filterToKeys(keys: Set<K>) {
        var changed = false
        queue.sync {
            let count = data.count
            data = data.filter({ keys.contains($0.key) })
            if count != data.count {
                changed = true
                NSLog("before \(count) and after \(data.count)")
            }
        }
        if changed {
            self.throttledPersistToDisk()
        }
    }
    
    func persistToDisk() {
        var data: Data? = nil
        queue.sync {
            do {
                data = try NSKeyedArchiver.archivedData(withRootObject: self.data, requiringSecureCoding: false)
            } catch {
                NSLog("encode Failed")
            }
        }
        do {
            try data?.write(to: file, options: Data.WritingOptions.atomic)
        } catch {
            NSLog("Write Failed")
        }
    }
}
