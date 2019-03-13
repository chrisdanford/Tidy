//
//  DuplicatesViewController.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/9/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import UIKit
import Photos
import ReSwift
import DeepDiff

class DuplicatesViewController: UIViewController, StoreSubscriber {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var applyBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var spaceToRecoverBarButtonItem: UIBarButtonItem!
    
    var lastWidth: CGFloat = 0
    var lastColumnCount: Int = 0

    var state = AppState.empty()
    var sectionModels = [ViewModel.GridSection]()
    var gridDataSource = GridDataSource.empty()

    /*
    static func attributedString(from string: String, nonBoldRange: NSRange?) -> NSAttributedString {
        let fontSize = UIFont.systemFontSize
        let attrs = [
            NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: fontSize),
            //x NSAttributedString.Key.foregroundColor: UIColor.black
        ]
        let nonBoldAttribute = [
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1),
            ]
        let attrStr = NSMutableAttributedString(string: string, attributes: attrs)
        if let range = nonBoldRange {
            attrStr.setAttributes(nonBoldAttribute, range: range)
        }
        return attrStr
    }
     */
    func makeButtonAttributedText(smallText: String, bigText: String) -> NSAttributedString {
        return (NSAttributedString(string: smallText, font: UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1)) +
            NSAttributedString(string: bigText, font: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)))
    }

    
    func set(gridDataSource: GridDataSource) {
        self.gridDataSource = gridDataSource
        
        self.navigationItem.title = gridDataSource.title
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        collectionView.register(AssetGridCell.self, forCellWithReuseIdentifier: "AssetGridCell")

        let headerNib = UINib(nibName: "DuplicatesSectionHeaderView", bundle: nil)
        collectionView.register(headerNib, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "DuplicatesSectionHeaderView")
        
        //collectionView.register(TranscodeSectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "TranscodeSectionHeaderView")

        // Give a bottom inset because the bottom section is overlapping the collectionView content.
        // Warning: Fragile magic number
        //collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 102, right: 0)
        
        collectionViewLayout.sectionHeadersPinToVisibleBounds = true
        
        //newState(state: mainStore.state)
        
        //pulsateBackgroundColor(view: applyButton)
        
        collectionViewLayout.headerReferenceSize = CGSize(width: self.collectionView.frame.size.width, height: 100)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Determine the size of the thumbnails to request from the PHCachingImageManager.
        let scale = UIScreen.main.scale
        let cellSize = collectionViewLayout.itemSize
        thumbnailSize = CGSize(width: cellSize.width * scale, height: cellSize.height * scale)

        // Update once but don't subscribe.  We don't want to be updating while the transition is in progress.
        newState(state: mainStore.state)
        
//        let blue = UIColor(red: 34.0/255, green: 103.0/255, blue: 255.0/255, alpha: 1)
//        self.navigationController?.toolbar.barTintColor = blue
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateCachedAssets()

        // Now that the transition is finished, subscribe and start updating.
        mainStore.subscribe(self)
        newState(state: mainStore.state)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        mainStore.unsubscribe(self)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    func newState(state: AppState) {
        /*
        let assets = state.transcode.eligibleForTranscoding
        sectionModels = assets
            .map({ (asset) -> AssetGridView.Model in
                return AssetGridView.Model(asset: asset, deleteCount: nil)
            })
        
        let formattedCount = duplicateGroups.numAssetsToDelete.formattedDecimalString
        applyButton.setTitle("Apply \(formattedCount) Deletes", for: .normal)
        applyButton.setTitleColor(UIColor.white, for: .normal)
        
        spaceToRecoverLabel.text = duplicateGroups.bytesToDelete.formattedCompactByteString
*/
        self.state = state
        let newSectionModels = gridDataSource.viewModels(state)
        // TODO: move diffing off the main thread
        if sectionModels.count != newSectionModels.count {
            self.sectionModels = newSectionModels
            collectionView.reloadData()
        } else {
            for sectionIndex in 0..<newSectionModels.count {
                let changes = diff(old: sectionModels[sectionIndex].cells, new: newSectionModels[sectionIndex].cells)
                collectionView.reload(changes: changes, section: sectionIndex, updateData: {
                    self.sectionModels[sectionIndex] = newSectionModels[sectionIndex]
                })
            }
        }
        
        let primaryButton = gridDataSource.primaryButton(state)
        navigationController?.isToolbarHidden = (primaryButton == nil)
        if let button = primaryButton {
            if applyBarButtonItem.customView == nil {
                applyBarButtonItem.customView = makeButton()
            }
            let buttonView = applyBarButtonItem.customView as! UIButton
            
            var attributedTexts = [
                NSAttributedString(string: button.labelText + "\n", color: UIColor.white, font: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)),
            ]
            let moreAttributedTexts = [
                NSAttributedString(string: " Space to recover: ", color: UIColor.init(white: 1, alpha: 0.6), font: UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1)),
                NSAttributedString(string: button.spaceToRecoverBytes.formattedCompactByteString, color: UIColor.init(white: 1, alpha: 1), font: UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption2)),
                ]
            attributedTexts.append(contentsOf: moreAttributedTexts)
            
            buttonView.setAttributedTitle(NSAttributedString.join(attributedTexts), for: .normal)
            buttonView.isEnabled = button.isEnabled
            
            if buttonView.isEnabled {
                let color = UIColor(red: 34.0/255, green: 103.0/255, blue: 255.0/255, alpha: 1)
                buttonView.backgroundColor = color
            } else {
                let color = UIColor(white: 0.5, alpha: 1)
                buttonView.backgroundColor = color
            }
            
            buttonView.sizeToFit()
            applyBarButtonItem.customView = buttonView
            navigationController?.isToolbarHidden = false
            self.toolbarItems = [applyBarButtonItem,]
        }
                
        // Update all visible headers.
        // TODO: Is there a better way to diff and update the headers?
        let visibleHeaderIndexPaths = collectionView.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader)
        let visibleHeaderViews = collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        for (indexPath, header) in zip(visibleHeaderIndexPaths, visibleHeaderViews) {
            let sectionHeader = sectionModels[indexPath.section].sectionHeader!
            switch sectionHeader {
            case .duplicates(let sectionModel):
                let specificHeader = header as! DuplicatesSectionHeaderView
                specificHeader.load(model: sectionModel)
            case .transcode(let sectionModel):
                let specificHeader = header as! TranscodeSectionHeaderView
                specificHeader.load(model: sectionModel)
            }
        }
    }
    
    func makeButton() -> UIButton {
        let lightBlue = UIColor(red: 68.0/255, green: 206.0/255, blue: 255.0/255, alpha: 1)

        let button = UIButton(type: .custom)
        //let text = gridDataSource.buttonLabelText(state)
        //button.setTitle("aa", for: .normal)
        
        button.setTitleColor(lightBlue, for: .highlighted)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.layer.cornerRadius = 3.0
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 30, bottom: 10, right: 30)
        button.addTarget(self, action: #selector(applyAction(sender:)), for: .touchUpInside)
        return button
    }

    @objc func applyAction(sender: UIBarButtonItem) {
        self.actionRemoveDuplicates(sender)
    }
    
    func makeSpaceToRecoverView(text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: UIFont.TextStyle.caption1)
        return label
    }

    /*
    func darkerColorForColor(color: UIColor) -> UIColor {
        
        var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
        
        if color.getRed(&r, green: &g, blue: &b, alpha: &a){
            return UIColor(red: max(r - 0.2, 0.0), green: max(g - 0.2, 0.0), blue: max(b - 0.2, 0.0), alpha: a)
        }
        
        return UIColor()
    }
    
    func pulsateBackgroundColor(view: UIView) {
        let originalColor = view.backgroundColor!
        let darkenedColor = darkerColorForColor(color: originalColor)
        
        UIView.animateKeyframes(withDuration: 2, delay: 0, options: [.autoreverse, .repeat], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5, animations: {
                view.layer.backgroundColor = darkenedColor.cgColor
            })
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5, animations: {
                view.layer.backgroundColor = originalColor.cgColor
            })
        }, completion: nil)
    }
     */
    
    static func numberOfColsFrom(width: CGFloat, forceEvenColumnCount: Bool) -> Int {
        let iPhone6PointsWidth = CGFloat(375)
        let minDimension: CGFloat = iPhone6PointsWidth / CGFloat(4)
        let minItemWidth: CGFloat = minDimension
        let columnCount = (width / minItemWidth).rounded(.towardZero)
        
        if forceEvenColumnCount {
            return Int((columnCount / 2).rounded(.towardZero) * 2)
        } else {
            return Int(columnCount)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let width = view.bounds.width
        // Adjust the item size if the available width has changed.
        if lastWidth != width {
            lastWidth = width
            let columnCount = DuplicatesViewController.numberOfColsFrom(width: width, forceEvenColumnCount: gridDataSource.forceEvenColumnCount)
            lastColumnCount = columnCount
            let finalItemDimension = width / CGFloat(columnCount)
            collectionViewLayout.itemSize = CGSize(width: finalItemDimension, height: finalItemDimension)
        
            let visibleHeaderViews = collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
            for header in visibleHeaderViews {
                if let specificHeader = header as? DuplicatesSectionHeaderView {
                    specificHeader.set(columnCount: columnCount)
                }
            }
        }
    }
    
    @IBAction func actionRemoveDuplicates(_ sender: Any) {
        let progressController = self.showProgressHUD(message: self.gridDataSource.applyActionProgressMessage)
        let state = self.state

        // Apply the action off of Main.  It may take a while to return, and we want the progress message
        // to show immediately.
        DispatchQueue.global().async {
            if let button = self.gridDataSource.primaryButton(state) {
                button.applyAction(state, { [weak self] progressOrResult in
                    switch progressOrResult {
                    case .progress(let message):
                        progressController.set(message: message)
                    case .result(let result):
                        var ending: UIViewController.ProgressController.Ending
                        switch result {
                        case .success:
                            ending = .success
                            DispatchQueue.main.async {
                                self?.navigationController?.popViewController(animated: true)
                                AppManager.resetAndFetch()
                            }
                        case .cancelledOrError:
                            ending = .errorOrCancelled
                            DispatchQueue.main.async {
                                // PHPhotoLibrary.performChanges doesn't not give a way to differentiate between "error" and "cancelled", and the errors
                                // that it returns are always worthless "domain=NSCocoaErrorDomain, code=-1" errors.  It's inactionable, so don't show the error.
                                
                                //self?.showSimpleOKAlert(title: "Failed to apply changes", message: error.friendlyLocalizedDescription)
                                
                                AppManager.resetAndFetch()
                            }
                        }
                        progressController.end(ending: ending)
                    }
                })
            }
        }
    }

    fileprivate let imageManager = PHCachingImageManager()
    fileprivate var thumbnailSize: CGSize!
    fileprivate var previousPreheatRect = CGRect.zero
    
    // MARK: UIScrollView
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
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
        
        func assetFor(cell: ViewModel.Cell) -> PHAsset? {
            switch cell {
            case .instructions:
                return nil
            case .asset(let model):
                return model.assetModel.asset
            }
        }
        
        // Compute the assets to start and stop caching.
        let (addedRects, removedRects) = differencesBetweenRects(previousPreheatRect, preheatRect)
        let addedAssets = addedRects
            .flatMap { rect in collectionView!.indexPathsForElements(in: rect) }
            //.filter { indexPath in  && indexPath.item < sectionModels.count }
            .compactMap { indexPath in assetFor(cell: sectionModels[indexPath.section].cells[indexPath.item]) }
        let removedAssets = removedRects
            .flatMap { rect in collectionView!.indexPathsForElements(in: rect) }
            //.filter { indexPath in indexPath.section > Section.instructions.rawValue && indexPath.item < sectionModels.count }
            .compactMap { indexPath in assetFor(cell: sectionModels[indexPath.section].cells[indexPath.item]) }
        
        
        // Update the assets the PHCachingImageManager is caching.
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        imageManager.startCachingImages(for: addedAssets,
                                        targetSize: thumbnailSize, contentMode: .aspectFill, options: options)
        imageManager.stopCachingImages(for: removedAssets,
                                       targetSize: thumbnailSize, contentMode: .aspectFill, options: options)
        
        // Store the computed rectangle for future comparison.
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
}

