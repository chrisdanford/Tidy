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
            return BriefStatus(isScanning: isFetching, badge: .bytes(bytesToDelete))
        }
    }
    
    struct State {
        var photosExact: Groups
        var videosExact: Groups
        var photosInexact: Groups
        var videosInexact: Groups

        var badgeCount: Int {
            return [photosExact, videosExact, photosInexact, videosInexact].reduce(0, { $0 + $1.numAssetsToDelete })
        }

        static func empty() -> State {
            return State(photosExact: .empty(), videosExact: .empty(), photosInexact: .empty(), videosInexact: .empty())
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
            // Prioritize scanning videos over photos because they are much larger and will find savings earlier.

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
            
            // disable for now
//            findInexactMatches(assets: photoAssets, exactMatchDuplicateGroups: photoExactMatches) { duplicateGroups in
//                queue.sync {
//                    state.photosInexact = duplicateGroups
//                }
//                emitProgress()
//            }
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
//            if assets.count > 2 {
//                NSLog("foo")
//            }
            return FindDuplicatesUsingThumbnail.filterToDupes(assets: assets, strictness: .similar)
        }

//        let dupeAssets = exactMatchDuplicateGroups.groups.flatMap({ [$0.toKeep] + $0.toDelete })
//        let dupes = FindDuplicatesUsingThumbnail.filterToDupes(assets: dupeAssets)
//        let dupeAssets2 = dupes.groups.flatMap { (group) -> [PHAsset] in
//            return group.allAssets
//        }
//        let difference = Set(dupeAssets).subtracting(dupeAssets2)
//        let differenceGrouped = FindDuplicatesUsingMetadata.filterToDupes(assets: Array(difference), matchMode: .exactMatchUsingResources)
//        let differenceGrouped2 = FindDuplicatesUsingThumbnail.filterToDupes(assets: Array(difference))
//
//        NSLog("dupeAssets \(dupeAssets.count)")
//        NSLog("dupes \(dupes.groups.count)")
//        NSLog("dupeAssets2 \(dupeAssets2.count)")
//        NSLog("difference \(difference.count)")
//        NSLog("differenceGrouped \(differenceGrouped.groups.count)")
//        NSLog("differenceGrouped2 \(differenceGrouped2.groups.count)")
        let groups3 = Groups(isFetching: false, groups: duplicateGroups2a.groups.sorted(by: {$0.toKeep.creationDate! < $1.toKeep.creationDate!}))
//
//        let test = FindDuplicatesUsingThumbnail.filterToDupes(assets: groups3.groups[6].allAssets, strictness: .nearIdentical)
//        let test2 = refine(groups: test) { (assets) -> Duplicates.Groups in
//            if assets.count > 2 {
//                NSLog("foo")
//            }
//            return FindDuplicatesUsingThumbnail.filterToDupes(assets: assets, strictness: .nearIdentical)
//        }
//
//        if test2.groups.count >= 2 {
//            let assets3 = test2.groups[0].allAssets
//            let test3 = FindDuplicatesUsingThumbnail.filterToDupes(assets: assets3, strictness: .nearIdentical)
//            //.groups.map({$0.allAssets.map({$0.thumbnailSync})})
//        }
        
        progress(groups3)
    }

    class func refine(groups: Groups, refiner: ([PHAsset]) -> Groups) -> Groups {
        let g = groups.groups.flatMap({ (groups) -> [Group] in
            let g2 = refiner(groups.allAssets).groups
//            if g2.count != 1 {
//                NSLog("refined g2 into \(g2.count) groups from groups.allAssets \(groups.allAssets) \(groups.allAssets.map({$0.slow_resourceStats}))" )
//            }
            return g2
        })
        return Groups(isFetching: false, groups: g)
    }
    
    class func findExactMatches(assets: [PHAsset], progress: @escaping (Groups) -> ()) -> Groups {
        //let date = Date()
        
        // Look for exact creationDate matches.  It's one of the fastest criteria we can match on.
        let duplicateGroups = FindDuplicatesUsingMetadata.filterToDupes(assets: assets, matchMode: .exactMatchNotUsingResources)

        //NSLog("duplicates 1 \(date.timeIntervalSinceNow)")

        //let filteredAssets = duplicateGroups.groups.flatMap({$0.allAssets})

        // Look for exact size matches.  This is a little slow to get, but it's OK because we've filtered
        // down to a smaller set than "everything".
        //let duplicateGroups2a = FindDuplicatesUsingMetadata.filterToDupes(assets: filteredAssets, matchMode: .exactMatchUsingResources)

        let duplicateGroups2b = refine(groups: duplicateGroups) { (assets) -> Duplicates.Groups in
            return FindDuplicatesUsingMetadata.filterToDupes(assets: assets, matchMode: .exactMatchUsingResources)
        }
        
        //NSLog("duplicates 2 \(date.timeIntervalSinceNow)")

        //let duplicateGroups3a = FindDuplicatesUsingThumbnail.filterToDupes(assets: filteredAssets)
//        let duplicateGroups3b = refine(groups: duplicateGroups2b) { (assets) -> Duplicates.Groups in
//            return FindDuplicatesUsingThumbnail.filterToDupes(assets: assets, strictness: .similar)
//        }


        //NSLog("duplicates 3 \(date.timeIntervalSinceNow)")

        progress(duplicateGroups2b)
        return duplicateGroups2b
    }
}
