//
//  PHAssetMetadata.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/19/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Photos

extension PHAsset {
    /*
    enum FetchVideoCodecResult: Codable {
        case error
        case failureNeedsPhotoKit
        case failureNeedsNetwork
        case success(AVAsset.AssetStatsResult)
        
        enum CodingKeys: CodingKey {
            case error
            case failureNeedsPhotoKit
            case failureNeedsNetwork
            case success
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .error:
                try container.encode(0, forKey: .error)
            case .failureNeedsPhotoKit:
                try container.encode(0, forKey: .failureNeedsPhotoKit)
            case .failureNeedsNetwork:
                try container.encode(0, forKey: .failureNeedsNetwork)
            case .success(let value):
                try container.encode(value, forKey: .success)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let _ = try? container.decode(Int.self, forKey: .error) {
                self = .error
            } else if let _ = try? container.decode(Int.self, forKey: .failureNeedsPhotoKit) {
                self = .failureNeedsPhotoKit
            } else if let _ = try? container.decode(Int.self, forKey: .failureNeedsNetwork) {
                self = .failureNeedsNetwork
            } else if let value = try? container.decode(AVAsset.AssetStatsResult.self, forKey: .success) {
                self = .success(value)
            } else {
                self = .error
            }
            //                do {
            //                    let _ = try container.decode(Int.self, forKey: .failureNeedsNetwork)
            //                    self = .failureNeedsNetwork
            //                } catch {
            //                    let value = try container.decode(AssetStatsResult.self, forKey: .success)
            //                    self = .success(value)
            //                }
            //            }
        }
    }
 */

    func slow_isTranscodableOrErrorFetchingSync(cancellationToken: CancellationToken, isNetworkAccessAllowed: Bool) -> Bool {
        let result = slow_videoCodecSync(cancellationToken: cancellationToken, isNetworkAccessAllowed: isNetworkAccessAllowed)
        switch result {
        case .success(let videoCodec):
            switch videoCodec {
            case .avc1:
                break
            default:
                return false
            }
        default:
            break
        }
        return true
    }

    var videoCodecCached: AVAsset.VideoCodec? {
        let key = localIdentifier
        return Caches.videoCodecCache.get(key: key)
    }

    func slow_videoCodecSync(cancellationToken: CancellationToken, isNetworkAccessAllowed: Bool) -> AVAsset.VideoCodecResult {
        let key = localIdentifier
        let value = Caches.videoCodecCache.get(key: key)
        
        if let value2 = value {
            return .success(value2)
        }
        
        let videoCodecResult = videoCodecSyncInternal(cancellationToken: cancellationToken, isNetworkAccessAllowed: isNetworkAccessAllowed)
        switch videoCodecResult {
        case .success(let videoCodec):
            Caches.videoCodecCache.put(key: key, value: videoCodec)
        default:
            break
        }
        return videoCodecResult
    }
    
    private func videoCodecSyncInternal(cancellationToken: CancellationToken, isNetworkAccessAllowed: Bool) -> AVAsset.VideoCodecResult {
        var result: AVAsset.VideoCodecResult?
        let semaphore = DispatchSemaphore(value: 0)
        //NSLog("statsSync start \(self.localIdentifier)")
        self.videoCodecAsync(cancellationToken: cancellationToken, isNetworkAccessAllowed: isNetworkAccessAllowed) { (fetchAssetStatsResult) in
            //NSLog("statsSync end \(self.localIdentifier)")
            result = fetchAssetStatsResult
            semaphore.signal()
        }
        semaphore.wait()
        return result!
    }
    
    func videoCodecAsync(cancellationToken: CancellationToken, isNetworkAccessAllowed: Bool, completion: @escaping (AVAsset.VideoCodecResult) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = isNetworkAccessAllowed
        
        options.progressHandler = { (progress, error, stop, info) in
            NSLog("requestPlayerItem progress \(progress)")
        }
        
        // original quality is required because we need to know the codec of the original
        options.deliveryMode = .highQualityFormat
        
        let date = Date()

        if cancellationToken.isCancelling {
            completion(.cancelled)
            return
        }
        
        // Observation:
        // requestAVAsset seems to download the whole asset then call the callback.
        // requestPlayerItem seems to set up the asset for streaming.
        let requestID = PHImageManager.default().requestPlayerItem(forVideo: self, options: options, resultHandler: { playerItem, info in
            NSLog("got requestPlayerItem in \(date.timeIntervalSinceNow)")
            if let info2 = info {
                if let error = info2[PHImageErrorKey] {
                    if let error2 = error as? NSError {
                        NSLog("info error \(error2)")
                        completion(.error)
                        return
                    }
                }
            }
            if let playerItem2 = playerItem {
                let date2 = Date()
                
                playerItem2.asset.videoCodec() { result in
                    switch result {
                    case .success(let videoCodec):
                        NSLog("got videoCodec in \(date2.timeIntervalSinceNow)")
                        completion(.success(videoCodec))
                        return
                    default:
                        NSLog("failure error")
                        completion(.error)
                        // Handle all other cases
                        return
                    }
                }
            } else {
                NSLog("failure needs network")
                completion(.error)
                return
            }
        })
        
        cancellationToken.register {
            PHImageManager.default().cancelImageRequest(requestID)
        }
    }
}

