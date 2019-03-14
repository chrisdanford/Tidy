//
//  VideoEncodeUtil.swift
//  Tidy iOS
//
//  Created by Chris Danford on 1/25/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import AVFoundation

class VideoEncodeUtil: NSObject {
    static let HEVCPresetName = AVAssetExportPresetHEVCHighestQuality
    static var deviceCanExportHEVC: Bool {
        return AVAssetExportSession.allExportPresets().contains(HEVCPresetName)
    }
}
