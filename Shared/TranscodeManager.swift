//
//  TranscodeManager.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/25/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation
import Photos
import Reachability

extension PHAsset {
    var workIsDone: Bool {
        if transcodeStatsCached != nil {
            return true
        }
        if let videoCodecCached2 = videoCodecCached {
            if !videoCodecCached2.shouldAttemptToTranscode {
                return true
            }
        }
        return false
    }
}

class TranscodeManager {
    struct BeingWorkedOn {
        var asset: PHAsset
        var operationProgress: TranscodeOperation.Progress
        //var transcodeOperation: TranscodeOperation
    }
        
    enum ScanningStatus {
        case starting
        case scanning(Int, Int)
        case paused(TranscodingAllowed.Status)
        case done(Int)
        
        var friendlyStatus: String {
            switch self {
            case .starting:
                return "Starting"
            case .scanning(let completed, let total):
                return "\(completed.formattedDecimalString) of \(total.formattedDecimalString)"
            case .paused(let pausedReason):
                return pausedReason.friendlyString
            case .done:
                return "All Done"
            }
        }
    }

    struct State {
        var isDone: Bool
        var processedCount: Int
        var totalCount: Int
        var transcoded: Set<PHAsset>
        
        var beingWorkedOn: [BeingWorkedOn]
        var scanningStatus: ScanningStatus
    }
//    static let manager = TranscodeManager()
    
    let queue = DispatchQueue(label: "TranscodeManager")
    //var assetsToCheckWithoutNetwork = ArraySlice<PHAsset>()
    var assetsToCheckReversePriority = Array<PHAsset>()
    //let operationQueueNetworkNotAllowed = OperationQueue()
    let operationQueue = OperationQueue()
    var state = State(isDone: false, processedCount: 0, totalCount: 0, transcoded: [], beingWorkedOn: [], scanningStatus: .starting)
    let progress: (State) -> ()
    var throttledEmitProgress: () -> Void
//    var backgroundTaskID: UIBackgroundTaskIdentifier
    let cancellationTokenSource = CancellationTokenSource()
    var lastTranscodeAllowedStatus: TranscodingAllowed.Status?

