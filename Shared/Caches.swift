//
//  Caches.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/19/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Photos

class Caches {
    static let resourceStatsCache = Cache<String, PHAsset.ResourceStats>(filenamePrefix: "resourceStats", currentCacheVersion: 3)
    static let videoCodecCache = Cache<String, AVAsset.VideoCodec>(filenamePrefix: "videoCodec", currentCacheVersion: 3)
    static let transcodeStatsCache = Cache<String, AVAsset.TranscodeSuccessStats>(filenamePrefix: "transcodeStats", currentCacheVersion: 4)
}
