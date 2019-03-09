//
//  AVAssetTranscode.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/25/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import AVFoundation

extension AVAsset {
    enum TranscodeResult {
        case error
        case cancelled
        case success(TranscodeSuccessStats)
    }
    struct TranscodeSuccessStats: Codable, Hashable {
        let originalFileSize: UInt64
        let downloadSeconds: Float
        let encodeSeconds: Float
        let actualTranscodedFileSize: UInt64
        
        enum CodingKeys: CodingKey {
            case originalFileSize
            case downloadSeconds
            case encodeSeconds
            case actualTranscodedFileSize
        }
        
        var rawSavingsBytes: Int64 {
            return Int64(originalFileSize) - Int64(actualTranscodedFileSize)
        }
        
        var shouldApplyTranscode: Bool {
            let improvementTheshold = Float(0.05) // If the savings aren't greater than this threshold, don't apply the transcode.
            return rawSavingsPercentage > improvementTheshold
        }
        
        var rawSavingsPercentage: Float {
            return Float(rawSavingsBytes) / Float(originalFileSize)
        }
        
        var applyableSavingsBytes: Int64? {
            return shouldApplyTranscode ? rawSavingsBytes : nil
        }
        var applyableSavingsPercentage: Float? {
            return shouldApplyTranscode ? rawSavingsPercentage : nil
        }
    }

    func transcode(cancellationToken: CancellationToken, downloadSeconds: Float, progressCallback: @escaping (Float) -> (), tempFile: URL, outFile: URL, completion: @escaping (TranscodeResult) -> () ) {
        guard let urlAsset = self as? AVURLAsset else {
            NSLog("not a URL asset")
            completion(.error)
            return
        }
        let originalFileSize = urlAsset.url.fileSize
        
        // Try to create the directory or else writing the file below will fail.
        try? FileManager.default.createDirectory(at: tempFile.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.createDirectory(at: outFile.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        
        

        try? FileManager.default.removeItem(at: tempFile)

        let date = Date()
        try? FileManager.default.removeItem(at: tempFile)
        exportTo(cancellationToken: cancellationToken, progressCallback: progressCallback, file: tempFile, completion: { result in
            switch result {
            case .success:
                try? FileManager.default.removeItem(at: outFile)
                do {
                    try FileManager.default.moveItem(at: tempFile, to: outFile)
                } catch(let error) {
                    NSLog("move error \(error)")
                    completion(.error)
                    return
                }
                let encodeSeconds = -1 * Float(date.timeIntervalSinceNow)
                let transcodedFileSize = outFile.fileSize
                let transcodeStats = TranscodeSuccessStats(originalFileSize: originalFileSize, downloadSeconds: downloadSeconds, encodeSeconds: encodeSeconds, actualTranscodedFileSize: transcodedFileSize)
                print("rawSavingsPercentage \(transcodeStats.rawSavingsPercentage) originalFileSize \(transcodeStats.originalFileSize) transcodedFileSize \(transcodedFileSize)")
                if transcodedFileSize == 0 {
                    NSLog("somehow, transcoded file size is 0")
                    completion(.error)
                    return
                }
                if transcodeStats.rawSavingsPercentage > 0.99 {
                    NSLog("transcodeStats.rawSavingsPercentage > 0.99")
                }
                completion(.success(transcodeStats))
                return
            case .error:
                completion(.error)
                return
            case .cancelled:
                completion(.cancelled)
                return
            }
        })
    }
    
    enum ExportResult {
        case error
        case cancelled
        case success
    }
    func exportTo(cancellationToken: CancellationToken, progressCallback: @escaping (Float) -> (), file: URL, completion: @escaping (ExportResult) -> Void) {
        let preset = VideoEncodeUtil.HEVCPresetName
        
        if !AVAssetExportSession.exportPresets(compatibleWith: self).contains(preset) {
            NSLog("incompatiblePreset")
            completion(.error)
            return
        }
        guard let export = AVAssetExportSession(asset: self, presetName: preset) else {
            NSLog("no exportSession")
            completion(.error)
            return
        }
        
        export.outputFileType = AVFileType.mov
        export.outputURL = file
        
        // Don't turn on multiple passes.  Testing shows that multiplePasses is making no difference at all
        // in output file size on an iPhone with the HEVCHigh encoder preset.
        //export.canPerformMultiplePassesOverSourceMediaData = true
        
        // Metadata automatically transfers from the source asset without this.  In fact, this is somehow causing
        // the more detailed metadata fields to not flow through to the new file.  So, let the better default behavior happen.
        //export.metadata = self.metadata
        

        // Stupidly tricky:
        // 1) This thread might be a synchronous NSOperation thread that's calling this async
        //    method but blocking on the result.  In that case, the thread's runloop is stalled, and any timer scheduled on this thread's runloop
        //    will never get a chance to execute.  So, schedule this timer on Main's runloop, which should never be stalled.
        // 2) NSTimer.invalidate must be called from the same thread that created the timer.  We have no way to dispatch back
        //    to the original thread, so we'll instead create the timer on Main so that we can call invalidate from Main.
        //    https://stackoverflow.com/questions/37687967/nstimer-not-invalidating-even-after-trying-main-thread-solution
        // 3) Running an NSTimer from any thread other than Main is kind of a mess: http://danielemargutti.com/2018/02/22/the-secret-world-of-nstimer/
        var timer: Timer?
        DispatchQueue.main.async { [weak export] in
            let newTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { (timer) in
                if let strongExport = export {
                    NSLog("transcoding \(strongExport.progress)")
                    progressCallback(strongExport.progress)
                }
            })
            newTimer.tolerance = 0.5
            timer = newTimer
        }

        export.exportAsynchronously {
            DispatchQueue.main.async {
                timer!.invalidate()
            }
            
            if let error = export.error {
                NSLog("export error \(error)")
                let nsError = error as NSError
                
                // AVErrorSessionWasInterrupted is a retryable error that seems to happen immediately after the app becomes active
                // after being backgrounded for a while.
                if nsError.domain == AVFoundationErrorDomain && nsError.code == AVError.sessionWasInterrupted.rawValue {
                    completion(.cancelled)
                    return
                }
                completion(.error)
                return
            } else {
                switch export.status {
                case .completed:
                    completion(.success)
                    return
                case .cancelled:
                    completion(.cancelled)
                    return
                default:
                    NSLog("unexpected export.status \(export.status)")
                    completion(.error)
                    return
                }
            }
        }
        cancellationToken.register {
            export.cancelExport()
        }
    }
}
