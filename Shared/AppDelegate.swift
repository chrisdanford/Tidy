/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the sample's app delegate.
*/

import UIKit
import Photos

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NSLog("application:didFinishLaunchingWithOptions")

        guard let splitViewController = self.window?.rootViewController as? UISplitViewController else {
            return true
        }
        splitViewController.preferredDisplayMode = .allVisible
        #if os(iOS)
        guard let navigationController = splitViewController.viewControllers.last as? UINavigationController else {
            return true
        }
        //navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        #endif
        splitViewController.delegate = self

        return true
    }
    
    var indexingStarted = false
    var alertController: UIAlertController?
    
    func ensureAuthorizationStatus() {
        if !indexingStarted {
            PHPhotoLibrary.requestAuthorization { (authorizationStatus) in
                NSLog("ensure authorized callback")
                switch authorizationStatus {
                case .authorized:
                    // Begin indexing
                    self.indexingStarted = true
                    AppManager.resetAndFetch()
                default:
                    DispatchQueue.main.async {
                        let alertController = UIAlertController(title: "PhotoTidy needs access to your Photos library.", message: "Enable access in Settings in order to continue.", preferredStyle: .alert)
                        
                        let action1 = UIAlertAction(title: "Go to Settings", style: .default) { (action:UIAlertAction) in
                            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                                return
                            }
                            
                            if UIApplication.shared.canOpenURL(settingsUrl) {
                                UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                                    print("Settings opened: \(success)") // Prints true
                                })
                            }
                        }
                        
                        alertController.addAction(action1)
                        self.alertController = alertController
                        self.window!.rootViewController!.present(alertController, animated: true, completion: nil)
                    }
                }
            }
        }
        Notifications.ensureAuthorized()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        ensureAuthorizationStatus()

        if indexingStarted {
            AppManager.instance.fetchRecentlyDeleted()
        }

        updateBadgeCount()

        Preferences.Persistence.instance.readRemoteChanges()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        if let alertController = alertController {
            alertController.dismiss(animated: false, completion: nil)
        }
        
        NSLog("BackgroundTimeRemaining \(NSString(format: "%.2f", UIApplication.shared.backgroundTimeRemaining))")
        
        updateBadgeCount()
    }

    func updateBadgeCount() {
        Notifications.setBadge(count: mainStore.state.badgeCount)
    }
    
    // MARK: Split view
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController,
                             onto primaryViewController: UIViewController) -> Bool {
//        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else {
//            return true
//        }
//        guard let topAsDetailController = secondaryAsNavController.topViewController as? AssetGridViewController else {
//            return true
//        }
//        if topAsDetailController.fetchResult == nil {
//        }

        if let vc = primaryViewController as? MasterViewController2 {
            vc.clearTableViewSelection()
        }
        
        // What a mess. Pushing a nested UINavigationController usually supported, but an exception is made in the default behavior
        // when collapsing the secondary into the primary.
        // https://www.malhal.com/2017/01/27/default-behaviour-of-uisplitviewcontroller-collapsesecondaryviewcontroller/
        //
        // Normalize the behavior here by stripping out UINavigationController that is the secondaryView and pop its content
        // and push it onto the primary.
//        let primaryNavigationController = primaryViewController as! UINavigationController
//        let secondaryNavigationController = secondaryViewController as! UINavigationController
//        let controllersToPush = secondaryNavigationController.viewControllers
//        secondaryNavigationController.setViewControllers([], animated: false)
//        
//        for controllerToPush in controllersToPush {
//            controllerToPush.removeFromParent()
//            primaryNavigationController.pushViewController(controllerToPush, animated: false)
//        }
        
        // Propagate properties the UINavigationController that were probably set by the top ViewController.
//        primaryNavigationController.isToolbarHidden = secondaryNavigationController.isToolbarHidden
//        primaryNavigationController.isNavigationBarHidden = secondaryNavigationController.isNavigationBarHidden
//        primaryNavigationController.setToolbarItems(secondaryNavigationController.toolbarItems, animated: false)

        // Return true to indicate that the app has handled the collapse by doing nothing and will discard the secondary controller.
        return false
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, showDetail viewController: UIViewController, sender: Any?) -> Bool {
        // Let the storyboard handle the segue for every case except going from detail:assetgrid to detail:asset.
        guard !splitViewController.isCollapsed else {
            return false
        }
        guard !(viewController is UINavigationController) else {
            return false
        }
        let secondaryViewController = splitViewController.viewControllers[1] as! UINavigationController
        
        secondaryViewController.setViewControllers([viewController], animated: false)
        return true
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        let primary = primaryViewController as! UINavigationController
        let viewControllersToMove = primary.popToRootViewController(animated: false)
        
        // What a mess. Pushing a nested UINavigationController usually supported, but an exception is made in the default behavior
        // when collapsing the secondary into the primary.
        // https://www.malhal.com/2017/01/27/default-behaviour-of-uisplitviewcontroller-collapsesecondaryviewcontroller/

        func wrapInNavigationControllerIfNotAlready(viewControllers: [UIViewController]) -> UINavigationController {
            if let navigationController = viewControllers.first as? UINavigationController {
                return navigationController
            }
 
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let navigationController = storyboard.instantiateViewController(withIdentifier: "SecondaryViewController") as! UINavigationController
            navigationController.setViewControllers(viewControllers, animated: false)
            return navigationController
        }
//
        let navigationController = wrapInNavigationControllerIfNotAlready(viewControllers: viewControllersToMove ?? [])
//        if let viewControllersToMove2 = viewControllersToMove {
//            navigationController.setViewControllers(viewControllersToMove2, animated: false)

            
            //            secondary.setViewControllers(poppedVCs2, animated: false)
//        }
        return navigationController
//        return secondary
//        return nil
    }
}
