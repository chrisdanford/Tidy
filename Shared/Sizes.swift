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

            static func + (lhs: CategoryStats, rhs: CategoryStats) -> CategoryStats {
                return CategoryStats(isScanning: lhs.isScanning || rhs.isScanning, count: lhs.count + rhs.count, totalSizeBytes: lhs.totalSizeBytes + rhs.totalSizeBytes)
            }
            
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
        
        // slow_resourceStats is massively bottlenecked by RPC, so there's there's no benefit to making this multithreaded.

        func photos() {
            let assets = FetchAssets.manager.fetch(with: .image)
            queue.sync {
                state.photos.count = assets.count
            }
            func getSize(asset: PHAsset) -> UInt64 {
                return asset.slow_resourceStats.totalResourcesSizeBytes
            }
            SizeUtil.predictSize(assets: assets, getSize: getSize, progress: { (estimate) in
                queue.sync {
                    state.photos.totalSizeBytes = estimate
                }
                emitProgressThrottled()
            })
            queue.sync {
                state.photos.isScanning = false
            }
            emitProgressThrottled()
        }
        photos()
        func videos() {
            //
            // Videos are highly variable in size, and we can fairly quickly get the largest videos.
            // Fetch and accurately measure a chunk of the largest videos, then estimate the size of the
            // rest of the videos (the pool of non-largest).  This allows us to achieve an accurate measure
            // of the total library size using fewer samples than sampling randomly
            //
            let assets = FetchAssets.manager.fetch(with: .video)
            queue.sync {
                state.videos.count = assets.count
            }
            func getSize(asset: PHAsset) -> UInt64 {
                return asset.slow_resourceStats.totalResourcesSizeBytes
            }
            let (largestAssets, restAssets) = FetchAssets.manager.fetchEstimatedLargestFilesAndRest(with: .video)
            SizeUtil.predictSize(largeAssets: largestAssets, restAssets: restAssets, getSize: getSize, progress: { (estimate) in
                queue.sync {
                    state.videos.totalSizeBytes = estimate
                }
                emitProgressThrottled()
            })
            queue.sync {
                state.videos.isScanning = false
            }
            emitProgressThrottled()
        }
        videos()
    }
}
