/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implements the view controller that displays a single asset.
*/

import UIKit
import Photos
import PhotosUI

class AssetViewController: UIViewController {
    
    var asset: PHAsset!
    var assetCollection: PHAssetCollection!
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var livePhotoView: PHLivePhotoView!
    @IBOutlet weak var editButton: UIBarButtonItem!
    @IBOutlet weak var progressView: UIProgressView!
    
    #if os(tvOS)
    @IBOutlet var livePhotoPlayButton: UIBarButtonItem!
    #endif
    
    @IBOutlet var playButton: UIBarButtonItem!
    @IBOutlet var space: UIBarButtonItem!
    @IBOutlet var trashButton: UIBarButtonItem!
    @IBOutlet var favoriteButton: UIBarButtonItem!
    
    fileprivate var playerLayer: AVPlayerLayer!
    fileprivate var isPlayingHint = false
    
    fileprivate lazy var formatIdentifier = Bundle.main.bundleIdentifier!
    fileprivate let formatVersion = "1.0"
    fileprivate lazy var ciContext = CIContext()
    
    // MARK: UIViewController / Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        livePhotoView.delegate = self
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override func viewWillLayoutSubviews() {
        let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
        view.backgroundColor = isNavigationBarHidden ? .black : .white
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateToolbarItems()
        
        // Make sure the view layout happens before requesting an image sized to fit the view.
        view.layoutIfNeeded()
        updateImage()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        #if os(iOS)
        navigationController?.hidesBarsOnTap = false
        #endif
    }
    
