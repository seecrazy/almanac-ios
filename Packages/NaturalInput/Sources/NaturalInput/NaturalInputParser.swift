import Foundation

public struct NaturalRecurrence: Hashable, Sendable {
    public let mode: NaturalRecurrenceMode

    public init(mode: NaturalRecurrenceMode) {
        self.mode = mode
    }
}

public struct QuickEventDraft: Hashable, Sendable {
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let location: String?
    public let notes: String?
    public let recurrence: NaturalRecurrence

    public init(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        notes: String?,
        recurrence: NaturalRecurrence
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.recurrence = recurrence
    }
}

public struct NaturalParseResult: Equatable, Sendable {
    public let draft: QuickEventDraft
    public let warnings: [String]
}

public struct NaturalInputParser: Sendable {
    private let rules: NaturalInputRules

    public init(rules: NaturalInputRules = .bundled()) {
        self.rules = rules
    }

    public func parse(
        _ input: String,
        reference: Date,
        calendar: Calendar = .current
    ) -> NaturalParseResult {
        var working = input
        var warnings: [String] = []

        var isAllDay = false
        for marker in sortedLongest(rules.allDayMarkers) {
            if remove(marker, from: &working) {
                isAllDay = true
                break
            }
        }

        let location = extractMarkerValue(rules.locationMarker, from: &working)
        let notes = extractMarkerValue(rules.notesMarker, from: &working)
        let recurrence = parseRecurrence(from: &working)

        let dateHit = parseDate(
            from: &working,
            reference: reference,
            calendar: calendar,
            allowBareWeekday: recurrence.isImmediatelyFollowedByWeekday
        )
        if dateHit == nil {
            warnings.append("未识别日期，已按今天处理")
        }
        let dayStart = dateHit?.date ?? calendar.startOfDay(for: reference)

        var startDate = dayStart
        var endDate = dayStart
        var crossedMidnight = false

        if isAllDay {
            startDate = calendar.startOfDay(for: dayStart)
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
            if containsTimeExpression(working) {
                warnings.append("已识别全天，忽略时间")
                working = removeTimeExpressions(from: working)
            }
        } else {
            if let range = parseTimeRange(from: &working) {
                startDate = makeDate(day: dayStart, time: range.start, calendar: calendar)
                if range.end.hour < range.start.hour
                    || (range.end.hour == range.start.hour && range.end.minute <= range.start.minute) {
                    endDate = makeDate(day: dayStart, time: range.end, calendar: calendar, addOneDay: true)
                    crossedMidnight = true
                } else {
                    endDate = makeDate(day: dayStart, time: range.end, calendar: calendar)
                }
            } else if let start = parseSingleTime(from: &working) {
                startDate = makeDate(day: dayStart, time: start, calendar: calendar)

                if let duration = parseDuration(from: &working) {
                    endDate = startDate.addingTimeInterval(duration)
                } else {
                    endDate = calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
                }
            } else {
                startDate = makeDate(day: dayStart, time: TimeValue(hour: 9, minute: 0), calendar: calendar)
                endDate = makeDate(day: dayStart, time: TimeValue(hour: 10, minute: 0), calendar: calendar)
                warnings.append("未识别时间，已按 09:00–10:00 处理")
            }
        }

        if crossedMidnight {
            warnings.append("结束时间早于开始时间，已按跨天处理")
        }

        let recurrenceMode = recurrence.mode

        let cleanedTitle = cleanTitle(working)
        let title = cleanedTitle.isEmpty ? "新日程" : cleanedTitle
        if cleanedTitle.isEmpty {
            warnings.append("未识别标题，请补充标题")
        }

        let draft = QuickEventDraft(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            notes: notes,
            recurrence: NaturalRecurrence(mode: recurrenceMode)
        )

        return NaturalParseResult(draft: draft, warnings: warnings)
    }

    // MARK: - Text helpers

