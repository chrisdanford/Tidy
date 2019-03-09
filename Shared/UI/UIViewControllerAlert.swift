//
//  UIViewControllerAlert.swift
//  Tidy iOS
//
//  Created by Chris Danford on 3/7/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import UIKit

extension UIViewController {
    func showSimpleOKAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
