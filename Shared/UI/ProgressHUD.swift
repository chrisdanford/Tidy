//
//  ProgressHUD.swift
//  Tidy iOS
//
//  Created by Chris Danford on 3/6/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import JGProgressHUD

extension UIViewController {
    class ProgressController {
        let hud: JGProgressHUD
        
        fileprivate init(hud: JGProgressHUD) {
            self.hud = hud
        }
        func set(message: String) {
            DispatchQueue.main.async {
                self.hud.textLabel.text = message
            }
        }

        enum Ending {
            case none
            case success
            case errorOrCancelled
        }
        func end(ending: Ending) {
            DispatchQueue.main.async {
                //                hud?.hide(animated: true)
                //SVProgressHUD.dismiss()
                let hud = self.hud
                switch ending {
                case .none:
                    hud.dismiss()
                case .errorOrCancelled:
                    hud.textLabel.text = "Error or Cancelled"
                    //  hud.detailTextLabel.text = nil
                    hud.indicatorView = JGProgressHUDErrorIndicatorView()
                    hud.dismiss(afterDelay: 3, animated: true)
                case .success:
                    hud.textLabel.text = "Success"
                    //  hud.detailTextLabel.text = nil
                    hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                    hud.dismiss(afterDelay: 3, animated: true)
                }
            }
        }
    }
    func showProgressHUD(message: String) -> ProgressController {
        assert(Thread.isMainThread)
        
        let hud = JGProgressHUD(style: .extraLight)

        // Necessary to prevent the use of CoreMotion that's causing the Main Thread Checker to fire on iPhone XS on iOS 12.1.
        // TODO: Retest this after iOS 12.2.
        hud.parallaxMode = .alwaysOff
        
        // Setting label text is causing the same CoreMotion/MainThreadChecker problem.  For now, disable.
        hud.textLabel.text = message
        
        hud.vibrancyEnabled = true
        

        //        hud.textLabel.text = "Loading"
        hud.show(in: self.view)
        
        //SVProgressHUD.show()
//        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
//        hud.areDefaultMotionEffectsEnabled = false
//        hud.mode = MBProgressHUDMode.indeterminate
//        hud.label.text = "Loading";
        return ProgressController(hud: hud)
    }
}

