//
//  Sizes.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/12/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation
import Photos

class Sizes {
    struct State {
        struct CategoryStats {
            var isScanning: Bool
            var count: Int
            var totalSizeBytes: UInt64

//            static func + (lhs: CategoryStats, rhs: CategoryStats) -> CategoryStats {
//                return CategoryStats(count: lhs.count + rhs.count, totalSizeBytes: lhs.totalSizeBytes + rhs.totalSizeBytes)
//            }
            
            static func empty() -> CategoryStats {
                return CategoryStats(isScanning: true, count: 0, totalSizeBytes: 0)
            }
        }

        var photos: CategoryStats
        var videos: CategoryStats

        var isScanning: Bool {
            return photos.isScanning || videos.isScanning
        }

        static func empty() -> State {
            return State(photos: .empty(), videos: .empty())
        }
    }

    class func fetch(progress: @escaping (State) -> Void) {
        let queue = DispatchQueue(label: "Sizes")
        var state = State.empty()
        
        let emitProgressThrottled = throttle(maxFrequency: 0.5) {
            var copy : State?
            queue.sync {
                copy = state
            }
            progress(copy!)
        }
        
        // Photos are much more uniform in size than video because video is variable length.
        // Static numbers chosen so that the amount of time to scan is bounded not proportional to library size
        let photosSampleSize = 750
        let videoSampleSize = 2500

        // There appears to be a global lock on slow_resourceStats that's causing a maximum throughput of 1ms/call
        // acrross all threads on my device.  So, there's no benefit to making this multithreaded.

        DispatchQueue.global().async {
            predictSize(mediaType: .image, preferredSampleSize: photosSampleSize, progress: { (stats) in
                queue.sync {
                    state.photos = stats
                }
                emitProgressThrottled()
            })
        }
        DispatchQueue.global().async {
            predictSize(mediaType: .video, preferredSampleSize: videoSampleSize, progress: { (stats) in
                queue.sync {
                    state.videos = stats
                }
                emitProgressThrottled()
            })
        }
    }
    
    class func predictSize(mediaType: PHAssetMediaType, preferredSampleSize: Int, progress: (State.CategoryStats) -> ()) {
        let assets = FetchAssets.manager.fetch(with: mediaType)
        let assetsSample = FetchAssets.manager.fetchSamples(with: mediaType)
        let totalCount = assets.count
        
        var i = 0
        var totalBytes: UInt64 = 0
        var stats = State.CategoryStats.init(isScanning: true, count: totalCount, totalSizeBytes: 0)
        for asset in assetsSample {
            i += 1
            totalBytes += asset.slow_resourceStats.totalResourcesSizeBytes
            
            let estimatedBytes = SizeUtil.estimateSum(partialSum: Float(totalBytes), numSamplesProcessed: i, totalSamples: assetsSample.count, totalElements: assets.count)

            stats.totalSizeBytes = UInt64(estimatedBytes)
            progress(stats)
        }
        stats.isScanning = false
        progress(stats)
    }
}
