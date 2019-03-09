//
//  PhotoKitReplace.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/7/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Photos

class PHAssetReplace {
    struct AssetCollectionAndIndex {
        let assetCollection: PHAssetCollection
        let indexInCollection: Int
    }

    class func indexInCollection(identifier: String, collection: PHAssetCollection) -> Int? {
        let fetchResult = PHAsset.fetchAssets(in: collection, options: nil)
        for idx in 0..<fetchResult.count {
            let item = fetchResult.object(at: idx)
            if item.localIdentifier == identifier {
                return idx
            }
        }
        return nil
    }
    
    class func collectionsFor(asset: PHAsset) -> [AssetCollectionAndIndex] {
        var results: [AssetCollectionAndIndex] = []
        
        // get albums and indexes
        let fetchOptions = PHFetchOptions.init()
        fetchOptions.includeHiddenAssets = true
        let fetchResult = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: fetchOptions)
        for index in 0..<fetchResult.count {
            let collection = fetchResult.object(at: index)
            let assetIndex = indexInCollection(identifier: asset.localIdentifier, collection: collection)
            results.append(AssetCollectionAndIndex(assetCollection: collection, indexInCollection: assetIndex!))
        }
        return results
    }
    
    enum ProgressType {
        case preparingBatchOfSize(Int)
        case appliedSavings(Savings.Stats)
    }
    enum Result {
        case success
        case cancelledOrError(Error)
    }
    enum ProgressOrResult {
        case progress(ProgressType)
        case result(Result)
    }

    static let maxBatchCount = 100
    static let maxBatchSizeBytes: UInt64 = 4 * 1024 * 1024 * 1024
    static let maximumQueuedBytesToApplyBeforePausing = maxBatchSizeBytes * 10

    class func calculateBatchSize(assets: [PHAsset]) -> Int {
        // If we try to apply too many changes at once (e.g. 650 new videos at once on and iPhone XS Max on iOS 12.1)
        // then the performChanges call dies with the following in the console:
        //    [GatekeeperXPC] Connection to assetsd was interrupted or assetsd died
        //
        // Whether or not this error occurs seems to depend on the contents of the batch.  I'm seeing that a very large
        // file in the batch will cause the problem, and a smaller batch allows the changes to complete.  So,
        var size: UInt64 = 0
        for (i, asset) in assets.enumerated() {
            size += asset.slow_resourceStats.totalResourcesSizeBytes
            if size > maxBatchSizeBytes || i == maxBatchCount {
                return i
            }
        }
        return assets.count
    }
    
    class func replaceWithTranscoded(assets: [PHAsset], callback: @escaping (ProgressOrResult) -> Void) {

        var remainingAssets = assets
        
        func nextStep() {
            if remainingAssets.count == 0 {
                callback(.result(.success))
                return
            }
            
            // Bit off a chunk of assets.
            let batchSize = calculateBatchSize(assets: remainingAssets)
            let chunkOfAssets = remainingAssets.prefix(batchSize)
            remainingAssets = Array(remainingAssets.suffix(from: chunkOfAssets.count))
            
            callback(.progress(.preparingBatchOfSize(batchSize)))
            
            privateReplaceWithTranscoded(assets: chunkOfAssets) { progressOrResult in
                // Kick off the next batch on "success", otherwise forward along the progress.
                switch progressOrResult {
                case .result(let result):
                    switch result {
                    case .success:
                        nextStep()
                        return
                    default:
                        break
                    }
                default:
                    break
                }
                callback(progressOrResult)
            }
        }

        nextStep()
    }
    
    private class func privateReplaceWithTranscoded(assets: ArraySlice<PHAsset>, callback: @escaping (ProgressOrResult) -> Void) {
        var savings: Savings.Stats? = nil
        PHPhotoLibrary.shared().performChanges({

            // Tricky: be careful not to access "slow_resourceStats" more than once per asset.  It takes about 1ms on an iPhone XS.
            // Optimization opportunity: Gather this information while scanning then use it here.
            var totalOriginalBytes = UInt64(0)
            var totalTranscodedBytes = UInt64(0)
            var originalFileNames = [String]()
            for asset in assets {
                let resourceStats = asset.slow_resourceStats
                totalOriginalBytes = totalOriginalBytes + resourceStats.totalResourcesSizeBytes
                totalTranscodedBytes = totalTranscodedBytes + asset.transcodedCacheFileURL.fileSize
                originalFileNames.append(resourceStats.originalFileName ?? "video")
            }

            
            savings = Savings.Stats(count: assets.count, beforeBytes: totalOriginalBytes, afterBytes: totalTranscodedBytes)

            let assetAndOriginalFileNames = zip(assets, originalFileNames)
            
            for (asset, originalFileName) in assetAndOriginalFileNames {
                let updatedFName = URL(fileURLWithPath: originalFileName).deletingPathExtension().appendingPathExtension("mov")
        

                let tmp = try! TemporaryFile(creatingTempDirectoryForFilename: updatedFName.path)
                do {
                    try FileManager.default.copyItem(at: asset.transcodedCacheFileURL, to: tmp.fileURL)
                } catch let error {
                    NSLog("Error copying file: \(error).  Skipping.")
                    continue
                }


                // Create the new asset with identical metadata to the original.
                let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tmp.fileURL)!
                creationRequest.creationDate = asset.creationDate
                creationRequest.location = asset.location
                creationRequest.isFavorite = asset.isFavorite
                creationRequest.isHidden = asset.isHidden
                let assetPlaceholder = creationRequest.placeholderForCreatedAsset!

                // Add the new asset to the collections of the original.
                for assetInCollection in self.collectionsFor(asset: asset) {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetInCollection.assetCollection)!
                    albumChangeRequest.insertAssets([assetPlaceholder] as NSArray, at: [assetInCollection.indexInCollection])
                }

                // Delete the original asset.
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }
        }, completionHandler: { (success, error) in
            if let error2 = error {
//                if let nsError = error2 as NSError {
//                }
                NSLog("failed to perform changes \(error2)")
                callback(.result(.cancelledOrError(error2)))
            } else {
                // Now that the original assets have been deleted, remove the deleted assets transcoded files.
                for asset in assets {
                    do {
                        try FileManager.default.removeItem(at: asset.transcodedCacheFileURL)
                    } catch let error {
                        NSLog("Failed to remove applied trancoded file \(asset.transcodedCacheFileURL), error \(error)")
                    }
                }
                
                callback(.progress(.appliedSavings(savings!)))
                callback(.result(.success))
            }
        })
    }
}
