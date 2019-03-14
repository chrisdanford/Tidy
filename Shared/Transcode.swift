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
            let (estimatedLargestAssets, restAssets) = FetchAssets.manager.fetchEstimatedLargestFilesAndRest(with: .video)

            func getSize(asset: PHAsset) -> UInt64 {
                let sizeBytes = asset.slow_resourceStats.totalResourcesSizeBytes
                return UInt64(Float(sizeBytes) * asset.predictAVC1CodecProbability() * estimatedSavingsFromTranscodingAVC1toHEVC)
            }
            SizeUtil.predictSize(largeAssets: estimatedLargestAssets, restAssets: restAssets, getSize: getSize) { (estimate) in
                queue.sync {
                    state.briefStatus.estimatedEventualSavingsBytes = estimate
                }
                emitProgressThrottled()
            }
            queue.async {
                print("state.briefStatus \(state.briefStatus)")
                state.briefStatus.isScanning = false
            }
            emitProgressThrottled()
        }
        DispatchQueue.global().async {
            roughEstimate()
        }
            
        func transcode() {
            let assets = filterOutHighFrameRate(assets: FetchAssets.manager.fetch(with: .video))
            
            let semaphore = DispatchSemaphore(value: 0)
            let trancodeManager = TranscodeManager(assets: assets, progress: { transcodeState in
                queue.async {
                    state.transcodingComplete = transcodeState.transcoded.sorted(by: PHAsset.compareCreationDate)
                    state.beingTranscoded = transcodeState.beingWorkedOn
                    state.transcodeManagerScanningStatus = transcodeState.scanningStatus
                    
                    state.briefStatus.readySavingsBytes = transcodeState.transcoded.reduce(0, { (result, asset) -> UInt64 in
                        return result + UInt64(asset.transcodeStatsCached?.applyableSavingsBytes ?? 0)
                    })

                    state.briefStatus.isScanning = !transcodeState.isDone
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


