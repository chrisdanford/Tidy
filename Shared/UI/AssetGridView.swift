/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Implements the collection view cell for displaying an asset in the grid view.
 */

import UIKit
import PhotosUI

class AssetGridView: UIView {
    struct AssetModel : Hashable {
        let asset: PHAsset
        let isLivePhoto: Bool
        let isVideo: Bool
        let duration: TimeInterval
        let modificationDate: Date?
        let totalResourcesSizeBytes: UInt64
        let pixelWidth: Int
        let pixelHeight: Int
        let videoCodec: AVAsset.VideoCodec?
        let originalFileName: String
        let transcodeSavingsPercentage: Float?
        let transcodeCanBeApplied: Bool?

        init(asset: PHAsset) {
            self.asset = asset
            self.isLivePhoto = asset.mediaSubtypes.contains(.photoLive)
            self.isVideo = asset.mediaType == .video
            self.duration = asset.duration
            self.modificationDate = asset.modificationDate
            self.totalResourcesSizeBytes = asset.slow_resourceStats.totalResourcesSizeBytes
            self.pixelWidth = asset.pixelWidth
            self.pixelHeight = asset.pixelHeight
            self.videoCodec = asset.videoCodecCached
            self.originalFileName = asset.slow_resourceStats.originalFileName ?? ""
            self.transcodeSavingsPercentage = asset.transcodeStatsCached?.rawSavingsPercentage
            self.transcodeCanBeApplied = asset.transcodeStatsCached?.shouldApplyTranscode
        }
    }
    
    struct Model : Hashable {
        let assetModel: AssetModel
        let showDeleteIcon: Bool
        let showVerboseSizeBytes: Bool
        let showModifiedDate: Bool
        let showSavingsPercentage: Bool
        let operationProgress: TranscodeOperation.Progress?

        static func formattedCompactByteString(assetModel: AssetModel, verbose: Bool = false) -> String {
            let totalBytes = assetModel.totalResourcesSizeBytes
            return verbose ? totalBytes.formattedDecimalString : totalBytes.formattedCompactByteString
        }
    }
    
    @IBOutlet var contentView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var livePhotoBadgeImageView: UIImageView!
    @IBOutlet weak var deleteImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var resolutionLabel: UILabel!
    @IBOutlet weak var codecLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var modifiedLabel: UILabel!
    @IBOutlet weak var savingsLabel: UILabel!
    
    var imageManager: PHCachingImageManager?
    var imageRequestID: PHImageRequestID?
    
    // https://medium.com/@brianclouser/swift-3-creating-a-custom-view-from-a-xib-ecdfe5b3a960
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    private func commonInit() {
        Bundle.main.loadNibNamed("AssetGridView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
        
    func load(imageManager: PHCachingImageManager, model: Model) {
        // Cancel a pending image request, if any.
        unload()

        self.imageManager = imageManager
        
        // Add a badge to the cell if the PHAsset represents a Live Photo.
        if model.assetModel.isLivePhoto {
            livePhotoBadgeImageView.image = PHLivePhotoView.livePhotoBadgeImage(options: .overContent)
        }

        let scale = UIScreen.main.scale
        let thumbnailSize = CGSize(width: 50 * scale, height: 50 * scale)
    
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        let requestAsset = model.assetModel.asset
        imageRequestID = imageManager.requestImage(for: requestAsset, targetSize: thumbnailSize, contentMode: .aspectFill, options: options, resultHandler: { [weak self] image, _ in
            // UIKit may have recycled this cell by the handler's activation time.
            // Set the cell's thumbnail image only if it's still showing the same asset.
            if requestAsset.localIdentifier == model.assetModel.asset.localIdentifier {
                if let image = image {
                    self?.imageView.image = image
                } else {
                    NSLog("image is nil")
                }
            }
        })
    
        let showDuration = model.assetModel.isVideo
        durationLabel.isHidden = !showDuration
        if showDuration {
            let duration: TimeInterval = model.assetModel.duration
            durationLabel.text = duration.conciseFriendlyFormattedString
        } else {
            durationLabel.text = ""
        }

        if model.showModifiedDate, let modifiedDate = model.assetModel.modificationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let formattedDate = formatter.string(from: modifiedDate)
            
            modifiedLabel.text = formattedDate
            modifiedLabel.isHidden = false
        } else {
            modifiedLabel.isHidden = true
        }
      
        sizeLabel.isHidden = false
        sizeLabel.text = Model.formattedCompactByteString(assetModel: model.assetModel, verbose: model.showVerboseSizeBytes)

        resolutionLabel.isHidden = false
        resolutionLabel.text = "\(model.assetModel.pixelWidth)x\(model.assetModel.pixelHeight)"
        
        if let videoCodec = model.assetModel.videoCodec {
            codecLabel.isHidden = false
            codecLabel.text = videoCodec.friendlyName
        } else {
            codecLabel.isHidden = true
            codecLabel.text = ""
        }
        
        deleteImageView.isHidden = true
        nameLabel.isHidden = false
        nameLabel.text = model.assetModel.originalFileName
        
        if model.showDeleteIcon {
            imageView.layer.borderColor = UIColor.red.cgColor
            imageView.layer.borderWidth = 3
        } else {
            imageView.layer.borderWidth = 0
        }

        if model.showSavingsPercentage, let savingsPercentage = model.assetModel.transcodeSavingsPercentage {
            let canBeApplied = model.assetModel.transcodeCanBeApplied ?? false
            savingsLabel.text = "Saves " + String(format: "%.1f%%", savingsPercentage * 100)
            savingsLabel.textColor = (canBeApplied ? UIColor.green : UIColor.red).lighten()
            savingsLabel.isHidden = false
        } else {
            let text: String
            if let operationProgress = model.operationProgress {
                switch operationProgress {
                case .checkingVideoCodec:
                    text = "Getting codec..."
                case .waitingToDownload:
                    text = "Downloading..."
                case .downloading(let percent):
                    text = "Downloading...\n" + String(format: "%.1f%%", percent * 100)
                case .transcoding(let percent):
                    text = "Transcoding...\n" + String(format: "%.1f%%", percent * 100)
                }
                savingsLabel.text = text
                savingsLabel.textColor = UIColor.white
                savingsLabel.isHidden = false
            }
        }
    }
    
    func unload() {
        if imageRequestID != nil && imageManager != nil {
            imageManager!.cancelImageRequest(imageRequestID!)
        }
        imageRequestID = nil
        imageManager = nil

        imageView.image = nil
        imageView.layer.borderWidth = 0
        livePhotoBadgeImageView.image = nil
        durationLabel.text = nil
        sizeLabel.text = nil
        resolutionLabel.text = nil
        modifiedLabel.text = nil
        deleteImageView.isHidden = true
        nameLabel.isHidden = true
        modifiedLabel.isHidden = true
        savingsLabel.isHidden = true
    }
}
