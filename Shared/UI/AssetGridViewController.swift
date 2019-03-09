/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implements the view controller for browsing photos in a grid layout.
*/

import UIKit
import Photos
import PhotosUI
import ReSwift

extension UICollectionView {
    func indexPathsForElements(in rect: CGRect) -> [IndexPath] {
        let allLayoutAttributes = collectionViewLayout.layoutAttributesForElements(in: rect)!
        return allLayoutAttributes.filter({ $0.representedElementCategory == .cell }).map { $0.indexPath }
    }
}

class AssetGridViewController: UICollectionViewController, StoreSubscriber {
    
    //var fetchResult: PHFetchResult<PHAsset>!
    var state: AppState = AppState.empty()
    var assetCollection: PHAssetCollection!
    var availableWidth: CGFloat = 0
    
    @IBOutlet var addButtonItem: UIBarButtonItem!
    @IBOutlet var transcodeButtonItem: UIBarButtonItem!
    @IBOutlet weak var collectionViewFlowLayout: UICollectionViewFlowLayout!
    
    fileprivate let imageManager = PHCachingImageManager()
    fileprivate var thumbnailSize: CGSize!
    fileprivate var previousPreheatRect = CGRect.zero
    
    // MARK: UIViewController / Life Cycle
    
    override func viewDidLoad() {
        state = mainStore.state
        super.viewDidLoad()
        
        resetCachedAssets()
        //PHPhotoLibrary.shared().register(self)
        
        // Reaching this point without a segue means that this AssetGridViewController
        // became visible at app launch. As such, match the behavior of the segue from
        // the default "All Photos" view.
//        if fetchResult == nil {
//            let allPhotosOptions = PHFetchOptions()
//            allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
//            fetchResult = PHAsset.fetchAssets(with: allPhotosOptions)
//        }

//        self.state = Store.subscribe { (stateChange) in
//            DispatchQueue.main.async { [weak self] in
//                self?.apply(stateChange: stateChange)
//            }
//        }
    }
    
    deinit {
//        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
//    func apply(stateChange: Store.StateChange) {
    func newState(state: AppState) {
        self.state = mainStore.state
//        collectionView.reload(changes: stateChange.compressChanges.workItemsChanges, section: 0, updateData: {
//            self.state = stateChange.newState
//        })
        
        // update progress
        // It's ugly to grab the section header this way, but the only working alternative
        // I've found so far is to reload the whole section.
        let supplementalView = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0))
        if supplementalView != nil {
            let headerView = supplementalView as! GridViewHeader?
            //headerView!.set(indexStatus: state.transcode)
        }
        
