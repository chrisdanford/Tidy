//
//  PHAssetResource.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/8/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Photos

extension PHAsset {
    // Don't hold a reference to the PHAsset.
    //static var resourceStatsCache = [String: ResourceStats]()
    //static let queue = DispatchQueue(label: "resourceStatsCache")

    struct ResourceStats: Codable {
        let totalResourcesSizeBytes: UInt64
        let originalFileName: String?
        //let uti: String?

        enum CodingKeys: CodingKey {
            case totalResourcesSizeBytes
            case originalFileName
        }
    }
    
    var slow_resourceStats: ResourceStats {
        var stats: ResourceStats? = nil
        let key = localIdentifier
        stats = Caches.resourceStatsCache.get(key: key)
        
        if let stats2 = stats {
            return stats2
        }

        let newStats = computeResourceStats
        Caches.resourceStatsCache.put(key: key, value: newStats)
        stats = newStats
        return newStats
    }
    
    private var computeResourceStats: ResourceStats {
        // This fairly slow.  On the order of 1ms.
        let resources = PHAssetResource.assetResources(for: self)

        let sumResourceBytes = resources.reduce(UInt64(0)) { (result, assetResource) -> UInt64 in
            let resourceSize = assetResource.value(forKey: "fileSize") as? UInt64
            return result + (resourceSize ?? 0)
        }

        var fileName: String? = nil
        if let resourceType = PHAsset.resourceType(mediaType: self.mediaType) {
            let resources = resources.filter { $0.type == resourceType }
            fileName = resources.first?.originalFilename
        }
        
        //let uti = resources.first?.value(forKey: "uti") as? String
        
        return ResourceStats(totalResourcesSizeBytes: sumResourceBytes, originalFileName: fileName /*, uti: uti*/)
    }

    static func dateFromString(stringDate: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let ios11ReleaseDate = dateFormatter.date(from: stringDate)!
        return ios11ReleaseDate
    }
    static let ios11ReleaseDate = dateFromString(stringDate: "2017-09-19")
    static let ios12ReleaseDate = dateFromString(stringDate: "2018-09-17")

    func predictAVC1CodecProbability() -> Float {
        if self.mediaType == .video {
            if let creationDate = creationDate {
                // Everything before iOS11 was AVC1
                if creationDate < PHAsset.ios11ReleaseDate {
                    return 1.0
                } else if creationDate < PHAsset.ios12ReleaseDate {
                    return 0.4
                } else {
                    return 0.2
                }
            } else {
                return 0.0
            }
        }
        return 0.0
    }
    
    static func resourceType(mediaType: PHAssetMediaType) -> PHAssetResourceType? {
        switch mediaType {
        case .video:
            return .video
        case .image:
            return .photo
        case .audio:
            return .audio
        case .unknown:
            return nil
        }
    }
}
