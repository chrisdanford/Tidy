//
//  LargeFiles.swift
//  Tidy iOS
//
//  Created by Chris Danford on 3/11/19.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import Photos

class LargeFiles {
    struct State {
        var sortedAssets: [PHAsset]
        var briefStatus: BriefStatus

        static func empty() -> State {
            return State(sortedAssets: [], briefStatus: BriefStatus.empty())
        }
    }
    
    class func fetch(progress: @escaping (State) -> Void) {
        var state = State.empty()

        state.briefStatus.isScanning = true
        progress(state)

        state.sortedAssets = FetchAssets.manager.fetchLargestSorted(with: .video)
        state.briefStatus.isScanning = false
        progress(state)
    }
}
