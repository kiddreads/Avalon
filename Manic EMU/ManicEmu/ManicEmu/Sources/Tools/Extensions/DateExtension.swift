//
//  DateExtension.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

extension Date {
    func timeAgo() -> String? {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.second, .minute, .hour, .day, .weekOfYear, .month, .year], from: self, to: now)
        
        if let minutes = components.minute, minutes < 60 {
            return R.string.localizable.timeAgoMinuteFormat(minutes <= 0 ? 1 : minutes)
        }
        
        if let hours = components.hour, hours < 24 {
            return R.string.localizable.timeAgoHourFormat(hours)
        }
        
        if let days = components.day, days < 7 {
            return R.string.localizable.timeAgoDayFormat(days)
        }
        
        if let weeks = components.weekOfYear, weeks < 5 {
            return R.string.localizable.timeAgoWeekFormat(weeks)
        }
        
        if let months = components.month, months < 12 {
            return R.string.localizable.timeAgoMonthFormat(months)
        }
        
        if let years = components.year, years > 0 {
            return R.string.localizable.timeAgoYearFormat(years)
        }
        
        return nil
    }
    
    static func timeDuration(milliseconds: Int) -> String {
        let minutes = milliseconds / 60000
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            if remainingMinutes == 0 {
                return R.string.localizable.timeDurationHourFormat(hours)
            }
            return R.string.localizable.timeDurationHourAndMinuteFormat(hours, remainingMinutes)
        } else {
            return R.string.localizable.timeDurationMinuteFormat(minutes + 1)
        }
    }
    
    var timeIntervalSince1970ms: Double {
        self.timeIntervalSince1970 * 1000
    }
}