    // MARK: UI Actions
    /// - Tag: EditAlert
    @IBAction func editAsset(_ sender: UIBarButtonItem) {
        // Use a UIAlertController to display editing options to the user.
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        #if os(iOS)
        alertController.modalPresentationStyle = .popover
        if let popoverController = alertController.popoverPresentationController {
            popoverController.barButtonItem = sender
            popoverController.permittedArrowDirections = .up
        }
        #endif
        
        // Add a Cancel action to dismiss the alert without doing anything.
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""),
                                                style: .cancel, handler: nil))
        // Allow editing only if the PHAsset supports edit operations.
        if asset.canPerform(.content) {
            // Add actions for some canned filters.
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Sepia Tone", comment: ""),
                                                    style: .default, handler: getFilter("CISepiaTone")))
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Chrome", comment: ""),
                                                    style: .default, handler: getFilter("CIPhotoEffectChrome")))
            
            // Add actions to revert any edits that have been made to the PHAsset.
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Revert", comment: ""),
                                                    style: .default, handler: revertAsset))
        }
        // Present the UIAlertController.
        present(alertController, animated: true)
    }
    #if os(tvOS)
    @IBAction func playLivePhoto(_ sender: Any) {
        livePhotoView.startPlayback(with: .full)
    }
    #endif
    /// - Tag: PlayVideo
    @IBAction func play(_ sender: AnyObject) {
        //PhotosUtil.duplicateVideoAssetAndAlbumMembership(asset: self.asset)
        
        if playerLayer != nil {
            // The app already created an AVPlayerLayer, so tell it to play.
            playerLayer.player!.play()
        } else {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .fastFormat
            options.progressHandler = { progress, _, _, _ in
                // The handler may originate on a background queue, so
                // re-dispatch to the main queue for UI work.
                DispatchQueue.main.sync {
                    self.progressView.progress = Float(progress)
                }
            }
            // Request an AVPlayerItem for the displayed PHAsset.
            // Then configure a layer for playing it.
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options, resultHandler: { playerItem, info in
                DispatchQueue.main.sync {
                    guard self.playerLayer == nil else { return }

                    // Create an AVPlayer and AVPlayerLayer with the AVPlayerItem.
                    let player = AVPlayer(playerItem: playerItem)
                    let playerLayer = AVPlayerLayer(player: player)

                    // Configure the AVPlayerLayer and add it to the view.
                    playerLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                    playerLayer.frame = self.view.layer.bounds
                    self.view.layer.addSublayer(playerLayer)

                    player.play()

                    // Cache the player layer by reference, so you can remove it later.
                    self.playerLayer = playerLayer
                }
            })
        }
    }
    /// - Tag: RemoveAsset
    @IBAction func removeAsset(_ sender: AnyObject) {
        let completion = { (success: Bool, error: Error?) -> Void in
            if success {
                // unregister before doing anything else or else we'll the change will fire and we'll try to refresh the asset we just deleted.
                PHPhotoLibrary.shared().unregisterChangeObserver(self)
                
                let savingsStats = Savings.Stats(count: 1, beforeBytes: self.asset.slow_resourceStats.totalResourcesSizeBytes, afterBytes: 0)
                AppManager.instance.deletedAsset(stats: savingsStats)
                AppManager.resetAndFetch()
                DispatchQueue.main.sync {
                    _ = self.navigationController!.popViewController(animated: true)
                }
            } else {
                NSLog("Can't remove the asset: \(String(describing: error))")
            }
        }
        if assetCollection != nil {
            // Remove the asset from the selected album.
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCollectionChangeRequest(for: self.assetCollection)!
                request.removeAssets([self.asset] as NSArray)
            }, completionHandler: completion)
        } else {
            // Delete the asset from the photo library.
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets([self.asset] as NSArray)
            }, completionHandler: completion)
        }
    }
    /// - Tag: MarkFavorite
    @IBAction func toggleFavorite(_ sender: UIBarButtonItem) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: self.asset)
            request.isFavorite = !self.asset.isFavorite
        }, completionHandler: { success, error in
            if success {
                DispatchQueue.main.sync {
                    self.asset = FetchAssets.fetchAsset(asset: self.asset)
                    self.updateToolbarItems()
                }
            } else {
                NSLog("Can't mark the asset as a Favorite: \(String(describing: error))")
            }
        })
    }

    func updateToolbarItems() {
        // Set the appropriate toolbar items based on the media type of the asset.
        #if os(iOS)
        navigationController?.isToolbarHidden = false
        navigationController?.hidesBarsOnTap = true
        if asset.mediaType == .video {
            toolbarItems = [favoriteButton, space, playButton, space, trashButton]
        } else {
            // In iOS, present both stills and Live Photos the same way, because
            // PHLivePhotoView provides the same gesture-based UI as in the Photos app.
            toolbarItems = [favoriteButton, space, trashButton]
        }
        #elseif os(tvOS)
        if asset.mediaType == .video {
            navigationItem.leftBarButtonItems = [playButton, favoriteButton, trashButton]
        } else {
            // In tvOS, PHLivePhotoView doesn't support playback gestures,
            // so add a play button for Live Photos.
            if asset.mediaSubtypes.contains(.photoLive) {
                navigationItem.leftBarButtonItems = [favoriteButton, trashButton]
            } else {
                navigationItem.leftBarButtonItems = [livePhotoPlayButton, favoriteButton, trashButton]
            }
        }
        #endif
        // Enable editing buttons if the user can edit the asset.
        editButton.isEnabled = false //asset.canPerform(.content)
        favoriteButton.isEnabled = asset.canPerform(.properties)
        favoriteButton.title = asset.isFavorite ? "♥︎" : "♡"
        
        // Enable the trash can button if the user can delete the asset.
        if assetCollection != nil {
            trashButton.isEnabled = assetCollection.canPerform(.removeContent)
        } else {
            trashButton.isEnabled = asset.canPerform(.delete)
        }
    }
    
    // MARK: Image display
    
    var targetSize: CGSize {
        let scale = UIScreen.main.scale
        return CGSize(width: imageView.bounds.width * scale, height: imageView.bounds.height * scale)
    }
    
    func updateImage() {
        if asset.mediaSubtypes.contains(.photoLive) {
            updateLivePhoto()
        } else {
            updateStaticImage()
        }
    }
    
    func updateLivePhoto() {
        // Prepare the options to pass when fetching the live photo.
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.progressHandler = { progress, _, _, _ in
            // The handler may originate on a background queue, so
            // re-dispatch to the main queue for UI work.
            DispatchQueue.main.sync {
                self.progressView.progress = Float(progress)
            }
        }
        
        // Request the live photo for the asset from the default PHImageManager.
        PHImageManager.default().requestLivePhoto(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options,
                                                  resultHandler: { livePhoto, info in
                                                    // PhotoKit finishes the request, so hide the progress view.
                                                    self.progressView.isHidden = true
                                                    
                                                    // Show the Live Photo view.
                                                    guard let livePhoto = livePhoto else { return }
                                                    
                                                    // Show the Live Photo.
                                                    self.imageView.isHidden = true
                                                    self.livePhotoView.isHidden = false
                                                    self.livePhotoView.livePhoto = livePhoto
                                                    
                                                    if !self.isPlayingHint {
                                                        // Play back a short section of the Live Photo, similar to the Photos share sheet.
                                                        self.isPlayingHint = true
                                                        self.livePhotoView.startPlayback(with: .hint)
                                                    }
        })
    }
    
    func updateStaticImage() {
        // Prepare the options to pass when fetching the (photo, or video preview) image.
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.progressHandler = { progress, _, _, _ in
            // The handler may originate on a background queue, so
            // re-dispatch to the main queue for UI work.
            DispatchQueue.main.sync {
                self.progressView.progress = Float(progress)
            }
        }
        
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options,
                                              resultHandler: { image, _ in
                                                // PhotoKit finished the request, so hide the progress view.
                                                self.progressView.isHidden = true
                                                
                                                // If the request succeeded, show the image view.
                                                guard let image = image else { return }
                                                
                                                // Show the image.
                                                self.livePhotoView.isHidden = true
                                                self.imageView.isHidden = false
                                                self.imageView.image = image
        })
    }
    
    // MARK: Asset editing
    
    func revertAsset(sender: UIAlertAction) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: self.asset)
            request.revertAssetContentToOriginal()
        }, completionHandler: { success, error in
            if !success { NSLog("Can't revert the asset: \(String(describing: error))") }
        })
    }
    
    // Returns a filter-applier function for the named filter.
    // Use the function as a handler for a UIAlertAction object.
    /// - Tag: ApplyFilter
    func getFilter(_ filterName: String) -> (UIAlertAction) -> Void {
        func applyFilter(_: UIAlertAction) {
            // Set up a handler to handle prior edits.
            let options = PHContentEditingInputRequestOptions()
            /*options.canHandleAdjustmentData = {
                // intentionally request the latest version
                $0.formatIdentifier == self.formatIdentifier && $0.formatVersion == self.formatVersion
            }
            */
            
            // Prepare for editing.
            asset.requestContentEditingInput(with: options, completionHandler: { input, info in
                guard let input = input
                    else { fatalError("Can't get the content-editing input: \(info)") }
                
                // This handler executes on the main thread; dispatch to a background queue for processing.
                DispatchQueue.global(qos: .userInitiated).async {
                    
                    // Create adjustment data describing the edit.
                    let adjustmentData = PHAdjustmentData(formatIdentifier: self.formatIdentifier,
                                                          formatVersion: self.formatVersion,
                                                          data: filterName.data(using: .utf8)!)
                    
                    // Create content editing output, write the adjustment data.
                    let output = PHContentEditingOutput(contentEditingInput: input)
                    output.adjustmentData = adjustmentData
                    
                    // Select a filtering function for the asset's media type.
                    let applyFunc: (String, PHContentEditingInput, PHContentEditingOutput, @escaping () -> Void) -> Void
                    if self.asset.mediaSubtypes.contains(.photoLive) {
                        applyFunc = self.applyLivePhotoFilter
                    } else if self.asset.mediaType == .image {
                        applyFunc = self.applyPhotoFilter
                    } else {
                        applyFunc = self.applyVideoFilter
                    }
                    
                    // Apply the filter.
                    applyFunc(filterName, input, output, {
                        // When the app finishes rendering the filtered result, commit the edit to the photo library.
                        PHPhotoLibrary.shared().performChanges({
                            let request = PHAssetChangeRequest(for: self.asset)
                            request.contentEditingOutput = output
                        }, completionHandler: { success, error in
                            if !success { NSLog("Can't edit the asset: \(String(describing: error))") }
                        })
                    })
                }
            })
        }
        return applyFilter
    }
    
    func applyPhotoFilter(_ filterName: String, input: PHContentEditingInput, output: PHContentEditingOutput, completion: () -> Void) {
        
        // Load the full-size image.
        guard let inputImage = CIImage(contentsOf: input.fullSizeImageURL!)
            else { fatalError("Can't load the input image to edit.") }
        
        // Apply the filter.
        let outputImage = inputImage
            .oriented(forExifOrientation: input.fullSizeImageOrientation)
            .oriented(CGImagePropertyOrientation.down)
            .applyingFilter(filterName, parameters: [:])
        
        // Write the edited image as a JPEG.
        do {
            try self.ciContext.writeJPEGRepresentation(of: outputImage,
                                                       to: output.renderedContentURL, colorSpace: inputImage.colorSpace!, options: [:])
        } catch let error {
            fatalError("Can't apply the filter to the image: \(error).")
        }
        completion()
    }
    
    func applyLivePhotoFilter(_ filterName: String, input: PHContentEditingInput, output: PHContentEditingOutput, completion: @escaping () -> Void) {
        
        // This app filters assets only for output. In an app that previews
        // filters while editing, create a livePhotoContext early and reuse it
        // to render both for previewing and for final output.
        guard let livePhotoContext = PHLivePhotoEditingContext(livePhotoEditingInput: input)
            else { fatalError("Can't fetch the Live Photo to edit.") }
        
        livePhotoContext.frameProcessor = { frame, _ in
            return frame.image.applyingFilter(filterName, parameters: [:])
        }
        livePhotoContext.saveLivePhoto(to: output) { success, error in
            if success {
                completion()
            } else {
                NSLog("Can't output the Live Photo.")
            }
        }
    }
    
    enum Rotation {
        case noRotation
        case counterClockwise90
        case counterClockwise180
        case counterClockwise270
    }
    
    func almostEqual(_ a: CGFloat, _ b: CGFloat) -> Bool {
        
        // There is significant float drift that causes the nextUp/nextDown method of precision
        // to not work.  For example, these values we want to consider equivalent to 0.
        // CGFloat   0.00000000000000006123233995736766
        let epsilon = CGFloat(0.0001)
        return abs(a - b) < epsilon
    }
    
    func almostEqual(_ a : CGAffineTransform, _ b : CGAffineTransform) -> Bool {
        return (
            almostEqual(a.a, b.a) &&
            almostEqual(a.b, b.b) &&
            almostEqual(a.c, b.c) &&
            almostEqual(a.d, b.d) &&
            almostEqual(a.tx, b.tx) &&
            almostEqual(a.ty, b.ty)
        )
        
    }
    
    func rotationForTrack(videoTrack: AVAssetTrack) -> Rotation {
        let size = videoTrack.naturalSize
        let txf = videoTrack.preferredTransform
        
        if almostEqual(txf, transformFor(rotation: .noRotation, videoSize: size)) {
            return .noRotation
        } else if almostEqual(txf, transformFor(rotation: .counterClockwise90, videoSize: size)) {
            return .counterClockwise90
        } else if almostEqual(txf, transformFor(rotation: .counterClockwise180, videoSize: size)) {
            return .counterClockwise180
        } else if almostEqual(txf, transformFor(rotation: .counterClockwise270, videoSize: size)) {
            return .counterClockwise270
        } else {
            NSLog("Unexpected transform: \(txf))")
            return .noRotation
        }
    }
    
    func next(rotation: Rotation) -> Rotation {
        switch rotation {
        case .noRotation:
            return .counterClockwise90
        case .counterClockwise90:
            return .counterClockwise180
        case .counterClockwise180:
            return .counterClockwise270
        case .counterClockwise270:
            return .noRotation
        }
    }
    
    func transformFor(rotation: Rotation, videoSize: CGSize) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        switch rotation {
        case .noRotation:
            break
        case .counterClockwise90:
            transform = transform.rotated(by: CGFloat(-1 * Double.pi / 2))
            transform = transform.translatedBy(x: 0.0, y: videoSize.width)
        case .counterClockwise180:
            transform = transform.rotated(by: CGFloat(-1 * Double.pi))
            transform = transform.translatedBy(x: videoSize.width, y: videoSize.height)
            break
        case .counterClockwise270:
            transform = transform.rotated(by: CGFloat(-1 * Double.pi * 3 / 2))
            transform = transform.translatedBy(x: videoSize.height, y: 0)
            break
        }

        return transform
    }
    
    func applyVideoFilter(_ filterName: String, input: PHContentEditingInput, output: PHContentEditingOutput, completion: @escaping () -> Void) {
        // Load the AVAsset to process from input.
        guard let avAsset = input.audiovisualAsset
            else { fatalError("Can't fetch the AVAsset to edit.") }
        
        
        
        
//        let formatsKey = "availableMetadataFormats"
//
//        avAsset.loadValuesAsynchronously(forKeys: [formatsKey]) {
//            var error: NSError? = nil
//            let status = avAsset.statusOfValue(forKey: formatsKey, error: &error)
//            if status == .loaded {
//                for format in avAsset.availableMetadataFormats {
//                    let metadata = avAsset.metadata(forFormat: format)
//                    // process format-specific metadata collection
//                }
//            }
//        }

        
        
        
        
        
        //tracksWithMediaType:AVMediaTypeVideo
//        let composition2 = AVVideoComposition(propertiesOf: <#T##AVAsset#>)
        
        
        
        /*
 
 AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
 instruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
 
 AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTrack];
 
 CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(M_PI_2);
 
 [layerInstruction setTransform:rotationTransform atTime:kCMTimeZero];
 instruction.layerInstructions = @[layerInstruction];
 
 AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
 videoComposition.renderSize = CGSizeMake(videoWidth, videoHeight);
 videoComposition.instructions = @[instruction];
 videoComposition.frameDuration = CMTimeMake(1, 30);
 
 AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
 exporter.outputURL = exportURL;
 exporter.outputFileType = AVFileTypeQuickTimeMovie;
 exporter.videoComposition = videoComposition;
 
 [exporter exportAsynchronouslyWithCompletionHandler:^{
 
 }];
 */
        
        
        // Set up a video composition to apply the filter.
//        let composition = AVMutableVideoComposition(
//            asset: avAsset,
//            applyingCIFiltersWithHandler: { request in
//                let filtered = request.sourceImage.applyingFilter(filterName, parameters: [:])
//                request.finish(with: filtered, context: nil)
//        })

        let clipVideoTrack = avAsset.tracks( withMediaType: AVMediaType.video ).first!

        let composition = AVMutableComposition()
        composition.naturalSize = CGSize(width: clipVideoTrack.naturalSize.height, height: clipVideoTrack.naturalSize.width)
        
        let mutableTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: CMPersistentTrackID())!
        
        
        do {
            try mutableTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: avAsset.duration), of: clipVideoTrack, at: CMTime.zero)
        }
        catch {
            NSLog(error.localizedDescription)
        }
        
        
