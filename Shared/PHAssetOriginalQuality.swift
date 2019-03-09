//
//  PHAssetOriginalQuality.swift
//  Tidy iOS
//
//  Created by Chris Danford on 3/3/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Photos

extension PHAsset {
    
    var slow_isOriginalQualityAvailableWithoutNetwork: Bool {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        var success: Bool?
        let semaphore = DispatchSemaphore(value: 0)
        PHImageManager.default().requestPlayerItem(forVideo: self, options: options, resultHandler: { playerItem, info in
            success = playerItem != nil
            semaphore.signal()
        })
        semaphore.wait()
        return success!
    }
}
