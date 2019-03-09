//
//  PHAssetVideoCodec.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/25/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation
import AVFoundation

extension AVAsset {
    // corresponds for FourCC code
    enum VideoCodec: String, Codable {
        case avc1
        case hvc1
        case unknown
        
        var shouldAttemptToTranscode: Bool {
            return self == .avc1
        }
        
        var friendlyName: String {
            switch self {
            case .avc1:
                return "h264"
            case .hvc1:
                return "hevc"
            case .unknown:
                return "unknown"
            }
        }
    }
    
    enum VideoCodecResult {
        case error
        case cancelled
        case success(VideoCodec)
    }
    
    
    //        func encode(to encoder: Encoder) throws {
    //            var container = encoder.container(keyedBy: CodingKeys.self)
    //            try container.encode(naturalSizeTransformed, forKey: .naturalSizeTransformed)
    //            try container.encode(durationSeconds, forKey: .durationSeconds)
    //            try container.encode(estimatedDataRate, forKey: .estimatedDataRate)
    //            try container.encode(videoCodec, forKey: .videoCodec)
    //        }
    //        init(from decoder: Decoder) throws {
    //            let container = try decoder.container(keyedBy: CodingKeys.self)
    //            naturalSizeTransformed = try container.decode(CGSize.self, forKey: .naturalSizeTransformed)
    //            durationSeconds = try container.decode(Float.self, forKey: .durationSeconds)
    //            estimatedDataRate = try container.decode(Float.self, forKey: .estimatedDataRate)
    //            videoCodec = try container.decode(VideoCodec.self, forKey: .videoCodec)
    //        }
    
    
    func videoCodec(completion: @escaping (VideoCodecResult) -> ()) {
        // Accessing "tracks" will block.  On iOS, it seems like the download is getting killed
        // if we block on it.  It's documented that iOS should use AVAsynchronousKeyValueLoading
        // to monitor and avoid blocking.
        // https://developer.apple.com/documentation/avfoundation/avasynchronouskeyvalueloading
        let tracksKey = "tracks"
        self.loadValuesAsynchronously(forKeys: [tracksKey]) {
            var error: NSError? = nil
            let status = self.statusOfValue(forKey: tracksKey, error: &error)
            switch status {
            case .loaded:
                // Sucessfully loaded, continue processing
                completion(.success(self.videoCodec))
                return
            case .failed, .cancelled:
                completion(.cancelled)
                return
            default:
                NSLog("unexpected status \(status.rawValue)")
                completion(.cancelled)
                return
            }
        }
    }
    
    private var videoCodecString: String? {
        let formatDescriptions = self.tracks.flatMap { $0.formatDescriptions }
        let mediaSubtypes = formatDescriptions
            .filter { CMFormatDescriptionGetMediaType($0 as! CMFormatDescription) == kCMMediaType_Video }
            .map { CMFormatDescriptionGetMediaSubType($0 as! CMFormatDescription).toString() }
        return mediaSubtypes.first
    }
    
    private var videoCodec: VideoCodec {
        switch self.videoCodecString {
        case "avc1":
            return .avc1
        case "hvc1":
            return .hvc1
        default:
            NSLog("unknown videoCodec \(String(describing: self.videoCodecString))")
            return .unknown
        }
    }
}
