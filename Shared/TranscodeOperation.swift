//
//  TranscodeOperation.swift
//  Tidy iOS
//
//  Created by Chris Danford on 1/24/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Photos

class TranscodeOperation : Operation {
    let asset: PHAsset
    let isNetworkAccessAllowed: Bool
    var progressBlock: (Progress) -> () = {progress in }
    let cancellationTokenSource = CancellationTokenSource()
    var videoCodecResult : AVAsset.VideoCodecResult?
    var transcodeResult : AVAsset.TranscodeResult?

    enum Progress: Hashable {
        case checkingVideoCodec
        case waitingToDownload
        case downloading(Double)
        case transcoding(Double)
    }
    
    init(asset: PHAsset, isNetworkAccessAllowed: Bool) {
        self.asset = asset
        self.isNetworkAccessAllowed = isNetworkAccessAllowed
    }

    override func cancel() {
        super.cancel()
        cancellationTokenSource.cancel()
    }

    static func go(cancellationToken: CancellationToken, asset: PHAsset, isNetworkAccessAllowed: Bool, progressBlock: @escaping (Progress) -> ()) -> (AVAsset.VideoCodecResult?, AVAsset.TranscodeResult?) {
        print("starting operation asset \(asset)")
        
        if cancellationToken.isCancelling {
            return (nil, nil)
        }
        
        progressBlock(.checkingVideoCodec)
        if cancellationToken.isCancelling {
            return (nil, nil)
        }
        NSLog("checkingVideoCodec")
        
        let videoCodecResult = asset.slow_videoCodecSync(cancellationToken: cancellationToken, isNetworkAccessAllowed: isNetworkAccessAllowed)
        if cancellationToken.isCancelling {
            return (videoCodecResult, nil)
        }
        var transcodeResult: AVAsset.TranscodeResult?
        print("videoCodecResult \(videoCodecResult)")
        switch videoCodecResult {
        case .success(let videoCodec):
            if videoCodec.shouldAttemptToTranscode {
                let semaphore = DispatchSemaphore(value: 0)
                asset.transcode(cancellationToken: cancellationToken, isNetworkAccessAllowed: isNetworkAccessAllowed, callback: { progressOrResult in
                    switch progressOrResult {
                    case .progress(let transcodeProgress):
                        switch transcodeProgress {
                        case .downloading(let percent):
                            progressBlock(.downloading(percent))
                        case .transcoding(let percent):
                            progressBlock(.transcoding(percent))
                        case .waitingToDownload:
                            progressBlock(.waitingToDownload)
                        }
                    case .result(let transcodeResult2):
                        print("result \(transcodeResult2)")
                        transcodeResult = transcodeResult2
                        semaphore.signal()                        
                    }
                })
                semaphore.wait()
            }
        default:
            break
        }
        
        print("ending operation asset \(asset)")
        return (videoCodecResult, transcodeResult)
    }
    
    override func main() {
        (videoCodecResult, transcodeResult) = TranscodeOperation.go(cancellationToken: self.cancellationTokenSource.token, asset: asset, isNetworkAccessAllowed: isNetworkAccessAllowed, progressBlock: progressBlock)
    }
}
