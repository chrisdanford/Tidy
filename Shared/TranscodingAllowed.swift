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
    static let transcodingAllowedChanged = Notification.Name("transcodingAllowed")
}

class TranscodingAllowed {
    static let instance = TranscodingAllowed()

    enum Status {
        case allowed
        case deviceCantExportHEVC
        case noWiFi
        case lowPowerMode
        case lowPowerModeNoWiFi
        
        var friendlyString: String {
            switch self {
            case .allowed:
                return "allowed"
            case .deviceCantExportHEVC:
                return "'High Efficiency' not supported"
            case .noWiFi:
                return "Paused: connect WiFi"
            case .lowPowerMode:
                return "Paused: connect power"
            case .lowPowerModeNoWiFi:
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
            
            let lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

            let newStatus: Status
            if !deviceCanExportHEVC {
                newStatus = .deviceCantExportHEVC
            } else if !lowPowerMode && wifi {
                newStatus = .allowed
            } else if lowPowerMode && !wifi {
                newStatus = .lowPowerModeNoWiFi
            } else if !wifi {
                newStatus = .noWiFi
            } else {
                newStatus = .lowPowerMode
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
            NotificationCenter.default.post(name: .transcodingAllowedChanged, object: nil)
        }
    }

    @objc private func batteryStateDidChange(_ notification: Notification) {
        assert(Thread.isMainThread)
        self.evaluateAndEmit()
    }

    @objc private func reachabilityChanged(_ notification: Notification) {
        assert(Thread.isMainThread)
        self.evaluateAndEmit()
    }
}