    init(assets: [PHAsset], progress: @escaping (State) -> ()) {
        
        operationQueue.name = "TranscodeManager"
        operationQueue.maxConcurrentOperationCount = 3

        //self.assets = assets
        self.progress = progress
//        self.backgroundTaskID = .invalid

        throttledEmitProgress = {}
        throttledEmitProgress = throttle(maxFrequency: 0.5) { [weak self] in
            self?.emitProgress()
        }

        
        // There are 3 classes of assets:
        //  - Those that already have transcodeStats (very fast to discover)
        //  - Those that don't need network to transcode
        //  - Those that need network to transcode.
        let assetsWithTranscodeStats = assets.filter({ $0.transcodeStatsCached != nil })
        let assetsNeedsWork = assets.filter({ !$0.workIsDone })
        
        state.transcoded = Set(assetsWithTranscodeStats)
        state.totalCount = assets.count
        state.processedCount = assets.count - assetsNeedsWork.count
        self.assetsToCheckReversePriority = assetsNeedsWork.reversed()

        NotificationCenter.default.addObserver(self, selector: #selector(updateQueueSuspension), name: .transcodingAllowedChanged, object: nil)
        updateQueueSuspension()

        fillWithWork()
        
        // PhotoKit seems to not benefit at all from parallelization and takes ~0.5ms per call no matter how many threads.
        // Boost the processing of any assets for which we have the full version already downloaded but we haven't yet transcoded.
        // It's important to process these before future downloads bump them out of the Photos cache.
        for asset in assetsNeedsWork {
            if cancellationTokenSource.isCancelling {
                break
            }
            if asset.slow_isOriginalQualityAvailableWithoutNetwork {
                boostPriority(asset: asset)
            }
        }
    }

    @objc func updateQueueSuspension() {
        let status = TranscodingAllowed.instance.status
        
        queue.async {
            // Only allow progress in the operationQueueNetworkAllowed queue
            // If TranscodingAllowed says we're allowed to proceed
            
            //let beingWorkedOnAssets = self.state.beingWorkedOn.map { $0.asset }
            
            self.lastTranscodeAllowedStatus = status
            let isSuspended = self.lastTranscodeAllowedStatus != .allowed
            self.operationQueue.isSuspended = isSuspended
            if isSuspended {
                self.operationQueue.cancelAllOperations()
            }
        }
        throttledEmitProgress()
    }
    
    func boostPriority(asset: PHAsset) {
        queue.async {
            NSLog("boostPriority \(asset.slow_resourceStats.originalFileName)")
            let index = self.assetsToCheckReversePriority.lastIndex(of: asset)
            if let index2 = index {
                self.assetsToCheckReversePriority.remove(at: index2)
                self.assetsToCheckReversePriority.append(asset)
            }
        }
    }
    
    func fillWithWork() {
        queue.async {
            let numToFill = self.operationQueue.maxConcurrentOperationCount - self.operationQueue.operations.count
            for _ in 0..<numToFill {
                let maybeAsset = self.assetsToCheckReversePriority.popLast()
                if let asset = maybeAsset {
                    let operation = TranscodeOperation(asset: asset, isNetworkAccessAllowed: true)
                    operation.progressBlock = { [weak self, weak operation] (operationProgress) in
                        if let strongOperation = operation {
                            self?.onOperationProgress(operation: strongOperation, operationProgress: operationProgress)
                        }
                    }
                    operation.completionBlock = { [weak self, weak operation] in
                        if let strongOperation = operation {
                            self?.onOperationEnded(operation: strongOperation)
                        }
                    }
                    self.operationQueue.addOperation(operation)
                }
            }
        }
        throttledEmitProgress()
    }
    
//    deinit {
//        cancelAll()
//    }
    
//    func start() {
    
        
//        self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "TranscodeManager", expirationHandler: {
//            // End the task if time expires.
//            self.endBackgroundTask()
//        })

//        fillWithWork()
//    }

//    private func endBackgroundTask() {
//        queue.async {
//            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
//            self.backgroundTaskID = .invalid
//        }
//    }

    private func emitProgress() {
        queue.async {
            let scanningStatus: ScanningStatus
            let countUnfinished = self.assetsToCheckReversePriority.count + self.operationQueue.operations.count
            self.state.processedCount = self.state.totalCount - countUnfinished
            if self.state.transcoded.count >= self.state.totalCount {
                scanningStatus = .done(self.state.totalCount)
            } else if self.operationQueue.isSuspended {
                scanningStatus = .paused(self.lastTranscodeAllowedStatus!)
            } else {
                scanningStatus = .scanning(self.state.processedCount, self.state.totalCount)
            }
            self.state.scanningStatus = scanningStatus

            let stateCopy = self.state
            DispatchQueue.global().async {
                self.progress(stateCopy)
            }
        }
    }

    private func onOperationProgress(operation: TranscodeOperation, operationProgress: TranscodeOperation.Progress) {
        queue.async {
            //NSLog("TranscodeManager onOperationProgress")
            if let index = self.state.beingWorkedOn.firstIndex(where: { $0.asset == operation.asset }) {
                var beingWorkedOn = self.state.beingWorkedOn[index]
                beingWorkedOn.operationProgress = operationProgress
                self.state.beingWorkedOn[index] = beingWorkedOn
            } else {
                let beingWorkedOn = BeingWorkedOn(asset: operation.asset, operationProgress: .checkingVideoCodec)
                self.state.beingWorkedOn.append(beingWorkedOn)
            }
        }
        throttledEmitProgress()
    }

    private func onOperationEnded(operation: TranscodeOperation) {
        queue.async {
            NSLog("TranscodeManager onOperationEnded originalFileName \(operation.asset.slow_resourceStats.originalFileName) operation.transcodeResult \(operation.transcodeResult)")
            self.state.beingWorkedOn.removeAll(where: { $0.asset == operation.asset })
            if let transcodeResult = operation.transcodeResult {
                switch transcodeResult {
                case .success:
                    self.state.transcoded.insert(operation.asset)
                case .cancelled:
                    // re-enqueue
                    self.assetsToCheckReversePriority.append(operation.asset)
                default:
                    break
                }
            }
        }
        if !cancellationTokenSource.isCancelling {
            fillWithWork()
        }
        throttledEmitProgress()
    }
    
    func cancelAll() {
//        queue.async {
//            for beingWorkedOn in state.beingWorkedOn {
//                beingWorkedOn.cancellationTokenSource.cancel()
//            }
//        }
        cancellationTokenSource.cancel()
        operationQueue.cancelAllOperations()
        emitProgress()
    }
}
