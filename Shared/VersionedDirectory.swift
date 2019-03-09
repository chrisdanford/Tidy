//
//  VersionedDirectory.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/7/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation

class VersionedDirectory {
//    let version: Int
//    let baseDirectoryURL: URL
//    let versionedDirectoryURL: URL

    class func createDirectory(forBaseDirectory baseDirectory: URL, version: Int) throws -> URL {
        let versionedDirectoryURL = baseDirectory.appendingPathComponent(String(version))
        try? FileManager.default.createDirectory(at: versionedDirectoryURL, withIntermediateDirectories: true)

        DispatchQueue.global().async {
            for i in 0..<version {
                let versionedDirectoryURL = baseDirectory.appendingPathComponent(String(i))
                try? FileManager.default.removeItem(at: versionedDirectoryURL)
            }
        }
        
        return versionedDirectoryURL
    }
}
