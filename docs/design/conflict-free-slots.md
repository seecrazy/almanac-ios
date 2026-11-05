# 冲突检测与空闲时段 v1

状态：代码已接入；GUI / 真机人工验收待完成  
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md) · [ADR-007](../architecture/adr/ADR-007-cross-platform.md)  
关联设计：[事件创建](event-creation.md) · [日 / 周 / 年 / 议程视图](views-navigation.md)

## 1. 目标

- 在纯逻辑包内识别一段时间窗口内重叠的日程，并给出冲突组。
- 在日视图 / 日详情给出当日空闲时段，帮助用户选择新日程时间。
- 新建日程时提前提示所选时间是否与可见日程冲突。

## 2. 非目标 v1

- 不判断会议室、参与人、地理位置或通勤时间。
- 不修改已有事件；只提示冲突。
- 不读取日历邀请状态和 RSVP。
- 不做跨天自由排程优化，也不建议具体会议时间。

## 3. 纯逻辑模型

```swift
public struct AnalysisEvent: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
}

public struct AnalysisConflictGroup: Identifiable, Hashable {
    public let events: [AnalysisEvent]
    public let interval: DateInterval
}

public struct AnalysisFreeSlot: Identifiable, Hashable {
    public let startDate: Date
    public let endDate: Date
}
```

API：

```swift
CalendarConflictAnalyzer.conflictGroups(
    in: [AnalysisEvent],
    within: DateInterval? = nil
) -> [AnalysisConflictGroup]

CalendarConflictAnalyzer.freeSlots(
    on: Date,
    events: [AnalysisEvent],
    calendar: Calendar = .current,
    minimumDuration: TimeInterval = 30 * 60,
    maximumCount: Int = 6
) -> [AnalysisFreeSlot]
```

## 4. 判定规则

1. `end <= start` 的无效事件直接忽略。
2. 两个事件仅在时间区间相交且长度大于 0 时冲突；端点相接不冲突。
3. 重叠关系形成连通组：A-B 重叠、B-C 重叠时，A/B/C 是一个冲突组。
4. 全天事件占用所在本地日全天；与当天其他事件冲突，也会清空当天空闲时段。
5. `within` 提供时，先裁剪到查询窗口，再计算冲突。
6. 空闲时段按本地日历的天起止计算；已占用区间合并后，只输出时长不小于 `minimumDuration` 的空隙。
7. 输入已过滤的可见日程；`CalendarAnalysis` 不读取 EventKit，也不理解日历筛选状态。

## 5. 展示规则

| 位置 | 行为 |
|---|---|
| 新建日程 | 开始 / 结束 / 全天变化时实时检测；有冲突时显示冲突时间和事件标题 |
| 日详情 | 在日程列表前显示冲突摘要；无冲突不显示 |
| 日视图 | 在日程列表前显示当日空闲时段，最多 6 段，每段至少 30 分钟 |
| 权限拒绝 | 不显示空时段；保留现有“无法读取系统日历”反馈 |

冲突文案示例：`与「设计评审」冲突 14:00–15:00`。空闲文案示例：`08:00 – 10:00 · 2 小时`。

## 6. 边界

| 场景 | 行为 |
|---|---|
| 结束时间等于开始时间 | 忽略该事件 |
| 事件端点相接 | 不冲突 |
| 全天事件 | 当天无空闲时段 |
| 跨天事件 | 只裁剪到当前查询日 / 窗口 |
| 超过 20 个冲突组 | 最多返回 20 组，避免列表失控 |
| 空闲时段超过 6 个 | 最多返回 6 个 |
| 最小时长小于 1 分钟 | 使用 1 分钟 |

## 7. 验收清单

- [x] `CalendarAnalysis` 纯逻辑包无 EventKit / SwiftUI / UI 依赖。
- [x] 无效事件被忽略。
- [x] 两个重叠事件形成冲突组，端点相接不冲突。
- [x] 三个链式重叠事件形成一个冲突组。
- [x] 全天事件与普通事件冲突并清空当天空闲时段。
- [x] 空闲时段合并相邻日程、裁剪跨天事件、遵守最小时长和数量上限。
- [x] 新建日程实时显示冲突。
- [x] 日详情显示冲突摘要，日视图显示空闲时段。
- [x] SwiftPM XCTest 全绿。
- [x] generic iOS Simulator build 全绿。

验证记录：2026-11-05，`CalendarAnalysis` 7 项 XCTest、全仓库 82 项 SwiftPM XCTest 与 Xcode 27.2 generic iOS Simulator build 全绿；GUI / 真机人工验收待完成。