        //let transcodeItems = state.transcode.applyableTranscodeItems

//        let estimatedSavingsBytes = transcodeItems.reduce(0) {
//            return $0 + $1.estimatedSavingsBytes
//        }
//        let estimatedSavingsDisplay = UInt64(estimatedSavingsBytes).formattedCompactByteString
//
//        let applyableSavingsBytes = transcodeItems.reduce(0) {
//            return $0 + ($1.applyableSavingsBytes ?? 0)
//        }
//        let actualSavingsDisplay = UInt64(applyableSavingsBytes).formattedCompactByteString
//
//        transcodeButtonItem.title = "Apply \(transcodeItems.count) est \(estimatedSavingsDisplay) act \(actualSavingsDisplay)"
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let width = view.bounds.inset(by: view.safeAreaInsets).width
        // Adjust the item size if the available width has changed.
        if availableWidth != width {
            availableWidth = width
            let itemHeight: CGFloat = 80
            let minItemWidth: CGFloat = itemHeight
            let columnCount = (availableWidth / minItemWidth).rounded(.towardZero)
            let itemLength = (availableWidth - columnCount - 1) / columnCount
            collectionViewFlowLayout.itemSize = CGSize(width: itemLength, height: itemHeight)
            collectionViewFlowLayout.sectionHeadersPinToVisibleBounds = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Determine the size of the thumbnails to request from the PHCachingImageManager.
        let scale = UIScreen.main.scale
        let cellSize = collectionViewFlowLayout.itemSize
        thumbnailSize = CGSize(width: cellSize.width * scale, height: cellSize.height * scale)
        
        // Add a button to the navigation bar if the asset collection supports adding content.
        if assetCollection == nil || assetCollection.canPerform(.addContent) {
            navigationItem.rightBarButtonItem = addButtonItem
        } else {
            navigationItem.rightBarButtonItem = nil
        }
        
        navigationItem.rightBarButtonItem = transcodeButtonItem

        mainStore.subscribe(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        mainStore.unsubscribe(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateCachedAssets()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let destination = segue.destination as? AssetViewController else { fatalError("Unexpected view controller for segue") }
        guard let collectionViewCell = sender as? UICollectionViewCell else { fatalError("Unexpected sender for segue") }
        
        let indexPath = collectionView.indexPath(for: collectionViewCell)!
//        destination.asset = self.state.transcode.workItems[indexPath.item].asset
        destination.assetCollection = assetCollection
    }
    
    // MARK: UICollectionView

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1//state.transcode.workItems.count
    }
    /// - Tag: PopulateCell
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
 //       let workItem = state.transcode.workItems[indexPath.item]
        let asset = state.transcode.transcodingComplete[0]
        // Dequeue a GridViewCell.
        /*guard*/ let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GridViewCell", for: indexPath) //as? GridViewCell
//            else { fatalError("Unexpected cell in collection view") }
//
//        // Add a badge to the cell if the PHAsset represents a Live Photo.
//        if asset.mediaSubtypes.contains(.photoLive) {
//            cell.livePhotoBadgeImage = PHLivePhotoView.livePhotoBadgeImage(options: .overContent)
//        }
//        
//        //cell.workItem = workItem
//        
//        // Request an image for the asset from the PHCachingImageManager.
//        cell.representedAssetIdentifier = asset.localIdentifier
//        imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil, resultHandler: { image, _ in
//            // UIKit may have recycled this cell by the handler's activation time.
//            // Set the cell's thumbnail image only if it's still showing the same asset.
//            if cell.representedAssetIdentifier == asset.localIdentifier {
//                cell.thumbnailImage = image
//            }
//        })
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "GridViewHeader", for: indexPath) as? GridViewHeader
            else { fatalError("Unexpected cell in collection view") }
        //header.set(indexStatus: self.state.transcode)
        return header
    }
    
    // MARK: UIScrollView
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCachedAssets()
    }
    
    // MARK: Asset Caching
    
    fileprivate func resetCachedAssets() {
        imageManager.stopCachingImagesForAllAssets()
        previousPreheatRect = .zero
    }
    /// - Tag: UpdateAssets
    fileprivate func updateCachedAssets() {
        // Update only if the view is visible.
        guard isViewLoaded && view.window != nil else { return }
        
        // The window you prepare ahead of time is twice the height of the visible rect.
        let visibleRect = CGRect(origin: collectionView!.contentOffset, size: collectionView!.bounds.size)
        let preheatRect = visibleRect.insetBy(dx: 0, dy: -0.5 * visibleRect.height)
        
        // Update only if the visible area is significantly different from the last preheated area.
        let delta = abs(preheatRect.midY - previousPreheatRect.midY)
        guard delta > view.bounds.height / 3 else { return }
        
        // Compute the assets to start and stop caching.
//        let (addedRects, removedRects) = differencesBetweenRects(previousPreheatRect, preheatRect)
//        let addedAssets = addedRects
//            .flatMap { rect in collectionView!.indexPathsForElements(in: rect) }
//            .filter { indexPath in indexPath.section == 0 && indexPath.item < self.state.transcode.workItems.count }
//            .map { indexPath in self.state.transcode.workItems[indexPath.item].asset }
//        let removedAssets = removedRects
//            .flatMap { rect in collectionView!.indexPathsForElements(in: rect) }
//            .filter { indexPath in indexPath.section == 0 && indexPath.item < self.state.transcode.workItems.count }
//            .map { indexPath in self.state.transcode.workItems[indexPath.item].asset }
        
        // Update the assets the PHCachingImageManager is caching.
//        imageManager.startCachingImages(for: addedAssets,
//                                        targetSize: thumbnailSize, contentMode: .aspectFill, options: nil)
//        imageManager.stopCachingImages(for: removedAssets,
//                                       targetSize: thumbnailSize, contentMode: .aspectFill, options: nil)
//        // Store the computed rectangle for future comparison.
        previousPreheatRect = preheatRect
    }
    
    fileprivate func differencesBetweenRects(_ old: CGRect, _ new: CGRect) -> (added: [CGRect], removed: [CGRect]) {
        if old.intersects(new) {
            var added = [CGRect]()
            if new.maxY > old.maxY {
                added += [CGRect(x: new.origin.x, y: old.maxY,
                                 width: new.width, height: new.maxY - old.maxY)]
            }
            if old.minY > new.minY {
                added += [CGRect(x: new.origin.x, y: new.minY,
                                 width: new.width, height: old.minY - new.minY)]
            }
            var removed = [CGRect]()
            if new.maxY < old.maxY {
                removed += [CGRect(x: new.origin.x, y: new.maxY,
                                   width: new.width, height: old.maxY - new.maxY)]
            }
            if old.minY < new.minY {
                removed += [CGRect(x: new.origin.x, y: old.minY,
                                   width: new.width, height: new.minY - old.minY)]
            }
            return (added, removed)
        } else {
            return ([new], [old])
        }
    }
    
    @IBAction func transcode(_ sender: Any) {
        NSLog("transcode")

//        let transcodeItems = self.state.transcode.applyableTranscodeItems
//
//        for x in transcodeItems {
//            switch x.transcodeStatus {
//            case .success(let stats):
//                NSLog("originalFileSize \(stats.originalFileSize) actualTranscodedFileSize \(stats.actualTranscodedFileSize) savings \(stats.applyableSavingsBytes!)")
//            default:
//                break
//            }
//        }
//        
//        // use the first N items while debugging
//        let items = transcodeItems//.prefix(2)
//        
//        let assets = items.map { return $0.asset }
//        if assets.count > 0 {
//            PHAssetReplace.replaceWithTranscoded(assets: assets) { result in
//                switch result {
//                case .success(let savings):
//                    dispatch(AppliedTranscode(savingsStats: savings))
//                    break
//                case .error:
//                    NSLog("error exporting")
//                }
//            }
//        }
    }

    // MARK: UI Actions
    /// - Tag: AddAsset
    @IBAction func addAsset(_ sender: AnyObject?) {
        
        // Create a dummy image of a random solid color and random orientation.
        let size = (arc4random_uniform(2) == 0) ?
            CGSize(width: 400, height: 300) :
            CGSize(width: 300, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(hue: CGFloat(arc4random_uniform(100)) / 100,
                    saturation: 1, brightness: 1, alpha: 1).setFill()
            context.fill(context.format.bounds)
        }
        // Add the asset to the photo library.
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            if let assetCollection = self.assetCollection {
                let addAssetRequest = PHAssetCollectionChangeRequest(for: assetCollection)
                addAssetRequest?.addAssets([creationRequest.placeholderForCreatedAsset!] as NSArray)
            }
        }, completionHandler: {success, error in
            if !success { NSLog("Error creating the asset: \(String(describing: error))") }
        })
    }
    
}

