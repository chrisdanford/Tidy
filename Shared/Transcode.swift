//
//  PhotosUtil.swift
//  Tidy
//
//  Created by Chris Danford on 1/17/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Photos
import DeepDiff

class Transcode {
    static let estimatedSavingsFromTranscodingAVC1toHEVC: Float = 0.4

    struct BeingWorkedOn {
        var asset: PHAsset
        var operationProgress: TranscodeOperation.Progress
    }

    struct State {
        var transcodingComplete: [PHAsset] = []
        var beingTranscoded: [TranscodeManager.BeingWorkedOn] = []
        var transcodeManagerScanningStatus = TranscodeManager.ScanningStatus.starting
        
        var transcodingToApply: [PHAsset] {
            return transcodingComplete.filter { $0.transcodeStatsCached!.shouldApplyTranscode }
        }

        var briefStatus = BriefStatus.empty()
        
        var badgeCount: Int {
            return transcodingToApply.count
        }

        static func empty() -> State {
            return State()
        }
    }
    
    struct ApplyTranscodeStatus: Codable {
        let applied: Bool
        let savingsBytes: UInt64

        enum CodingKeys: CodingKey {
            case applied
            case savingsBytes
        }
    }
}

extension Transcode {
    class func fetch(cancellationToken: CancellationToken, progress: @escaping (State) -> Void) {
        let queue = DispatchQueue(label: "fetchWorkNew")
        var state = State.empty()
        
        let emitProgressThrottled = throttle(maxFrequency: 0.5) {
            queue.async {
                progress(state)
            }
        }

        func filterOutHighFrameRate(assets: [PHAsset]) -> [PHAsset] {
            // There's one slow-motion video in my library causing the following crash when reading from the AVAsset.
            // I haven't been able to figure out a work-around.  For now, skip over all slow-motion videos.
            //
            //Thread 84 Queue : com.apple.root.default-qos (concurrent)
            //#0    0x00000001e6049fac in -[AVMutableComposition insertTimeRange:ofAsset:atTime:error:] ()
            //#1    0x00000001ed88c344 in +[PFSlowMotionUtilities _scaledCompositionForAsset:slowMotionRate:slowMotionTimeRange:forExport:outTimeRangeMapper:] ()
            //#2    0x00000001ed88c074 in +[PFSlowMotionUtilities assetFromVideoAsset:slowMotionRate:slowMotionTimeRange:forExport:outAudioMix:outTimeRangeMapper:] ()
            //#3    0x00000001ed88ef4c in -[PFVideoAVObjectBuilder requestPlayerItemWithResultHandler:] ()
            //#4    0x00000001eef8ea34 in __66-[PHImageManager requestPlayerItemForVideo:options:resultHandler:]_block_invoke ()
            //#5    0x00000001eef89838 in __100-[PHImageManager _requestAsynchronousVideoURLForAsset:chainedToMasterRequest:options:resultHandler:]_block_invoke.1415 ()
            //#6    0x00000001eef83a44 in __48-[PHCoreImageManager _processImageRequest:sync:]_block_invoke.1117 ()
            //#7    0x00000001eef81794 in __134-[PHCoreImageManager _fetchAdjustmentDataThruAssetsdAndCPLHandlerWithRequest:networkAccessAllowed:trackCPLDownload:completionHandler:]_block_invoke ()
            //#8    0x00000001edc39408 in __111-[PLGatekeeperClient requestAdjustmentDataForAsset:withDataBlob:networkAccessAllowed:trackCPLDownload:handler:]_block_invoke ()
            //#9    0x00000001dfb41324 in _xpc_connection_reply_callout ()
            //#10    0x00000001dfb34430 in _xpc_connection_call_reply_async ()
            //#11    0x0000000102024248 in _dispatch_client_callout3 ()
            //#12    0x000000010203f07c in _dispatch_mach_msg_async_reply_invoke ()
            //#13    0x00000001020361f8 in _dispatch_kevent_worker_thread ()
            //#14    0x00000001dfaf9b30 in _pthread_wqthread ()
            //#15    0x00000001dfaffdd4 in start_wqthread ()
            
            return assets.filter({ $0.mediaSubtypes != PHAssetMediaSubtype.videoHighFrameRate })
        }
        
