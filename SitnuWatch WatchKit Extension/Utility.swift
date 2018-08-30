//
//  Utility.swift
//  SitnuWatch WatchKit Extension
//
//  Created by Nils Bergmann on 29.08.18.
//  Copyright © 2018 Nils Bergmann. All rights reserved.
//

import Foundation
import UIKit

func startAndEnd(of date : Date) -> (start : Date, end : Date) {
    var startDate = Date()
    var interval : TimeInterval = 0.0
    let _ = Calendar.current.dateInterval(of: .day, start: &startDate, interval: &interval, for: date)
    let endDate = startDate.addingTimeInterval(interval-1)
    return (start : startDate, end : endDate)
}

extension UIColor {
    convenience init(hexString: String, alpha: CGFloat = 1.0) {
        let hexString: String = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        if (hexString.hasPrefix("#")) {
            scanner.scanLocation = 1
        }
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        let red   = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue  = CGFloat(b) / 255.0
        self.init(red:red, green:green, blue:blue, alpha:alpha)
    }
    func toHexString() -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format:"#%06x", rgb)
    }
}

func getNextFullHour()-> Date {
    var now = Date()
    var nowComponents = DateComponents()
    let calendar = Calendar.current
    nowComponents.year = Calendar.current.component(.year, from: now)
    nowComponents.month = Calendar.current.component(.month, from: now)
    nowComponents.day = Calendar.current.component(.day, from: now)
    nowComponents.hour = Calendar.current.component(.hour, from: now) + 1
    nowComponents.minute = 0
    nowComponents.second = 0
    nowComponents.timeZone = NSTimeZone.local
    now = calendar.date(from: nowComponents)!
    return now as Date
}
