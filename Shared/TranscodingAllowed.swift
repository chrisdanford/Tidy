//
//  TranscodingAllowed.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/28/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import UIKit
import Reachability

public extension Notification.Name {
    public static let transcodingAllowedChanged = Notification.Name("transcodingAllowed")
}

class TranscodingAllowed {
    static let instance = TranscodingAllowed()

    enum Status {
        case allowed
        case deviceCantExportHEVC
        case noWiFi
        case noPower
        case noPowerNoWiFi
        
        var friendlyString: String {
            switch self {
            case .allowed:
                return "allowed"
            case .deviceCantExportHEVC:
                return "'High Efficiency' not supported"
            case .noWiFi:
                return "Paused: connect WiFi"
            case .noPower:
                return "Paused: connect power"
            case .noPowerNoWiFi:
                return "Paused: connect WiFi and power"
            }
        }
    }

    private let queue = DispatchQueue(label: "TranscodingAllowed")
    private var lastStatus = Status.allowed
    private let reachability = Reachability()!
    private let deviceCanExportHEVC = VideoEncodeUtil.deviceCanExportHEVC

    init() {
        // This must be set in order to receive battery-related notifications.
        // https://developer.apple.com/documentation/uikit/uidevice/1620045-isbatterymonitoringenabled
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(batteryStateDidChange), name: UIDevice.batteryStateDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged), name: .reachabilityChanged, object: nil)
        do {
            try reachability.startNotifier()
        } catch {
            print("could not start reachability notifier")
        }
    }

    static func start() {
        // Static members are lazily instantiated.
        let _ = instance
    }
    
    private func didStatusChange() -> Bool {
        var statusChanged: Bool?
        queue.sync {
            let wifi = reachability.connection == .wifi
            
            let power: Bool
            switch UIDevice.current.batteryState {
            case .unplugged:
                power = false
            case .unknown, .charging, .full:
                power = true
            }

            let newStatus: Status
            if !deviceCanExportHEVC {
                newStatus = .deviceCantExportHEVC
            } else if wifi && power {
                newStatus = .allowed
            } else if !power && !wifi {
                newStatus = .noPowerNoWiFi
            } else if !wifi {
                newStatus = .noWiFi
            } else {
                newStatus = .noPower
            }
            statusChanged = lastStatus != newStatus
            lastStatus = newStatus
        }
        return statusChanged!
    }
    
    var status: Status {
        var ret: Status?
        queue.sync {
            ret = lastStatus
        }
        return ret!
    }
 
    private func evaluateAndEmit() {
        assert(Thread.isMainThread)
        
        if didStatusChange() {
//            let vc = UIAlertController(title: "power", message: "\(UIDevice.current.batteryState.rawValue) \(allowed)", preferredStyle: .actionSheet)
//            vc.addAction(.init(title: "cancel", style: .cancel, handler: nil))
//            UIApplication.shared.keyWindow?.rootViewController?.present(vc, animated: false, completion: nil)

            NotificationCenter.default.post(name: .transcodingAllowedChanged, object: nil)
        }
    }

    @objc private func batteryStateDidChange(_ notification: Notification) {
        assert(Thread.isMainThread)
//        let vc = UIAlertController(title: "power", message: "\(UIDevice.current.batteryState.rawValue)", preferredStyle: .actionSheet)
//        vc.addAction(.init(title: "cancel", style: .cancel, handler: nil))
//        UIApplication.shared.keyWindow?.rootViewController?.present(vc, animated: false, completion: nil)

        self.evaluateAndEmit()
    }

    @objc private func reachabilityChanged(_ notification: Notification) {
        assert(Thread.isMainThread)
        self.evaluateAndEmit()
    }
}
