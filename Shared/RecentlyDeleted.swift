//
//  RecentlyDeleted.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/13/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation
import Photos

class RecentlyDeleted {
    struct State {
        let assets: [PHAsset]
        let briefStatus: BriefStatus
        
        var badgeCount: Int {
            return assets.count
        }

        static func empty() -> State {
            return State(assets: [], briefStatus: .empty())
        }
    }
    
    class func fetch(progress: @escaping (State) -> ()) {
        DispatchQueue.global().async {
            let assets = recentlyDeletedAssets()
            let bytes = assets.reduce(0) { (result, asset) -> UInt64 in
                return result + asset.slow_resourceStats.totalResourcesSizeBytes
            }
            let briefStatus = BriefStatus(isScanning: false, readySavingsBytes: bytes, estimatedEventualSavingsBytes: nil)
            let state = State(assets: assets, briefStatus: briefStatus)
            progress(state)
        }
    }
    
    class func recentlyDeletedAssets() -> [PHAsset] {
        if let album = recentlyDeletedCollection() {
            let result = PHAsset.fetchAssets(in: album, options: nil)
            var assets = [PHAsset]()
            for i in 0..<result.count {
                let asset = result[i]
                assets.append(asset)
            }
            return assets
        }
        return []
    }

    class func recentlyDeletedCollection() -> PHAssetCollection? {
        
        let result = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
        
        for i in 0..<result.count {
            let album = result[i]
            if album.localizedTitle == "Recently Deleted" {
                return album
            }
        }
        return nil
    }
}