extension DuplicatesViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sectionModels.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sectionModels[section].cells.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellModel = sectionModels[indexPath.section].cells[indexPath.item]
        switch cellModel {
        case .instructions(let instructions):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "instructions", for: indexPath) as! InstructionsCell
            cell.set(model: instructions)
            return cell
        case .asset(let model):
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AssetGridCell", for: indexPath) as? AssetGridCell
                else { fatalError("Unexpected cell in collection view") }
            cell.load(imageManager: imageManager, model: model)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            if let sectionHeader = self.sectionModels[indexPath.section].sectionHeader {
                switch sectionHeader {
                case .duplicates(let model):
                    let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "DuplicatesSectionHeaderView", for: indexPath) as! DuplicatesSectionHeaderView
                    header.load(model: model)
                    header.set(columnCount: self.lastColumnCount)
                    return header
                case .transcode(let model):
                    let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "TranscodeSectionHeaderView", for: indexPath) as! TranscodeSectionHeaderView
                    header.load(model: model)
                    return header
                }
            }
        }
        fatalError()
    }
}

extension DuplicatesViewController {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cellModel = sectionModels[indexPath.section].cells[indexPath.item]
        switch cellModel {
        case .instructions(let instructions):
            if let learnMore = instructions.learnMore {
                self.showSimpleOKAlert(title: self.navigationItem.title ?? "", message: instructions.text + "\n\n" + learnMore)
            }
        case .asset(let model):
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "assetViewController") as! AssetViewController
            vc.asset = model.assetModel.asset
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension DuplicatesViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        // Wonky: The only way to not display a section header is to return a zero-sized view.
        let sectionHeader = sectionModels[section].sectionHeader
        if sectionHeader == nil {
            return CGSize.zero
        } else {
            return CGSize(width: collectionView.bounds.size.width, height: 50)
        }
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellModel = sectionModels[indexPath.section].cells[indexPath.item]
        switch cellModel {
        case .instructions:
            // Hacky.  Measure size that fits and return that.  It would be better for cells to be self-sized, but this
            // is complicated and error-prone.
//            let cell = self.collectionView(collectionView, cellForItemAt: indexPath)
//            let width = collectionView.bounds.width - collectionView.contentInset.left - collectionView.contentInset.right
//            let fittedSize = cell.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
//            return fittedSize
            let width = collectionView.bounds.width - collectionView.contentInset.left - collectionView.contentInset.right
            return CGSize(width: width, height: 100)
        case .asset:
            return self.collectionViewLayout.itemSize
        }
    }
}