// MARK: PHPhotoLibraryChangeObserver
//extension AssetGridViewController: PHPhotoLibraryChangeObserver {
//    func photoLibraryDidChange(_ changeInstance: PHChange) {
//
//        guard let changes = changeInstance.changeDetails(for: fetchResult)
//            else { return }
//
//        // Change notifications may originate from a background queue.
//        // As such, re-dispatch execution to the main queue before acting
//        // on the change, so you can update the UI.
//        DispatchQueue.main.sync {
//            // Hang on to the new fetch result.
//            fetchResult = changes.fetchResultAfterChanges
//            // If we have incremental changes, animate them in the collection view.
//            if changes.hasIncrementalChanges {
//                guard let collectionView = self.collectionView else { fatalError() }
//                // Handle removals, insertions, and moves in a batch update.
//                collectionView.performBatchUpdates({
//                    if let removed = changes.removedIndexes, !removed.isEmpty {
//                        collectionView.deleteItems(at: removed.map({ IndexPath(item: $0, section: 0) }))
//                    }
//                    if let inserted = changes.insertedIndexes, !inserted.isEmpty {
//                        collectionView.insertItems(at: inserted.map({ IndexPath(item: $0, section: 0) }))
//                    }
//                    changes.enumerateMoves { fromIndex, toIndex in
//                        collectionView.moveItem(at: IndexPath(item: fromIndex, section: 0),
//                                                to: IndexPath(item: toIndex, section: 0))
//                    }
//                })
//                // We are reloading items after the batch update since `PHFetchResultChangeDetails.changedIndexes` refers to
//                // items in the *after* state and not the *before* state as expected by `performBatchUpdates(_:completion:)`.
//                if let changed = changes.changedIndexes, !changed.isEmpty {
//                    collectionView.reloadItems(at: changed.map({ IndexPath(item: $0, section: 0) }))
//                }
//            } else {
//                // Reload the collection view if incremental changes are not available.
//                collectionView.reloadData()
//            }
//            resetCachedAssets()
//        }
//    }
//}