    private func sortedLongest(_ values: [String]) -> [String] {
        values.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs < rhs
        }
    }

    private func remove(_ token: String, from text: inout String) -> Bool {
        guard !token.isEmpty,
              let range = text.range(of: token, options: .literal)
        else { return false }
        text.replaceSubrange(range, with: String(repeating: " ", count: token.count))
        return true
    }

    private func firstRegularExpression(_ pattern: String, in text: String) -> (NSTextCheckingResult, NSString)? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let nsText = text as NSString
        let matches = regex?.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length))
        guard let match = matches else { return nil }
        return (match, nsText)
    }

    private func consume(_ result: NSTextCheckingResult, in nsText: NSString, text: inout String) {
        text = nsText.replacingCharacters(
            in: result.range,
            with: String(repeating: " ", count: result.range.length)
        )
    }

    private func group(_ result: NSTextCheckingResult, _ index: Int, in nsText: NSString) -> String? {
        guard index < result.numberOfRanges else { return nil }
        let range = result.range(at: index)
        guard range.location != NSNotFound, range.location + range.length <= nsText.length else { return nil }
        let value = nsText.substring(with: range)
        return value.isEmpty ? nil : value
    }

    private func extractMarkerValue(_ marker: String, from text: inout String) -> String? {
        let escapedMarker = NSRegularExpression.escapedPattern(for: marker)
        let pattern = "\(escapedMarker)([^\\s，。；,.;:：！？!?#@]+)"
        guard let (match, nsText) = firstRegularExpression(pattern, in: text),
              let value = group(match, 1, in: nsText)
        else { return nil }
        consume(match, in: nsText, text: &text)
        return value
    }

    private func cleanTitle(_ text: String) -> String {
        let collapsed = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "，。；,.;:：、|-—"))
    }

    // MARK: - Recurrence

    private struct RecurrenceHit {
        let mode: NaturalRecurrenceMode
        let isImmediatelyFollowedByWeekday: Bool
    }

    private func parseRecurrence(from text: inout String) -> RecurrenceHit {
        let candidates = rules.recurrenceRules.flatMap { rule in
            rule.patterns.map { ($0, rule.mode) }
        }.sorted { lhs, rhs in
            if lhs.0.count != rhs.0.count { return lhs.0.count > rhs.0.count }
            return lhs.0 < rhs.0
        }

        for (pattern, mode) in candidates {
            guard let range = text.range(of: pattern, options: .literal) else { continue }
            let following = String(text[range.upperBound...])
            var isImmediatelyFollowedByWeekday = false
            if let first = following.first,
               rules.weekdayAliases.keys.contains(String(first)) {
                let nextIndex = following.index(after: following.startIndex)
                let characterAfterAlias = nextIndex < following.endIndex ? following[nextIndex] : " "
                isImmediatelyFollowedByWeekday = !characterAfterAlias.isLetter
            }
            text.replaceSubrange(range, with: String(repeating: " ", count: pattern.count))
            return RecurrenceHit(
                mode: mode,
                isImmediatelyFollowedByWeekday: isImmediatelyFollowedByWeekday
            )
        }
        return RecurrenceHit(mode: .none, isImmediatelyFollowedByWeekday: false)
    }

    // MARK: - Dates

    private struct DateHit {
        let date: Date
    }

    private func parseDate(
        from text: inout String,
        reference: Date,
        calendar: Calendar,
        allowBareWeekday: Bool = false
    ) -> DateHit? {
        let year = calendar.component(.year, from: reference)

        let isoPattern = #"(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})"#
        if let (match, nsText) = firstRegularExpression(isoPattern, in: text),
           let yearText = group(match, 1, in: nsText),
           let monthText = group(match, 2, in: nsText),
           let dayText = group(match, 3, in: nsText),
           let date = makeDate(
            year: Int(yearText),
            month: Int(monthText),
            day: Int(dayText),
            calendar: calendar
           ) {
            consume(match, in: nsText, text: &text)
            return DateHit(date: date)
        }

        let chineseYearPattern = #"(20\d{2})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]"#
        if let (match, nsText) = firstRegularExpression(chineseYearPattern, in: text),
           let yearText = group(match, 1, in: nsText),
           let monthText = group(match, 2, in: nsText),
           let dayText = group(match, 3, in: nsText),
           let date = makeDate(
            year: Int(yearText),
            month: Int(monthText),
            day: Int(dayText),
            calendar: calendar
           ) {
            consume(match, in: nsText, text: &text)
            return DateHit(date: date)
        }

        let chinesePattern = #"(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]"#
        if let (match, nsText) = firstRegularExpression(chinesePattern, in: text),
           let monthText = group(match, 1, in: nsText),
           let dayText = group(match, 2, in: nsText),
           let date = makeDate(year: year, month: Int(monthText), day: Int(dayText), calendar: calendar) {
            consume(match, in: nsText, text: &text)
            return DateHit(date: date)
        }

        let slashPattern = #"(?<!\d)(\d{1,2})/(\d{1,2})(?!\d)"#
        if let (match, nsText) = firstRegularExpression(slashPattern, in: text),
           let monthText = group(match, 1, in: nsText),
           let dayText = group(match, 2, in: nsText),
           let date = makeDate(year: year, month: Int(monthText), day: Int(dayText), calendar: calendar) {
            consume(match, in: nsText, text: &text)
            return DateHit(date: date)
        }

        for (word, offset) in sortedLongest(Array(rules.relativeDates.keys))
            .compactMap({ key -> (String, Int)? in rules.relativeDates[key].map { (key, $0) } })
            .sorted(by: { lhs, rhs in
                if lhs.0.count != rhs.0.count { return lhs.0.count > rhs.0.count }
                return lhs.0 < rhs.0
            }) {
            if remove(word, from: &text),
               let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: reference)) {
                return DateHit(date: date)
            }
        }

        if let weekday = parseWeekday(
            from: &text,
            reference: reference,
            calendar: calendar,
            allowBareAlias: allowBareWeekday
        ) {
            return DateHit(date: weekday)
        }

        return nil
    }

    private func parseWeekday(
        from text: inout String,
        reference: Date,
        calendar: Calendar,
        allowBareAlias: Bool
    ) -> Date? {
        let aliases = rules.weekdayAliases
            .sorted { lhs, rhs in
                if lhs.key.count != rhs.key.count { return lhs.key.count > rhs.key.count }
                return lhs.key < rhs.key
            }
            .compactMap { item -> String? in
                let value = item.value
                guard (1...7).contains(value) else { return nil }
                return NSRegularExpression.escapedPattern(for: item.key)
            }
            .joined(separator: "|")

        let nextPrefixes = rules.nextWeekPrefixes
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        let prefixes = rules.weekdayPrefixes
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")

        let weekdayPrefixPattern = allowBareAlias ? "(?:\(prefixes))?" : "(?:\(prefixes))"
        let pattern = "((?:\(nextPrefixes))\\s*|\(weekdayPrefixPattern))\\s*(\(aliases))"
        guard let (match, nsText) = firstRegularExpression(pattern, in: text) else {
            return nil
        }
        guard let alias = group(match, 2, in: nsText) else {
            return nil
        }
        guard let weekday = rules.weekdayAliases[alias] else { return nil }

        let matchedText = nsText.substring(with: match.range)
        let isNextWeek = rules.nextWeekPrefixes.contains { matchedText.contains($0) }
        consume(match, in: nsText, text: &text)

        if isNextWeek {
            return nextWeekDate(weekday: weekday, after: reference, calendar: calendar)
        }
        return nearestWeekday(weekday: weekday, after: reference, calendar: calendar)
    }

    private func makeDate(year: Int?, month: Int?, day: Int?, calendar: Calendar) -> Date? {
        guard let year, let month, let day else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    private func nearestWeekday(weekday: Int, after date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        let current = calendar.component(.weekday, from: start)
        var delta = (weekday - current + 7) % 7
        if delta == 0 { delta = 7 }
        return calendar.date(byAdding: .day, value: delta, to: start) ?? start
    }

    private func nextWeekDate(weekday: Int, after date: Date, calendar: Calendar) -> Date {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let weekStart = mondayCalendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? mondayCalendar.startOfDay(for: date)
        let nextMonday = mondayCalendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        // Calendar weekday: Sunday = 1. Convert it to days after Monday.
        let daysAfterMonday = (weekday == 1) ? 6 : weekday - 2
        return mondayCalendar.date(byAdding: .day, value: daysAfterMonday, to: nextMonday) ?? nextMonday
    }

    // MARK: - Time

    private struct TimeValue: Equatable {
        let hour: Int
        let minute: Int
    }

    private struct TimeRange {
        let start: TimeValue
        let end: TimeValue
    }

    private var meridiemPattern: String { "(凌晨|清晨|早上|上午|中午|下午|傍晚|晚上)?" }
    private var timeBodyPattern: String {
        #"(\d{1,2})(?:\s*(?:点|时))?(?:\s*(?:(?:[:：]\s*(\d{1,2})|(\d{1,2})|(半))\s*分?))?"#
    }

    private func containsTimeExpression(_ text: String) -> Bool {
        inspectTimeRange(text) != nil || inspectSingleTime(text) != nil
    }

    private func removeTimeExpressions(from text: String) -> String {
        var result = text
        let rangePattern = #"^\s*"# + meridiemPattern + #"\s*"# + timeBodyPattern + #"\s*(?:到|至|~|～|-|—|–)\s*"# + meridiemPattern + #"\s*"# + timeBodyPattern
        if let (match, nsText) = firstRegularExpression(rangePattern, in: result) {
            consume(match, in: nsText, text: &result)
        }
        let singlePattern = #"^\s*"# + meridiemPattern + #"\s*"# + timeBodyPattern
        while let (match, nsText) = firstRegularExpression(singlePattern, in: result),
              hasMeaningfulTime(nsText.substring(with: match.range)) {
            consume(match, in: nsText, text: &result)
        }
        return result
    }

    private func parseTimeRange(from text: inout String) -> TimeRange? {
        let range = inspectTimeRange(text)
        if let range,
           let (match, nsText) = firstRegularExpression(rangePatternForMatch, in: text) {
            consume(match, in: nsText, text: &text)
            return range
        }
        return nil
    }

    private var rangePatternForMatch: String {
        meridiemPattern + #"\s*"# + timeBodyPattern + #"\s*(?:到|至|~|～|-|—|–)\s*"# + meridiemPattern + #"\s*"# + timeBodyPattern
    }

    private func inspectTimeRange(_ text: String) -> TimeRange? {
        guard let (match, nsText) = firstRegularExpression(rangePatternForMatch, in: text) else { return nil }

        let startHourText = group(match, 2, in: nsText)
        let startMinuteText = group(match, 3, in: nsText)
        let startNoColonMinuteText = group(match, 4, in: nsText)
        let startHalfText = group(match, 5, in: nsText)
        let endMeridiem = group(match, 6, in: nsText)
        let endHourText = group(match, 7, in: nsText)
        let endMinuteText = group(match, 8, in: nsText)
        let endNoColonMinuteText = group(match, 9, in: nsText)
        let endHalfText = group(match, 10, in: nsText)
        let startMeridiem = group(match, 1, in: nsText)

        guard let startHourText, let endHourText,
              let start = normalizeTime(
                hourText: startHourText,
                minuteText: startMinuteText ?? startNoColonMinuteText,
                halfText: startHalfText,
                meridiem: group(match, 1, in: nsText)
              ),
              let end = normalizeTime(
                hourText: endHourText,
                minuteText: endMinuteText ?? endNoColonMinuteText,
                halfText: endHalfText,
                meridiem: endMeridiem ?? startMeridiem
              )
        else { return nil }

        return TimeRange(start: start, end: end)
    }

    private func parseSingleTime(from text: inout String) -> TimeValue? {
        let pattern = #"^\s*"# + meridiemPattern + #"\s*"# + timeBodyPattern
        guard let (match, nsText) = firstRegularExpression(pattern, in: text),
              hasMeaningfulTime(nsText.substring(with: match.range)),
              let hourText = group(match, 2, in: nsText),
              let value = normalizeTime(
                hourText: hourText,
                minuteText: group(match, 3, in: nsText) ?? group(match, 4, in: nsText),
                halfText: group(match, 5, in: nsText),
                meridiem: group(match, 1, in: nsText)
              )
        else { return nil }
        consume(match, in: nsText, text: &text)
        return value
    }

    private func inspectSingleTime(_ text: String) -> TimeValue? {
        let pattern = #"^\s*"# + meridiemPattern + #"\s*"# + timeBodyPattern
        guard let (match, nsText) = firstRegularExpression(pattern, in: text),
              hasMeaningfulTime(nsText.substring(with: match.range)),
              let hourText = group(match, 2, in: nsText),
              let value = normalizeTime(
                hourText: hourText,
                minuteText: group(match, 3, in: nsText) ?? group(match, 4, in: nsText),
                halfText: group(match, 5, in: nsText),
                meridiem: group(match, 1, in: nsText)
              )
        else { return nil }
        return value
    }

    private func hasMeaningfulTime(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains(":") || lowered.contains("：") || lowered.contains("点")
            || lowered.contains("时") || lowered.contains("半")
            || ["凌晨", "清晨", "早上", "上午", "中午", "下午", "傍晚", "晚上"].contains { lowered.contains($0) }
    }

    private func parseDuration(from text: inout String) -> TimeInterval? {
        let hoursPattern = #"(\d{1,3}(?:\.\d{1,2})?)\s*(?:个)?(?:小时|钟头)(?:\s*(半|\d{1,2})\s*分?)?"#
        if let (match, nsText) = firstRegularExpression(hoursPattern, in: text),
           let valueText = group(match, 1, in: nsText),
           let hours = Double(valueText) {
            var seconds = hours * 3600
            if let halfText = group(match, 2, in: nsText) {
                if halfText == "半" {
                    seconds += 1800
                } else if let minutes = Double(halfText) {
                    seconds += minutes * 60
                }
            }
            consume(match, in: nsText, text: &text)
            return seconds
        }

        let minutesPattern = #"(\d{1,4})\s*分钟"#
        if let (match, nsText) = firstRegularExpression(minutesPattern, in: text),
           let valueText = group(match, 1, in: nsText),
           let minutes = Double(valueText) {
            consume(match, in: nsText, text: &text)
            return minutes * 60
        }
        return nil
    }

    private func normalizeTime(
        hourText: String,
        minuteText: String?,
        halfText: String?,
        meridiem: String?
    ) -> TimeValue? {
        guard var hour = Int(hourText), hour >= 0, hour <= 23 else { return nil }
        var minute = 0
        if let minuteText, let parsed = Int(minuteText), parsed >= 0, parsed <= 59 {
            minute = parsed
        } else if halfText == "半" {
            minute = 30
        } else if let halfText, let parsed = Int(halfText), parsed >= 0, parsed <= 59 {
            minute = parsed
        }

        switch meridiem {
        case "凌晨":
            if hour == 12 { hour = 0 }
        case "清晨", "早上", "上午":
            if hour == 12 { hour = 0 }
        case "中午":
            if hour <= 2 { hour += 12 }
        case "下午", "傍晚", "晚上":
            if hour <= 11 { hour += 12 }
            else if hour == 12 { hour = 12 }
        default:
            break
        }

        return TimeValue(hour: hour, minute: minute)
    }

    private func makeDate(day: Date, time: TimeValue, calendar: Calendar, addOneDay: Bool = false) -> Date {
        var base = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day) ?? day
        if addOneDay {
            base = calendar.date(byAdding: .day, value: 1, to: base) ?? base
        }
        return base
    }
}
