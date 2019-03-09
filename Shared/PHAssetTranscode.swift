//
//  PHAssetTranscode.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/25/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation
import Photos

extension PHAsset {
    var transcodeStatsCached: AVAsset.TranscodeSuccessStats? {
        let key = localIdentifier
        return Caches.transcodeStatsCache.get(key: key)
    }
    
    /*
    func slow_transcodeSync(downloadProgress: @escaping (Double) -> ()) -> AVAsset.TranscodeResult {
        let key = localIdentifier
        let value = Caches.transcodeStatsCache.get(key: key)
        
        if let value2 = value {
            return .success(value2)
        }
        
        let transcodeResult = transcodeSync(downloadProgress: downloadProgress)
        switch transcodeResult {
        case .success(let transcodeSuccessStats):
            Caches.transcodeStatsCache.put(key: key, value: transcodeSuccessStats)
        default:
            break
        }
        return transcodeResult
    }
 
    private func transcodeSync(downloadProgress: @escaping (Double) -> ()) -> AVAsset.TranscodeResult {
        let semaphore = DispatchSemaphore(value: 0)
        var result: AVAsset.TranscodeResult?
        NSLog("transcodeSync start \(self.localIdentifier)")
        self.transcodeAsync(downloadProgress: downloadProgress, completion: { (transcodeStatus) in
            NSLog("transcodeSync end \(self.localIdentifier)")
            result = transcodeStatus
            semaphore.signal()
        })
        semaphore.wait()
        return result!
    }
    */
    
    enum Progress {
        case waitingToDownload
        case downloading(Double)
        case transcoding(Double)
    }
    enum ProgressOrResult {
        case progress(Progress)
        case result(AVAsset.TranscodeResult)
    }
    
    func transcode(cancellationToken: CancellationToken, isNetworkAccessAllowed: Bool, callback: @escaping (ProgressOrResult) -> Void) {
        if let value = self.transcodeStatsCached {
            callback(.result(.success(value)))
            return
        }
        return transcodeAsyncNoCache(cancellationToken: cancellationToken, isNetworkAccessAllowed: isNetworkAccessAllowed, callback: { progressOrResult in
            switch progressOrResult {
            case .result(let result):
                switch result {
                case .success(let transcodeSuccessStats):
                    let key = self.localIdentifier
                    Caches.transcodeStatsCache.put(key: key, value: transcodeSuccessStats)
                default:
                    break
                }
            default:
                break
            }
            callback(progressOrResult)
            return
        })
    }
    
    private func transcodeAsyncNoCache(cancellationToken: CancellationToken, isNetworkAccessAllowed: Bool, callback: @escaping (ProgressOrResult) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = isNetworkAccessAllowed
        
        // original quality is required because we need to know the codec of the original
        options.deliveryMode = .highQualityFormat
        
        options.progressHandler = { (progress, error, stop, info) in
            //NSLog("requestAVAsset progress \(progress)")
            callback(.progress(.downloading(progress)))
            return
        }
        
        let date = Date()
        //NSLog("transcode \(self)")
        callback(.progress(.waitingToDownload))
        
        let queue = DispatchQueue(label: "PHAsset transcode")
        var emittedResult = false
        
        let requestID = PHImageManager.default().requestAVAsset(forVideo: self, options: options) { (avAsset, avAudioMix, info) in
            NSLog("got requestAVAsset for \(self.slow_resourceStats.originalFileName) \(self.localIdentifier) in \(date.timeIntervalSinceNow)")
            guard let asset = avAsset else {
                NSLog("no asset with options: \(options), info dict: \(info)")
                callback(.result(.error))
                return
            }
            let downloadSeconds = -1 * Float(date.timeIntervalSinceNow)
            
            func progressCallback(percentage: Float) {
                callback(.progress(.transcoding(Double(percentage))))
            }
            asset.transcode(cancellationToken: cancellationToken,
                            downloadSeconds: downloadSeconds,
                            progressCallback: progressCallback,
                            tempFile: self.transcodedTempFileURL,
                            outFile: self.transcodedCacheFileURL) { result in
                // If we succeeded but the transcoding doesn't result in a gain, then delete the transcoded file
                switch result {
                case .success(let transcodeStats):
                    if !transcodeStats.shouldApplyTranscode {
                        try? FileManager.default.removeItem(at: self.transcodedCacheFileURL)
                    }
                default:
                    break
                }

                queue.sync {
                    if !emittedResult {
                        callback(.result(result))
                        emittedResult = true
                    }
                }
            }
        }
        
        cancellationToken.register {
            print("PHImageManager.default().cancelImageRequest \(self.localIdentifier)")

            // Depending on timing, this cancellation may prevent the requestAVAsset callback from being invoked
            // or it might not.  We need a guarantee that we'll not emit 2 results
            PHImageManager.default().cancelImageRequest(requestID)

            queue.sync {
                if !emittedResult {
                    callback(.result(.cancelled))
                    emittedResult = true
                }
            }
            return
        }
    }
    
