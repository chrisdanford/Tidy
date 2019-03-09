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
}
