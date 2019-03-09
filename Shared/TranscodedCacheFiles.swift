//
//  TranscodedCacheFiles.swift
//  Tidy iOS
//
//  Created by Chris Danford on 3/5/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation

class TranscodedCacheFiles {

    static let version = String(3)
    
    private static let baseDir: URL = {
        let dir = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        return dir.appendingPathComponent("transcoded", isDirectory: true)
    }()

    static let versionedDir: URL = {
        return baseDir.appendingPathComponent(version, isDirectory: true)
    }()
    
    static func clearUnused(lastPathComponentsToKeep: Set<String>) {
        clearUnusedVersions()
        clearUnusedCurrentVersionFiles(lastPathComponentsToKeep: lastPathComponentsToKeep)
    }

    private static func clearUnusedVersions() {
        // Clear directories for old versions.
        if let dirs = try? FileManager.default.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil, options: []) {
            for dir in dirs {
                if dir.lastPathComponent == version {
                    NSLog("keeping current version dir")
                } else {
                    do {
                        try FileManager.default.removeItem(at: dir)
                    } catch let error {
                        NSLog("failed to delete file: \(dir), error:\(error)")
                    }
                }
            }
        }
    }
    
    private static func clearUnusedCurrentVersionFiles(lastPathComponentsToKeep: Set<String>) {
        // Clear files in the current version directory that aren't in "urlsToKeep"
        if let files = try? FileManager.default.contentsOfDirectory(at: versionedDir, includingPropertiesForKeys: nil, options: []) {
            for file in files {
                if !lastPathComponentsToKeep.contains(file.lastPathComponent) {
                    do {
                        NSLog("removing file \(file.lastPathComponent)")
                        try FileManager.default.removeItem(at: file)
                    } catch let error {
                        NSLog("failed to delete file: \(file), error:\(error)")
                    }
                } else {
                    //NSLog("keeping file")
                }
            }
        }
    }
}