        func roughEstimate() {
            let rawSamples = FetchAssets.manager.fetchSamples(with: .video)
            let totalAssetsCount = FetchAssets.manager.fetch(with: .video).count

            let samples = filterOutHighFrameRate(assets: rawSamples)
            
            var sumBytes: UInt64 = 0
            var i = 0
            for asset in samples {
                i += 1
                let sizeBytes = asset.slow_resourceStats.totalResourcesSizeBytes

                sumBytes += UInt64(Float(sizeBytes) * asset.predictAVC1CodecProbability() * estimatedSavingsFromTranscodingAVC1toHEVC)
                let bytes = UInt64(SizeUtil.estimateSum(partialSum: Float(sumBytes), numSamplesProcessed: i, totalSamples: samples.count, totalElements: totalAssetsCount))
                queue.sync {
                    state.briefStatus.readyBytes = bytes
                }
                emitProgressThrottled()
            }
            print("sumBytes \(sumBytes) indexStatus.briefStatus.readyBytes \(state.briefStatus.readyBytes)")
            queue.async {
                state.briefStatus.isScanning = false
            }
            emitProgressThrottled()
        }
        DispatchQueue.global().async {
            roughEstimate()
        }

//            func detailedEstimate() {
//                let rawAssets = FetchAssets.manager.fetch(with: .video)
//
//                let assets = filterOutHighFrameRate(assets: rawAssets)
//
//                // Binary search to find the first video that's AVC1.  The theory is that
//                // the user's videos will all be AVC1 until a moment where they began using HEVC.
//                let firstUntranscodableIndex = assets.binarySearch(predicate: { (asset) -> Bool in
//                    if cancellationToken.isCancelling {
//                        return false
//                    }
//                    return asset.slow_isTranscodableOrErrorFetchingSync(isNetworkAccessAllowed: true)
//                })
//                var state = State.empty()
//                let transcodableAssets = assets.prefix(upTo: firstUntranscodableIndex)
//
//                // for the purpose of estimating size, we want to shuffle and try to have a uniform distribution of sizes
//                var sumBytes: UInt64 = 0
//                var i = 0
//
//                let shuffledTranscodableAssets = transcodableAssets.shuffled()
//                for asset in shuffledTranscodableAssets {
//                    i += 1
//                    let sizeBytes = asset.slow_resourceStats.totalResourcesSizeBytes
//                    let estimatedSavingsBytes = UInt64(Float(sizeBytes) * estimatedSavingsFromTranscodingAVC1toHEVC)
//                    sumBytes += estimatedSavingsBytes
//
//                    state.briefStatus.readyBytes = UInt64(SizeUtil.estimateSum(partialSum: Float(sumBytes), numSamplesProcessed: i, totalSamples: shuffledTranscodableAssets.count, totalElements: shuffledTranscodableAssets.count))
//                    emitProgressThrottled(state)
//                }
//                emitProgressThrottled(state)
//            }
//            detailedEstimate()
            
        func transcode() {
            let assets = filterOutHighFrameRate(assets: FetchAssets.manager.fetch(with: .video))
            
            let semaphore = DispatchSemaphore(value: 0)
            let trancodeManager = TranscodeManager(assets: assets, progress: { transcodeState in
                queue.async {
                    state.transcodingComplete = transcodeState.transcoded.sorted(by: PHAsset.compareCreationDate)
                    state.beingTranscoded = transcodeState.beingWorkedOn
                    state.transcodeManagerScanningStatus = transcodeState.scanningStatus
                    //state.briefStatus.isScanning = !transcodeState.isDone
                    if transcodeState.isDone {
                        semaphore.signal()
                    }
                }
                emitProgressThrottled()
            })
            cancellationToken.register {
                trancodeManager.cancelAll()
                semaphore.signal()
                // This will stop retaining transcodeManager
            }
            semaphore.wait()
            NSLog("all done")
        }
        DispatchQueue.global().async {
            transcode()
        }
    }
}


