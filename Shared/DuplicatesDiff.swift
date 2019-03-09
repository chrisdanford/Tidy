//
//  DuplicatesDiff.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/11/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation
import Photos

class DuplicatesDiff {
    struct Diff {
        struct AddAssetToCollection {
            let asset: PHAsset
            let collection: PHAssetCollection
            let indexInCollection: Int
        }

        struct UpdateAsset {
            let asset: PHAsset
            let makeFavorite: Bool
        }
        
        var stats: Savings.Stats {
            var stats = Savings.Stats.empty()
            for asset in deleteAssets {
                stats.count += 1
                stats.beforeBytes += asset.slow_resourceStats.totalResourcesSizeBytes
            }
            return stats
        }
        
        let deleteAssets: [PHAsset]
        let addAssetToCollection: [AddAssetToCollection]
        let updateAsset: [UpdateAsset]
    }

    class func createDiff(duplicateGroups: Duplicates.Groups) -> Diff {
        let date = Date()
        
        var deleteAssets = [PHAsset]()
        var addAssetToCollection = [Diff.AddAssetToCollection]()
        var updateAsset = [Diff.UpdateAsset]()

        for duplicateGroup in duplicateGroups.groups {
            let toKeepAsset = duplicateGroup.toKeep
            let toKeepCollections = PHAssetReplace.collectionsFor(asset: toKeepAsset)
            
            func toKeeepIsIn(assetCollection: PHAssetCollection) -> Bool {
                for toKeepCollection in toKeepCollections {
                    if toKeepCollection.assetCollection == assetCollection {
                        return true
                    }
                }
                return false
            }
            
            NSLog("time1 \(date.timeIntervalSinceNow)")
            
            // delete every photo except the first
            let toDeleteAssets = duplicateGroup.toDelete

            for toDeleteAsset in toDeleteAssets {
                
                if toDeleteAsset.isFavorite {
                    updateAsset.append(.init(asset: toKeepAsset, makeFavorite: true))
                }
                
                for collection in PHAssetReplace.collectionsFor(asset: toDeleteAsset) {
                    // If the toKeep asset is already in the collection, don't add.
                    if toKeeepIsIn(assetCollection: collection.assetCollection) {
                        // do nothing
                    } else {
                        let addToCollection = Diff.AddAssetToCollection(asset: toKeepAsset, collection: collection.assetCollection, indexInCollection: collection.indexInCollection)
                        addAssetToCollection.append(addToCollection)
                    }
                }
            }
            deleteAssets.append(contentsOf: toDeleteAssets)

            NSLog("time2 \(date.timeIntervalSinceNow)")
        }

        return Diff(deleteAssets: deleteAssets, addAssetToCollection: addAssetToCollection, updateAsset: updateAsset)
    }


    
    enum Result {
        case success(Savings.Stats)
        case cancelledOrError(Error)
    }
    class func applyDiff(diff: Diff, completion: @escaping (Result) -> Void) {
        let date = Date()
        
        let savingsStats = diff.stats
        
        PHPhotoLibrary.shared().performChanges({
            for addAssetToCollection in diff.addAssetToCollection {
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: addAssetToCollection.collection)!
                albumChangeRequest.insertAssets([addAssetToCollection.asset] as NSArray, at: [addAssetToCollection.indexInCollection])
            }
            PHAssetChangeRequest.deleteAssets(diff.deleteAssets as NSArray)

            for updateAsset in diff.updateAsset {
                let changeRequest = PHAssetChangeRequest(for: updateAsset.asset)
                if updateAsset.makeFavorite {
                    changeRequest.isFavorite = true
                }
            }

            NSLog("time2 \(date.timeIntervalSinceNow)")
        }, completionHandler: { (success, error) in
            if let error2 = error {
                NSLog("failed to perform changes \(error2)")
                completion(.cancelledOrError(error2))
            } else {
                completion(.success(savingsStats))
            }
        })
    }
}

