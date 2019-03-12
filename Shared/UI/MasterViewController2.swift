/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Implements the main view controller for album navigation.
 */

import UIKit
import Photos
import ReSwift

class MasterViewController2: UITableViewController, StoreSubscriber {
    
    // MARK: Types for managing sections, cell, and segue identifiers
//    enum Section: Int {
//        case status = 0
//        case identicalPhotos
//        case identicalVideos
//        case lowQuality
//        case compress
//        case recentlyDeleted
//        case savings
//
//        static let count = 7
//    }
    
    enum CellIdentifier: String {
        case status
        case header
        case feature
        case savings
    }
    
    enum SegueIdentifier: String {
        case duplicates
        case compress
    }
    
    var model = ViewModel.Table.empty()
    
    // MARK: UIViewController / Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Reduce the large gap between the bottom of the NavigationBar and the first cell.
        self.tableView.contentInset = UIEdgeInsets(top: -20, left: 0, bottom: 0, right: 0)
        
        
        
        var backgroundTask: UIBackgroundTaskIdentifier?
        backgroundTask = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(backgroundTask!)
        }
        NSLog("BackgroundTimeRemaining \(NSString(format: "%.2f", UIApplication.shared.backgroundTimeRemaining))")
        
        // Large titles take up too much space on tiny phones.
        let isPhoneAndiPhone5OrSmaller = UIDevice().userInterfaceIdiom == .phone && UIScreen.main.bounds.size.height <= 568
        if isPhoneAndiPhone5OrSmaller {
            self.navigationItem.largeTitleDisplayMode = .never
        }
        
        assert(backgroundTask != .invalid)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed

        // Update once, but don't subscribe.  We don't want to be updating while we're transitioning.
        applyState(state: mainStore.state)
        
        self.navigationController?.isToolbarHidden = true
    }
    

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Now that the transition is done, subscribe and apply all updates.
        mainStore.subscribe(self)
        applyState(state: mainStore.state)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        mainStore.unsubscribe(self)
    }
    
    /// - Tag: UnregisterChangeObserver
    deinit {
        //PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    var throttler: Throttler2? = nil
    func newState(state: AppState) {
        //var newState = state
        if throttler == nil {
            throttler = Throttler2.init(maxFrequency: 0.5)  { [weak self] in
                DispatchQueue.main.async {
                    self?.applyState(state: mainStore.state)
                }
            }
        }
        throttler?.executeThrottled()
    }

    func applyState(state: AppState) {
        model = ViewModel.Table.empty()
        model.sections = [
            ViewModel.TableSection(header: nil, rows: [
                .sizes]),
            ViewModel.TableSection(header: .header, rows: [
                .exactPhotos,
                .exactVideos,
                // .inexactPhotos,  // Disable for now.  Getting false duplicates
                .inexactVideos,
                .upgradeCompression,
                .largeFiles,
                .clearRecentlyDeleted]),
            ViewModel.TableSection(header: nil, rows: [
                .about]),
        ]
        
        for (sectionIndex, section) in model.sections.enumerated() {
            for (rowIndex, row) in section.rows.enumerated() {
                if let cell = tableView.cellForRow(at: IndexPath(row: rowIndex, section: sectionIndex)) {
                    row.update(cell: cell, state: state)
                }
            }
        }
    }
    
    // MARK: Segues
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let segueIdentifier = segue.identifier {
            guard let destination = (segue.destination as? UINavigationController)?.topViewController as? AssetGridViewController
                else { fatalError("Unexpected view controller for segue.") }
            guard let cell = sender as? UITableViewCell else { fatalError("Unexpected sender for segue.") }
            
            destination.title = cell.textLabel?.text
            
            switch SegueIdentifier(rawValue: segueIdentifier)! {
            case .duplicates: break
            //destination.fetchResult = allPhotos
            case .compress: break
            /*
                // Fetch the asset collection for the selected row.
                let indexPath = tableView.indexPath(for: cell)!
                let collection: PHCollection
                switch Section(rawValue: indexPath.section)! {
                case .smartAlbums:
                    collection = smartAlbums.object(at: indexPath.row)
                case .userCollections:
                    collection = userCollections.object(at: indexPath.row)
                default: return // The default indicates that other segues have already handled the photos section.
                }
                
                // configure the view controller with the asset collection
                guard let assetCollection = collection as? PHAssetCollection
                    else { fatalError("Expected an asset collection.") }
                //destination.fetchResult = PHAsset.fetchAssets(in: assetCollection, options: nil)
                destination.assetCollection = assetCollection
     */
            }
        }
    }
    
    // MARK: Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return model.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.sections[section].rows.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = model.sections[indexPath.section].rows[indexPath.row]
        
        switch row.selectionAction() {
        case .none:
            break
        case .push(let viewController):
            self.splitViewController?.showDetailViewController(viewController, sender: nil)
        case .present(let viewController, let requestStoreReview):
            self.present(viewController, animated: true) { [weak self] in
                self?.clearTableViewSelection()
            }
            if requestStoreReview {
                StoreUtil.requestReview()
            }
        }
    }
    
    func clearTableViewSelection() {
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return model.sections[section].header?.height ?? 0
    }
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let state = mainStore.state!

        if let header = model.sections[section].header {
            let cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.header.rawValue)!
            header.loadCell(cell: cell, state: state)
            return cell
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let state = mainStore.state!
        
        let row = model.sections[indexPath.section].rows[indexPath.row]

        let cell: UITableViewCell
        switch row {
        case .sizes:
            cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.status.rawValue, for: indexPath)
        case .header:
            fatalError()
        case .exactPhotos, .exactVideos, .inexactPhotos, .inexactVideos, .upgradeCompression, .clearRecentlyDeleted, .largeFiles:
            cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.feature.rawValue, for: indexPath)
        case .about:
            cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.savings.rawValue, for: indexPath)
        }
        row.loadCell(cell: cell, state: state)
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return model.sections[indexPath.section].rows[indexPath.item].height
    }
}
