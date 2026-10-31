import Foundation
import HolidayData

var failures = 0
func check(_ cond: Bool, _ name: String) {
    print((cond ? "✅ " : "❌ ") + name)
    if !cond { failures += 1 }
}

var cal = Calendar(identifier: .gregorian)
cal.timeZone = LunarCalendarShanghai.timezone
func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
    return cal.date(from: comps)!
}

// 从包内 Resources 读取（#filePath 相对定位，双构建路径通用）
let mainDir = (#filePath as NSString).deletingLastPathComponent
let jsonURL = URL(fileURLWithPath: mainDir + "/../HolidayData/Resources/holiday-2026.json")
let store = try! HolidayStore(json: Data(contentsOf: jsonURL))

check(store.effect(for: date(2026, 2, 17)) == .restDay(name: "春节"), "2026-02-17 春节休")
check(store.effect(for: date(2026, 2, 14)) == .workday(name: "春节"), "2026-02-14 调休补班")
check(store.effect(for: date(2026, 3, 5)) == nil, "普通日无效果")
check(store.nextHoliday(after: date(2026, 9, 30))?.name == "国庆", "9/30 之后下一假日=国庆")
check(store.nextHoliday(after: date(2026, 10, 31)) == nil, "样例年内无更多假日→nil")
exit(failures == 0 ? 0 : 1)
