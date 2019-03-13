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
        center.requestAuthorization(options: [.badge, /*.alert, .sound*/]) { (granted, error) in
        }
    }
    
    static func setBadgeAndScheduleNotifications(state: AppState) {
        let badgeCount = state.badgeCount
        UIApplication.shared.applicationIconBadgeNumber = state.badgeCount

        let center = UNUserNotificationCenter.current()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        if badgeCount > 0 {
            let body = state.notificationLines.map({ return "➡ " + $0 }).joined(separator: "\n")

            let content = UNMutableNotificationContent()
            content.title = NSString.localizedUserNotificationString(forKey: "You can recover storage space", arguments: nil)
            content.body = body
            //content.badge = count as NSNumber

            let seconds: TimeInterval = 60 // 24 * 60 * 60
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: true)
            let request = UNNotificationRequest(identifier: "Daily", content: content, trigger: trigger)

            // Schedule the notification.
            center.add(request)
        }
    }
}

