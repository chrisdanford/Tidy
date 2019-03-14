//
//  FindDuplicates.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/8/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Photos

class Duplicates {
    struct Group {
        let toKeep: PHAsset
        let toDelete: [PHAsset]

        var allAssets: [PHAsset] {
            return [toKeep] + toDelete
        }

        var numAssetsToDelete: Int {
            return toDelete.count
        }
        
        var bytesToDelete: UInt64 {
            return toDelete.reduce(0) { (result, asset) -> UInt64 in
                result + asset.slow_resourceStats.totalResourcesSizeBytes
            }
        }

        public static func < (lhs: Group, rhs: Group) -> Bool {
            return PHAsset.compareCreationDate(lhs.toKeep, rhs.toKeep)
        }
        
        // Returns nil if no obvious good way to resolve.
        static func resolveDuplicates(assets: [PHAsset]) -> Group? {
            // Choose the highest resolution.
            // We expect this to also be the largest.
            let assetsByPixelArea = assets.sorted(by: PHAsset.comparePixelArea)
            let assetsBySizeBytes = assets.sorted(by: PHAsset.compareBytesSize)
            
            // We have one asset with a larger pixelArea, and one with a larger size in bytes.
            // It's not clear which is the higher quality copy, so we won't try to resolve this conflict.
            if assetsByPixelArea.last! != assetsBySizeBytes.last! {
                let names = assets.map { $0.slow_resourceStats.originalFileName }
                NSLog("No obvious best choice. assetsByPixelArea.last! != assetsBySizeBytes.last!. \(names)")
                return nil
            }
            
            let toKeep = assetsByPixelArea.last!
            let toDelete = Array(assetsByPixelArea.prefix(upTo: assetsByPixelArea.count - 1)) // "without the last"
            assert(!toDelete.contains(toKeep))
            
            let anyToDeleteHasLocation = toDelete.reduce(false, { (result, asset) -> Bool in
                return result || (asset.location != nil)
            })
            if toKeep.location == nil && anyToDeleteHasLocation {
                let names = assets.map { $0.slow_resourceStats.originalFileName }
                NSLog("No obvious best choice. toKeep.location == nil && anyToDeleteHasLocation. \(names)")
                return nil
            }
            
            return Group(toKeep: toKeep, toDelete: toDelete)
        }
    }
    
    struct Groups {
        let isFetching: Bool
        let groups: [Group]
        
        init(isFetching: Bool, groups: [Group]) {
            self.isFetching = isFetching
            self.groups = groups.sorted(by: { (lhs, rhs) -> Bool in
                lhs < rhs
            })
        }
        
        var numAssetsToDelete: Int {
            return groups.reduce(0) { (result, group) -> Int in
                return result + group.numAssetsToDelete
            }
        }
        
        var bytesToDelete: UInt64 {
            return groups.reduce(0) { (result, group) -> UInt64 in
                return result + group.bytesToDelete
            }
        }

        static func empty() -> Groups {
            return Groups(isFetching: true, groups: [])
        }
        
        static func + (lhs: Groups, rhs: Groups) -> Groups {
            return Groups(isFetching: lhs.isFetching || rhs.isFetching, groups: lhs.groups + rhs.groups)
        }
        
        var briefStatus: BriefStatus {
            return BriefStatus(isScanning: isFetching, readySavingsBytes: bytesToDelete, estimatedEventualSavingsBytes: nil)
        }
    }
    
    struct State {
        var photosExact: Groups
        var videosExact: Groups
        var videosInexact: Groups

        var badgeCount: Int {
            return [photosExact, videosExact, videosInexact].reduce(0, { $0 + $1.numAssetsToDelete })
        }
        var briefStatus: BriefStatus {
            return [photosExact, videosExact, videosInexact].reduce(BriefStatus.empty(), { (result, duplicateGroups) -> BriefStatus in
                return result + duplicateGroups.briefStatus
            })
        }

        static func empty() -> State {
            return State(photosExact: .empty(), videosExact: .empty(), videosInexact: .empty())
        }
    }

    class func fetch(progress: @escaping (State) -> Void) {
        let queue = DispatchQueue(label: "Duplicates find")
        var state = State.empty()
        
        func emitProgress() {
            var copy: State?
            queue.sync {
                copy = state
            }
            progress(copy!)
        }

        DispatchQueue.global().async {
            let videoAssets = FetchAssets.manager.fetch(with: .video)
            let videoExactMatches = findExactMatches(assets: videoAssets) { duplicateGroups in
                queue.sync {
                    state.videosExact = duplicateGroups
                }
                emitProgress()
            }
            findInexactMatches(assets: videoAssets, exactMatchDuplicateGroups: videoExactMatches) { duplicateGroups in
                queue.sync {
                    state.videosInexact = duplicateGroups
                }
                emitProgress()
            }

            let photoAssets = FetchAssets.manager.fetch(with: .image)
            let _ = findExactMatches(assets: photoAssets) { duplicateGroups in
                queue.sync {
                    state.photosExact = duplicateGroups
                }
                emitProgress()
            }
        }
    }
    
    class func findInexactMatches(assets: [PHAsset], exactMatchDuplicateGroups: Groups, progress: @escaping (Groups) -> ()) {
        // For video, createDate and duration alone are pretty unique.
        // There's no equivalent good identifying info for photos.
        // Filter out all assets that were deleted in the previous step, or else we'll
        // detect them again as deleted to be applied.
        let assetsDeletedSoFar = exactMatchDuplicateGroups.groups.flatMap({ $0.toDelete })
        let remainingAssets = Array(Set(assets).subtracting(assetsDeletedSoFar))
        let duplicateGroups = FindDuplicatesUsingMetadata.filterToDupes(assets: remainingAssets, matchMode: .createDateAndDurationAndAspectRatio, progress: progress)

        let duplicateGroups2a = refine(groups: duplicateGroups) { (assets) -> Duplicates.Groups in
            return FindDuplicatesUsingThumbnail.filterToDupes(assets: assets, strictness: .similar)
        }

        let groups3 = Groups(isFetching: false, groups: duplicateGroups2a.groups.sorted(by: {$0.toKeep.creationDate! < $1.toKeep.creationDate!}))
        
        progress(groups3)
    }

    class func refine(groups: Groups, refiner: ([PHAsset]) -> Groups) -> Groups {
        let g = groups.groups.flatMap({ (groups) -> [Group] in
            let g2 = refiner(groups.allAssets).groups
            return g2
        })
        return Groups(isFetching: false, groups: g)
    }
    
    class func findExactMatches(assets: [PHAsset], progress: @escaping (Groups) -> ()) -> Groups {
        // Look for exact creationDate matches.  It's one of the fastest criteria we can match on.
        let duplicateGroups = FindDuplicatesUsingMetadata.filterToDupes(assets: assets, matchMode: .exactMatchNotUsingResources)

        let duplicateGroups2b = refine(groups: duplicateGroups) { (assets) -> Duplicates.Groups in
            return FindDuplicatesUsingMetadata.filterToDupes(assets: assets, matchMode: .exactMatchUsingResources)
        }
        
        progress(duplicateGroups2b)
        return duplicateGroups2b
    }
}
