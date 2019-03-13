//
//  SizeUtil.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/18/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation

class SizeUtil {
    
    // Intentionally underestimate by 30% at first, then by 0% at for the last sample.
    // That way, the mid-progress number looks like it's growing and not declining.
    private class func scale(value: Float, low: Float, high: Float, outLow: Float, outHigh: Float) -> Float {
        let percent = (value - low) / (high - low)
        return outLow + (percent * (outHigh - outLow))
    }

    class func estimateSum(partialSum: Float, numSamplesProcessed: Int, totalSamples: Int, totalElements: Int) -> Float {
        let reduceBytesEstimateByPercent = scale(value: Float(numSamplesProcessed), low: 0, high: Float(totalSamples), outLow: 0.3, outHigh: 0)
        let percentSamplesIncluded = Float(numSamplesProcessed) / Float(totalSamples)
        let percentSampled = Float(totalSamples) / Float(totalElements)
        let estimatedSum = (partialSum / percentSamplesIncluded) / percentSampled
        let discountedSum = estimatedSum * (1.0 - reduceBytesEstimateByPercent)
        return discountedSum
    }
    
    class func predictSize<T>(assets: [T], getSize: (T) -> UInt64, progress: (UInt64) -> ()) {
        let samples = FetchAssets.manager.sampleStabilyAndRandomize(assets: assets)
        var sum: UInt64 = 0
        var i = 0
        for asset in samples {
            i += 1
            sum += getSize(asset)
            let estimate = SizeUtil.estimateSum(partialSum: Float(sum), numSamplesProcessed: i, totalSamples: samples.count, totalElements: assets.count)
            progress(UInt64(estimate))
        }
    }
    
    class func predictSize<T>(largeAssets: [T], restAssets: [T], getSize: (T) -> UInt64, progress: (UInt64) -> ()) {
        var largeAssetsSum: UInt64 = 0
        for asset in largeAssets {
            largeAssetsSum += getSize(asset)
            progress(UInt64(largeAssetsSum))
        }
        predictSize(assets: restAssets, getSize: getSize) { (estimate) in
            progress(largeAssetsSum + estimate)
        }
    }
}
