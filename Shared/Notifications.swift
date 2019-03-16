//
//  Notifications.swift
//  Tidy iOS
//
//  Created by Chris Danford on 3/4/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import UserNotifications
import UIKit

class Notifications {

    static func ensureAuthorized() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.badge, .alert]) { (granted, error) in
        }
    }
    
    static func setBadgeAndScheduleNotifications(state: AppState) {
        UIApplication.shared.applicationIconBadgeNumber = state.badgeCount

        let center = UNUserNotificationCenter.current()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let notificationLines = state.notificationLines
        if notificationLines.count > 0 {
            let body = notificationLines.map({ return "➡ " + $0 }).joined(separator: "\n")

            let content = UNMutableNotificationContent()
            content.title = NSString.localizedUserNotificationString(forKey: "You can recover storage space", arguments: nil)
            content.body = body

            
            struct RepeatingTimerSpecs {
                var timeInterval: TimeInterval
                var repeats: Bool
                var identifier: String
            }
            // Fire one reminder immediately, then again every 24h.
            let specs = [
                RepeatingTimerSpecs(timeInterval: 60, repeats: false, identifier: "Quick"),
                RepeatingTimerSpecs(timeInterval: 24 * 60 * 60, repeats: true, identifier: "Slow"),
            ]
            for spec in specs {
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: spec.timeInterval, repeats: spec.repeats)
                let request = UNNotificationRequest(identifier: spec.identifier, content: content, trigger: trigger)

                // Schedule the notification.
                center.add(request)
            }
        }
    }
}

