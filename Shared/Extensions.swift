//
//  Extensions.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/18/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import Foundation
import Photos

// https://stackoverflow.com/a/48566887
extension URL {
    var attributes: [FileAttributeKey : Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch let error as NSError {
            NSLog("FileAttribute error: \(error)")
        }
        return nil
    }
    
    var fileSize: UInt64 {
        return attributes?[.size] as? UInt64 ?? UInt64(0)
    }
}

extension FixedWidthInteger {
    var formattedCompactByteString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(self))
    }
    
    var formattedDecimalString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formattedCount = formatter.string(from: Int64(self) as NSNumber)
        return formattedCount!
    }
}

extension CGSize: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.width)
        hasher.combine(self.height)
    }
    static func == (lhs: CGSize, rhs: CGSize) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
}

// MARK: - Date
// https://github.com/NextLevel/NextLevel/blob/62197bd12f73cbec87be0272984d8f459a8c56b2/Sources/NextLevel%2BFoundation.swift
extension Date {
    
    static let dateFormatter: DateFormatter = iso8601DateFormatter()
    fileprivate static func iso8601DateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        return formatter
    }
    
    // http://nshipster.com/nsformatter/
    // http://unicode.org/reports/tr35/tr35-6.html#Date_Format_Patterns
    public func iso8601() -> String {
        return Date.iso8601DateFormatter().string(from: self)
    }
    
}

extension TimeInterval {
    var conciseFriendlyFormattedString: String {
        let duration = self
        
        // https://stackoverflow.com/a/44826036
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional // Use the appropriate positioning for the current locale
        
        // Hacky: https://stackoverflow.com/q/49581717
        if duration >= 3600 {
            formatter.allowedUnits = [.second, .minute, .hour]
        } else {
            formatter.allowedUnits = [.second, .minute]
        }
        
        formatter.zeroFormattingBehavior = [ .pad ] // Pad with zeroes where appropriate for the locale
        
        // Photos app does rounding.  If we don't round here, it takes the floor.
        let roundedDuration = duration.rounded()
        
        return formatter.string(from: roundedDuration)!
    }
}

extension FourCharCode {
    func toString() -> String {
        let n = Int(self)
        var s: String = String(UnicodeScalar((n >> 24) & 255)!)
        s += String(UnicodeScalar((n >> 16) & 255)!)
        s += String(UnicodeScalar((n >> 8) & 255)!)
        s += String(UnicodeScalar(n & 255)!)
        return s.trimmingCharacters(in: .whitespaces)
    }
}

extension UIColor {
    func lighten() -> UIColor {
        
        var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
        
        if self.getRed(&r, green: &g, blue: &b, alpha: &a){
            return UIColor(red: max(r + 0.2, 0.0), green: max(g + 0.2, 0.0), blue: max(b + 0.2, 0.0), alpha: a)
        }
        
        return UIColor()
    }
}

extension NSAttributedString {
    static func join(_ pieces: [NSAttributedString]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for piece in pieces {
            result.append(piece)
        }
        return result
    }
    
    static func + (lhs: NSAttributedString, rhs: NSAttributedString) -> NSAttributedString {
        return join([lhs, rhs])
    }
    
    convenience init(string: String, color: UIColor? = nil, font: UIFont? = nil, url: URL? = nil) {
        var attrs = [NSAttributedString.Key: Any]()
        if color != nil {
            attrs[NSAttributedString.Key.foregroundColor] = color
        }
        if font != nil {
            attrs[NSAttributedString.Key.font] = font
        }
        if url != nil {
            attrs[NSAttributedString.Key.link] = url
        }
        self.init(string: string, attributes: attrs)
    }
}

extension UIColor {
    var components: (CGFloat, CGFloat, CGFloat, CGFloat) {
        var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
    static func blend(_ color1: UIColor, _ color2: UIColor) -> UIColor {
        let (r1, g1, b1, a1) = color1.components
        let (r2, g2, b2, a2) = color2.components
        return UIColor.init(red: (r1+r2)/2, green: (g1+g2)/2, blue: (b1+b2)/2, alpha: (a1+a2)/2)
    }
}

extension ArraySlice where Element : Any {
    public func poppingFirst(maxLength: Int) -> (ArraySlice<Element>, ArraySlice<Element>) {
        let prefix = self.prefix(maxLength)
        let suffix = self.suffix(from: prefix.count)
        return (prefix, suffix)
    }
}
