//
//  PHAssetFetch.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/8/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Photos

class FetchAssets {
    static let queue = DispatchQueue(label: "FetchAssets")
    static var privateManager: Manager? = nil
    static var manager: Manager {
        var ret: Manager? = nil
        queue.sync {
            ret = privateManager
        }
        return ret!
    }
    static func clear() {
        queue.async {
            privateManager = Manager()
        }
    }
    
    class Manager {
        // Calls to PhotoKit are extremely slow and don't benefit from parallelization across threads.  So,
        // it's very important to minimize the number of calls to PhotoKit.  A key strategy is maintaining
        // one set of PHAssets and sharing them among all callers.
        private let videosInternal: [PHAsset]
        private let imagesInternal: [PHAsset]
        
        init() {
            videosInternal = Manager.fetchInternal(with: .video)
            imagesInternal = Manager.fetchInternal(with: .image)
            CleanCaches.cleanCaches(imageAssets: imagesInternal, videoAssets: videosInternal)
            //CleanCaches.cleanTemp()
        }
        
        func fetch(with mediaType: PHAssetMediaType) -> [PHAsset] {
            switch mediaType {
            case .video:
                return videosInternal
            case .image:
                return imagesInternal
            default:
                fatalError()
            }
    //        NSLog("PHAssetFetch \(mediaType.rawValue) \(date2.timeIntervalSinceNow)")
    //        return ret
        }
                
        func fetchSamples(with mediaType: PHAssetMediaType) -> [PHAsset] {
            // Photos are much more uniform in size than video because video is variable length.
            // Static numbers chosen so that the amount of time to scan is bounded not proportional to library size
            let preferredSampleSize: Int
            let assets: [PHAsset]
            switch mediaType {
            case .video:
                preferredSampleSize = 2500
            case .image:
                preferredSampleSize = 750
            default:
                fatalError()
            }

            assets = fetch(with: mediaType)

            // Sample but in a stable way so that if we have to refresh this data,
            // we end up choosing the same PHAssets that have size data cached.
            // When comupting "by", round up so that the number of samples is never greater than preferredSampleSize.
            let by = max(1, Int((Float(assets.count) / Float(preferredSampleSize)).rounded(.up)))
            let assetsSamples = stride(from: 0, to: assets.count - 1, by: by).map { return assets[$0] }

            // Shuffle so that we have a random distribution of sizes.  Otherwise, early videos will tend to be smaller.
            let shuffled = assetsSamples.shuffled()
            return shuffled
        }

        private class func getFetchResult(with mediaType: PHAssetMediaType) -> PHFetchResult<PHAsset> {
            NSLog("PHAssetFetch.fetch mediaType\(mediaType.rawValue) 1")
            let options = PHFetchOptions()
            options.includeHiddenAssets = true
            options.wantsIncrementalChangeDetails = false
            
            // We want to sort by something more specific than what's possible with this method
            //options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            
            return PHAsset.fetchAssets(with: mediaType, options: options)
        }
        
        private class func fetchInternal(with mediaType: PHAssetMediaType) -> [PHAsset] {
            let result = self.getFetchResult(with: mediaType)
            var assets = [PHAsset]()
            assets.reserveCapacity(result.count)
            // quirky: PHAssetResults need to be iterated this way
            for idx in 0..<result.count {
                let asset = result.object(at: idx)
                assets.append(asset)
            }
            
            let sortedAssets = assets.sorted(by: PHAsset.compareCreationDate)

            return sortedAssets
        }
    }
    
    static func fetchAsset(asset: PHAsset) -> PHAsset {
        return FetchAssets.fetchAsset(localIdentifier: asset.localIdentifier)
    }

    static func fetchAsset(localIdentifier: String) -> PHAsset {
        return PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)[0]
    }
}

// MARK: Compare
extension PHAsset {
    var predictedRelativeSize: Double {
        return Double(self.pixelWidth) * Double(self.pixelHeight) * self.duration
    }
    
    static func compareCreationDate(_ lhs: PHAsset, _ rhs: PHAsset) -> Bool {
        // Sort by ObjectIdentifier in the case of creationDate ties so that the order
        // of items with ties in creationDate doesn't jump around.  "localIdentifer" is slow to access.
        // "localIdentifer" is showing up in profiling.
        let l = lhs.creationDate ?? Date.distantPast
        let r = rhs.creationDate ?? Date.distantPast
        if l == r {
            return ObjectIdentifier(lhs) < ObjectIdentifier(rhs)
        } else {
            return l < r
        }
    }
    
    static func comparePredictedRelativeSize(_ lhs: PHAsset, _ rhs: PHAsset) -> Bool {
        let l = lhs.predictedRelativeSize
        let r = rhs.predictedRelativeSize
        if l == r {
            return ObjectIdentifier(lhs) < ObjectIdentifier(rhs)
        } else {
            return l < r
        }
    }
    
    class func sortedByPredictedRelativeSize(assets: [PHAsset]) -> [PHAsset] {
        let sorted = assets.sorted(by: comparePredictedRelativeSize)
        return sorted
    }

    var pixelArea: Int {
        return self.pixelWidth * self.pixelHeight
    }

    static func comparePixelArea(_ lhs: PHAsset, _ rhs: PHAsset) -> Bool {
        if lhs.pixelArea == rhs.pixelArea {
            return compareBytesSize(lhs, rhs)
        } else {
            return lhs.pixelArea < rhs.pixelArea
        }
    }

    static func compareBytesSize(_ lhs: PHAsset, _ rhs: PHAsset) -> Bool {
        if lhs.slow_resourceStats.totalResourcesSizeBytes == rhs.slow_resourceStats.totalResourcesSizeBytes {
            return ObjectIdentifier(lhs) < ObjectIdentifier(rhs)
        } else {
            return lhs.slow_resourceStats.totalResourcesSizeBytes < rhs.slow_resourceStats.totalResourcesSizeBytes
        }
    }
}
