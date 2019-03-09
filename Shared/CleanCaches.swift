//
//  CleanCaches.swift
//  Tidy iOS
//
//  Created by Chris Danford on 3/5/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation
import Photos

class CleanCaches {
    // Remove items from cache that don't match any existing PHAsset
    static func cleanCaches(imageAssets: [PHAsset], videoAssets: [PHAsset]) {
        
        let imageKeys = Set(imageAssets.map({ $0.localIdentifier }))
        let videoKeys = Set(videoAssets.map({ $0.localIdentifier }))
        let allKeys = imageKeys.union(videoKeys)
        
        Caches.resourceStatsCache.filterToKeys(keys: allKeys)
        Caches.videoCodecCache.filterToKeys(keys: videoKeys)
        
        // The transcoded cache files may have been cleared.
        let videosWithExistingTranscodedFile = videoAssets.compactMap({ (asset) -> (PHAsset, URL?)? in
            if let transcodeStats = asset.transcodeStatsCached {
                let needsTranscodedFile = transcodeStats.shouldApplyTranscode
                if needsTranscodedFile {
                    let url = asset.transcodedCacheFileURL
                    if FileManager.default.fileExists(atPath: url.path) {
                        return (asset, url)
                    } else {
                        NSLog("transcodeStats exist and shouldApplyTranscode, but file doesn't \(String(describing: asset.slow_resourceStats.originalFileName)) \(asset.localIdentifier)")
                    }
                } else {
                    return (asset, nil)
                }
            }
            return nil
        })
        
        let videosWithTranscodedFileKeys = Set(videosWithExistingTranscodedFile.map({ $0.0.localIdentifier }))
        let lastPathComponentsToKeep = Set(videosWithExistingTranscodedFile.compactMap({ $0.1?.lastPathComponent }))
        
        Caches.transcodeStatsCache.filterToKeys(keys: videosWithTranscodedFileKeys)
        TranscodedCacheFiles.clearUnused(lastPathComponentsToKeep: lastPathComponentsToKeep)
    }
    
//    // If the app terminates mid-transcode, we might leave behind temp files.
//    // Since these could be huge, clean them up periodically.
//    // The system would clean temp files eventually, but since we know that there's no chance of re-use,
//    static func cleanTemp() {
//        let dir = FileManager.default.temporaryDirectory
//
//        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: []) {
//            for file in files {
//                do {
//                    try FileManager.default.removeItem(at: file)
//                } catch {
//                    NSLog("failed to delete temp file \(file)")
//                }
//            }
//        }
//    }
}
