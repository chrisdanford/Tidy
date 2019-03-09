//
//  FindDuplicatesUsingMetadata.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/20/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation
import Photos

class FindDuplicatesUsingMetadata {
    enum MatchMode {
        case createDateAndDurationAndAspectRatio
        case exactMatchNotUsingResources
        case exactMatchUsingResources
        
        var useDimensions: Bool {
            switch self {
            case .createDateAndDurationAndAspectRatio:
                return false
            case .exactMatchNotUsingResources, .exactMatchUsingResources:
                return true
            }
        }
        
        var useResources: Bool {
            switch self {
            case .createDateAndDurationAndAspectRatio, .exactMatchNotUsingResources:
                return false
            case .exactMatchUsingResources:
                return true
            }
        }
    }

    class func filterToDupes(assets: [PHAsset], matchMode: MatchMode, progress: ((Duplicates.Groups) -> ())? = nil) -> Duplicates.Groups {

        struct AssetIdentifyingInfo: Hashable {

            // Used in all depths
            let creationDatePrecisionTruncated: Int
            let durationPrecisionTruncated: Int
            let aspectRatioPrecisionTruncated: Int

            // Used in depth2 and depth3
            let pixelWidth: Int
            let pixelHeight: Int
            
            // Used in depth 3
            let sizeBytes: UInt64
            let fileName: String?
            
            static func from(asset: PHAsset, matchMode: MatchMode) -> AssetIdentifyingInfo {
                // We qualitize the date to the second.  I encountered one duplicate pair where the sub-second precision was truncated:
                //
                // ▿ some : 2017-05-04 09:44:21 +0000
                //  - timeIntervalSinceReferenceDate : 515583861.0
                // ▿ some : 2017-05-04 09:44:21 +0000
                //  - timeIntervalSinceReferenceDate : 515583861.135361
                let creationDatePrecisionTruncated = Int(asset.creationDate!.timeIntervalSinceReferenceDate)
                
                // We quantize to the tenth of a second.  I'm finding Quicktime/MP4 container dupes that are not the same length to the 1000th of a second.
                //
                // (lldb) po asset["IMG_7002.MOV"].duration
                // - duration : 62.432
                // (lldb) po asset["IMG_7002.mp4"].duration
                // - duration : 62.433
                let durationPrecisionTruncated = Int(asset.duration * 100)
                
                let aspectRatioPrecisionTruncated = Int(Float(asset.pixelWidth) * 100.0 / Float(asset.pixelHeight))
                
                let (pixelWidth, pixelHeight) = matchMode.useDimensions ? (asset.pixelWidth, asset.pixelHeight) : (0, 0)
                
                // Avoid accessing resourceStats unless `useSize` is set.
                let resourceStats = (matchMode.useResources) ? asset.slow_resourceStats : nil
                let sizeBytes = resourceStats?.totalResourcesSizeBytes ?? 0
                let fileName = resourceStats?.originalFileName
                
                return AssetIdentifyingInfo(creationDatePrecisionTruncated: creationDatePrecisionTruncated,
                                            durationPrecisionTruncated: durationPrecisionTruncated,
                                            aspectRatioPrecisionTruncated: aspectRatioPrecisionTruncated,
                                            pixelWidth: pixelWidth,
                                            pixelHeight: pixelHeight,
                                            sizeBytes: sizeBytes,
                                            fileName: fileName)
            }
        }
        
        let queue = DispatchQueue(label: "duplicates")
        var keyToAssets: [AssetIdentifyingInfo: [PHAsset]] = [:]
        var isFetching = true

        func calculateResult() -> Duplicates.Groups {
            var isFetchingCopy: Bool?
            var keyToAssetsCopy: [AssetIdentifyingInfo: [PHAsset]]?
            queue.sync {
                isFetchingCopy = isFetching
                keyToAssetsCopy = keyToAssets
            }
            let groups = keyToAssetsCopy!.values.filter({ $0.count >= 2 }).compactMap({ Duplicates.Group.resolveDuplicates(assets: $0) })
            return Duplicates.Groups(isFetching: isFetchingCopy!, groups: groups)
        }
        
        let emitProgressThrottled = throttle(maxFrequency: 0.5) {
            progress?(calculateResult())
        }

        
        for asset in assets {
            if asset.creationDate != nil {
                let key = AssetIdentifyingInfo.from(asset: asset, matchMode: matchMode)
                queue.sync {
                    var matchingAssets = keyToAssets[key] ?? []
                    matchingAssets.append(asset)
                    keyToAssets[key] = matchingAssets
                }
                emitProgressThrottled()
            }
        }
        queue.sync {
            isFetching = false
        }
        emitProgressThrottled()

//        let meat = assets.filter { (asset) -> Bool in
//            return asset.slow_resourceStats.originalFileName == "IMG_7002.mp4" || asset.slow_resourceStats.originalFileName == "IMG_7002.MOV"
//        }
//        let meatInfo = meat.map { AssetIdentifyingInfo.from(asset: $0, canUseResources: true) }
        
//        let filteredAssetGroups2 = filteredAssetGroups.filter { (assets) -> Bool in
//            let first = assets[0]
//            let rest = assets.suffix(from: 1)
//            let restMatchesFirst = rest.map{ first.creationDate!.compare($0.creationDate!) == .orderedSame }
//            let anyDontMatchFirst = restMatchesFirst.reduce(true, { $0 && !$1 })
//            return anyDontMatchFirst
//        }
        return calculateResult()
    }
}
