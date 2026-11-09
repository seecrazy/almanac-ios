import Foundation
import HolidayData

/// 进程级缓存的中文格式化器。DateFormatter 创建昂贵，禁止在 body 内新建。
enum AppFormatters {
    static let hhmm = makeFormatter("HH:mm")
    static let monthDay = makeFormatter("M月d日")
    static let monthDayTime = makeFormatter("M月d日 HH:mm")
    static let monthDayWeekday = makeFormatter("M月d日 EEEE")
    static let monthOnly = makeFormatter("M月")
    static let yearTitle = makeFormatter("yyyy年")
    static let anchorTitle = makeFormatter("yyyy年M月d日")
    static let fullDate = makeFormatter("yyyy年M月d日")
    static let fullDateTime = makeFormatter("yyyy年M月d日 HH:mm")
    static let fullDateWeekday = makeFormatter("yyyy年M月d日 EEEE")

    /// 闹钟通知标识用的稳定日期串（上海时区、POSIX locale，避免随系统语言变化）。
    static let alarmIdentifierDate: DateFormatter = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = LunarCalendarShanghai.timezone
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = format
        return formatter
    }
}
