//
//  VideoEncodeUtil.swift
//  Tidy iOS
//
//  Created by Chris Danford on 1/25/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import AVFoundation

class VideoEncodeUtil: NSObject {
//    class var hasHEVCHardwareEncoder: Bool {
//        let spec: [CFString: Any]
//        #if os(macOS)
//        spec = [ kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder: true ]
//        #else
//        spec = [:]
//        #endif
//        var outID: CFString?
//        var properties: CFDictionary?
//        let result = VTCopySupportedPropertyDictionaryForEncoder(width: 1920, height: 1080, codecType: kCMVideoCodecType_HEVC, encoderSpecification: spec as CFDictionary, encoderIDOut: &outID, supportedPropertiesOut: &properties)
//        if result == kVTCouldNotFindVideoEncoderErr {
//            return false // no hardware HEVC encoder
//        }
//        return result == noErr
//    }

    static let HEVCPresetName = AVAssetExportPresetHEVCHighestQuality
    static var deviceCanExportHEVC: Bool {
        return AVAssetExportSession.allExportPresets().contains(HEVCPresetName)
    }
}
