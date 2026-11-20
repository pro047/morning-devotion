//
//  DevotionDateMath.swift
//  MorningDevotion
//

import Foundation

extension DevotionDate {
    /// Calendar-day arithmetic in the Gregorian calendar (computed in UTC internally; no DST effects).
    nonisolated func addingDays(_ days: Int) -> DevotionDate {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        guard let base = utc.date(from: components),
              let shifted = utc.date(byAdding: .day, value: days, to: base)
        else { return self }
        let parts = utc.dateComponents([.year, .month, .day], from: shifted)
        return DevotionDate(year: parts.year ?? year, month: parts.month ?? month, day: parts.day ?? day)
    }

    /// Local calendar day of `instant` in `calendar` (uses calendar.timeZone).
    nonisolated init(localDayOf instant: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }
}