//        let videoComposition = AVMutableVideoComposition()
//        videoComposition.renderSize = CGSize(width: clipVideoTrack.naturalSize.height, height: clipVideoTrack.naturalSize.width)
//        videoComposition.frameDuration = clipVideoTrack.minFrameDuration
//
//        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: clipVideoTrack)
        
//        let instruction = AVMutableVideoCompositionInstruction()
//        instruction.timeRange = clipVideoTrack.timeRange
        
        let rotation = rotationForTrack(videoTrack: clipVideoTrack)
        let newRotation = next(rotation: rotation)
        let newTransform = transformFor( rotation: newRotation, videoSize: clipVideoTrack.naturalSize)
        
        
//        transformer.setTransform(transform, at: CMTime.zero)
        
//        instruction.layerInstructions = [transformer]
//        videoComposition.instructions = [instruction]
        
        
        //

        mutableTrack.preferredTransform = newTransform

    

        /*
         
         
         let videoComposition = AVMutableVideoComposition()
         videoComposition.renderSize = CGSize(width: clipVideoTrack.naturalSize.height, height: clipVideoTrack.naturalSize.width)
         videoComposition.frameDuration = CMTimeMake(1, 30)
         
         let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: clipVideoTrack)
         
         let instruction = AVMutableVideoCompositionInstruction()
         instruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(60, 30))
         var transform:CGAffineTransform = CGAffineTransform(scaleX: -1.0, y: 1.0)
         transform = transform.translatedBy(x: -clipVideoTrack.naturalSize.width, y: 0.0)
         transform = transform.rotated(by: CGFloat(Double.pi/2))
         transform = transform.translatedBy(x: 0.0, y: -clipVideoTrack.naturalSize.width)
         
         transformer.setTransform(transform, at: kCMTimeZero)
         
         instruction.layerInstructions = [transformer]
         videoComposition.instructions = [instruction]
         
         // Export
         
         let exportSession = AVAssetExportSession(asset: videoAsset, presetName: AVAssetExportPreset640x480)!
         let fileName = UniqueIDGenerator.generate().appending(".mp4")
         let filePath = documentsURL.appendingPathComponent(fileName)
         let croppedOutputFileUrl = filePath
         exportSession.outputURL = croppedOutputFileUrl
         
         
         
         
        // Grab the source track from AVURLAsset for example.
        let assetVideoTrack = avAsset.tracks(withMediaType: .video)[0]
        
        // Grab the composition video track from AVMutableComposition you already made.
        let compositionVideoTrack = composition.tracks// .tracks(withMediaType: .video)[0]
 
        */
    
        
        // Apply the original transform.
