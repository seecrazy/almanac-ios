# 日程小组件 v1（桌面 + 锁屏）

状态：已实现（2026-11-09）。关联：[里程碑提醒与小组件](milestone-reminders-widgets.md)、[性能优化](performance-optimizations.md)。

## 目标与非目标

目标：

1. 桌面 `systemSmall`（今天概览：日期 + 农历 + 日程数 + 最近一条）与 `systemMedium`（今天日程列表，最多 4 条）。
2. 锁屏 `accessoryRectangular`（下一条日程标题与时间）与 `accessoryInline`（"下一条 · 标题 HH:mm"）。
3. 数据链路复用里程碑 Widget 的 App Group 快照模式；快照覆盖"今天"，随 App 数据变化整体重写。

非目标：

- 不做交互式 Widget（勾选 / 按钮）与 deep link 跳转指定日期（后续配合 URL scheme 一并做）；
- 不做多天 / 周视图 Widget；
- Widget 内不做农历宜忌面板（锁屏保持极简）。

## 数据 / 状态模型

`MilestoneKit` 新增（与里程碑快照同一 App Group `group.com.yili.almanac.shared`）：

```swift
ScheduleWidgetEventItem { id, title, startDate, endDate, isAllDay, location?, calendarTitle, colorRGBA? }
ScheduleWidgetSnapshot  { version=1, generatedAt, day(当天零点), events(≤6，全天在前，按开始时间升序) }
ScheduleWidgetSnapshotStorage { fileName = "schedule-widget-snapshot.json" }
ScheduleWidgetSnapshotBuilder.make(items:, for day:, generatedAt:)
```

App 侧写入时机（`EventStoreService` 扩展 `syncScheduleWidget()`）：

1. `loadEvents` 完成后（事件数据变化的统一收口）；
2. `scenePhase == .active`（AlmanacApp 已有钩子）。

写入后 `WidgetCenter.shared.reloadAllTimelines()`；快照仅取"今天"，跨零点由 Widget 端按天刷新策略兜底。

Widget 端 `ScheduleWidgetProvider`：

- timeline：单 entry（now），刷新点取 min(今天结束, 下一个事件开始/结束 + 1min, 15 分钟)，`policy: .after`；
- 无快照 / 空日程 / 未授权各有占位文案。

## 用户入口与交互

- 添加入口：系统小组件库新增「宜历日程」；
- 配色：桌面 Widget 沿用纸感底色 + 系统深浅色自适应文字；锁屏 accessory 使用系统渲染层级。

## 边界与错误状态

- 快照缺失（App 从未启动 / 无 App Group）→「打开宜历更新数据」；
- 今天无日程 →「今天暂无日程」+ 日期头；
- 全天事件与时刻事件混排：全天置顶；
- 标题过长 `lineLimit(1)` + `minimumScaleFactor`。

## 验收清单

- [x] MilestoneKit 快照模型 + Builder XCTest（排序、全天优先、6 条上限、跨日裁剪）
- [x] 桌面 small / medium 与锁屏 rectangular / inline 四族布局
- [x] 空态 / 缺快照态文案
- [x] EventStoreService 写入 + WidgetCenter 刷新接入
- [x] generic iOS Simulator build 通过
