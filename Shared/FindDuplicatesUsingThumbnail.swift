//
//  FindDuplicatesUsingThumbnail.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/20/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation
//import CocoaImageHashing
import Photos

extension PHAsset {
    var thumbnailSync: UIImage {
        let semaphore = DispatchSemaphore(value: 0)
        var result: UIImage?
        let targetSize = CGSize(width: 300, height: 300)  // The smallest thumbnail possible
        let options = PHImageRequestOptions()
        
//        options.isNetworkAccessAllowed = true
//        options.deliveryMode = .highQualityFormat
        PHImageManager.default().requestImage(for: self, targetSize: targetSize, contentMode: .aspectFit, options: options) { (image, info) in
            result = image
            semaphore.signal()
        }
        semaphore.wait()
        return result!
    }
}

//
// Wrapper around CocoaImageHashing's very Objective-C-y API.
//
class FindDuplicatesUsingThumbnail {
    enum Strictness {
        case similar
        case closeToIdentical
    }
    private class func findDupes(assets: [PHAsset], strictness: Strictness) -> [[PHAsset]] {
//        let toCheckTuples: [OSTuple<NSString, NSData>] = assets.enumerated().map { (index, asset) -> OSTuple<NSString, NSData> in
//            let imageData = asset.thumbnailSync.pngData()!
//            return OSTuple<NSString, NSData>.init(first: "\(index)" as NSString, andSecond: imageData as NSData)
//        }
//
//        let providerId = OSImageHashingProviderIdForHashingQuality(.medium)
//        let provider = OSImageHashingProviderFromImageHashingProviderId(providerId);
//        let defaultHashDistanceTreshold = provider.hashDistanceSimilarityThreshold()
//        let hashDistanceTreshold: Int64
//        switch strictness {
//        case .similar: hashDistanceTreshold = defaultHashDistanceTreshold
//        case .closeToIdentical: hashDistanceTreshold = 1
//        }
//
//        // I'm seeing some thumnails of low-light high-quality (4K) videos not being detected as duplicates.
//        // Making the thumbnail size very high (1000) and very low (10) isn't changing the result.
//        // Increase the hash distance so that we're a little more accepting of these.
//
//        let similarImageIdsAsTuples = OSImageHashing.sharedInstance().similarImages(withProvider: providerId, withHashDistanceThreshold: hashDistanceTreshold, forImages: toCheckTuples)
//        var duplicateGroups = [[PHAsset]]()
//        var assetToGroupIndex = [PHAsset: Int]()
//        for pair in similarImageIdsAsTuples {
//            let assetIndex1 = Int(pair.first! as String)!
//            let assetIndex2 = Int(pair.second! as String)!
//            let asset1 = assets[assetIndex1]
//            let asset2 = assets[assetIndex2]
//            let groupIndex1 = assetToGroupIndex[asset1]
//            let groupIndex2 = assetToGroupIndex[asset2]
//            if groupIndex1 == nil && groupIndex2 == nil {
//                // new group
//                duplicateGroups.append([asset1, asset2])
//                let groupIndex = duplicateGroups.count - 1
//                assetToGroupIndex[asset1] = groupIndex
//                assetToGroupIndex[asset2] = groupIndex
//            } else if groupIndex1 == nil && groupIndex2 != nil {
//                // add 1 to 2's group
//                duplicateGroups[groupIndex2!].append(asset1)
//                assetToGroupIndex[asset1] = groupIndex2!
//            } else if groupIndex1 != nil && groupIndex2 == nil {
//                // add 2 to 1's group
//                duplicateGroups[groupIndex1!].append(asset2)
//                assetToGroupIndex[asset2] = groupIndex1!
//            }
//        }
        return []
        //return duplicateGroups
    }

    // Known problem: This doesn't work very well on images that have a lot of black.  It's not detecting them as duplicates
    class func filterToDupes(assets: [PHAsset], strictness: Strictness) -> Duplicates.Groups {
        let groups = findDupes(assets: assets, strictness: strictness).compactMap({ (assets) -> Duplicates.Group? in
            return Duplicates.Group.resolveDuplicates(assets: assets)
        })
        return Duplicates.Groups(isFetching: false, groups: groups)
    }
}


