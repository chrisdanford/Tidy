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
    
    static func setBadge(count: Int) {
        let center = UNUserNotificationCenter.current()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(forKey: "Elon said:", arguments: nil)
        content.body = NSString.localizedUserNotificationString(forKey: "Hello Tom！Get up, let's play with Jerry!", arguments: nil)
        content.badge = count as NSNumber
        content.categoryIdentifier = "com.SuperSoundGames.localNotification"
        // Deliver the notification in 60 seconds.
        let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: 24 * 60 * 60, repeats: true)
        let request = UNNotificationRequest.init(identifier: "Daily", content: content, trigger: trigger)

        // Schedule the notification.
        center.add(request)
    }
}