    private var transcodeFname: String {
        func sanitize(fileName: String) -> String {
            let charSet = CharacterSet(charactersIn:"/\\?%*|\"<>")
            return fileName.components(separatedBy: charSet).joined(separator: "")
        }
        
        // localIdentifier has slashes, which are not valid file characters.
        return sanitize(fileName: self.localIdentifier).appending(".mov")
    }
    
    var transcodedCacheFileURL: URL {
        return TranscodedCacheFiles.versionedDir.appendingPathComponent(transcodeFname)
    }
    var transcodedTempFileURL: URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent(transcodeFname)
    }
}

enum AssetStatsError: Error {
    case errorGettingDataRate
    case errorGettingTimeRange
}

//extension AVAssetTrack {
//    func estimatedTotalSizeBytes() throws -> UInt64 {
//        // I'm sometimes seeing tracks with estimatedDataRate of 0 and timeRange.duration.seconds of NaN.
//        // Handle that.
//        let a = estimatedDataRate
//        if a == 0 {
//            throw AssetStatsError.errorGettingDataRate
//        }
//        let b = timeRange
//        if b.duration.seconds.isNaN {
//            throw AssetStatsError.errorGettingDataRate
//        }
//        let bits = Double(a) * b.duration.seconds
//        return UInt64(bits/8)
//    }
//}

extension AVAsset {
    
    //    var estimatedDataRate: Float {
    //        return self.tracks.map { $0.estimatedDataRate }
    //            .reduce(0.0) { (sum, newVal) -> Float in
    //                return sum + newVal }
    //    }
    
    //    func estimatedTotalSizeBytes() throws -> UInt64 {
    //        return try tracks.reduce(0, { (result, track) -> UInt64 in
    //            let bytes = try track.estimatedTotalSizeBytes()
    //            return 0 + bytes
    //        })
    //    }
    
    //    var stats: PhotosUtil.AssetStatsResult {
    //let date = Date()
    //let track = self.tracks.first
    //NSLog("got first track in \(date.timeIntervalSinceNow)")
    //        guard let firstVideoTrack = self.tracks(withMediaType: .video).first
    //            else { return .error }
    //NSLog("got video track in \(date.timeIntervalSinceNow)")
    //        let videoCodec = self.videoCodec
    //NSLog("got videoCodec in \(date.timeIntervalSinceNow)")
    //let size = firstVideoTrack.naturalSize.applying(firstVideoTrack.preferredTransform)
    //NSLog("got size in \(date.timeIntervalSinceNow)")
    //let roundedSize = CGSize(width: abs(size.width), height: abs(size.height))
    //let durationSeconds = firstVideoTrack.timeRange.duration.seconds
    //NSLog("got seconds in \(date.timeIntervalSinceNow)")
    //if durationSeconds.isNaN {
    //    NSLog("nan")
    //    return .error
    //}
    
    //        guard let estimatedTotalSizeBytes = try? self.estimatedTotalSizeBytes() else {
    //            return .error
    //        }
    //NSLog("got estimated size in \(date.timeIntervalSinceNow)")
    //        let stats = PhotosUtil.AssetStats(/*naturalSizeTransformed: roundedSize, durationSeconds: Float(durationSeconds), fileSizeBytes: fileSizeBytes, */videoCodec: videoCodec)
    //NSLog("got stats in \(date.timeIntervalSinceNow)")
    //        return .success(stats)
    //    }
}