//        if (assetVideoTrack && compositionVideoTrack) {
//            compositionVideoTrack.preferredTransform = assetVideoTrack.preferredTransform
//        }

//        for track in avAsset.tracks {
//            if track.mediaType == AVMediaType.video {
//                // rotate
//            }
//
//        }

        
        /*
 // Insert the video and audio tracks from AVAsset
 if (assetVideoTrack != nil) {
 AVMutableCompositionTrack *compositionVideoTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
 [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:assetVideoTrack atTime:insertionPoint error:&error];
 
 }
 if (assetAudioTrack != nil) {
 AVMutableCompositionTrack *compositionAudioTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
 [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:assetAudioTrack atTime:insertionPoint error:&error];
 }*/
        
        
//        let videoTrack = avAsset.tracks(withMediaType: AVMediaType.video)[0]
//        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack);
//        let rotationTransform = CGAffineTransform.init(rotationAngle: .pi / 2 );
//        layerInstruction.setTransform(rotationTransform, at: CMTime.zero)
//
//
//        let mainInstruction = AVMutableVideoCompositionInstruction()
//        mainInstruction.timeRange = videoTrack.timeRange
//        mainInstruction.layerInstructions = [layerInstruction]
//        composition.instructions = [mainInstruction]
        
        
        // Export the video composition to the output URL.
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough/*AVAssetExportPresetHighestQuality*/)
            else { fatalError("Can't configure the AVAssetExportSession.") }
//        export.video
        export.outputFileType = AVFileType.mov
        export.outputURL = output.renderedContentURL
        //export.videoComposition = videoComposition
        export.exportAsynchronously(completionHandler: completion)
    }
}

// MARK: PHPhotoLibraryChangeObserver
extension AssetViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // The call might come on any background queue. Re-dispatch to the main queue to handle it.
        DispatchQueue.main.sync {
            // Check if there are changes to the displayed asset.
            guard let details = changeInstance.changeDetails(for: asset) else { return }
            
            // Get the updated asset.
            asset = details.objectAfterChanges
            
            // If the asset's content changes, update the image and stop any video playback.
            if details.assetContentChanged {
                updateImage()
                
                playerLayer?.removeFromSuperlayer()
                playerLayer = nil
            }
        }
    }
}

// MARK: PHLivePhotoViewDelegate
extension AssetViewController: PHLivePhotoViewDelegate {
    func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        isPlayingHint = (playbackStyle == .hint)
    }
    
    func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        isPlayingHint = (playbackStyle == .hint)
    }
}
