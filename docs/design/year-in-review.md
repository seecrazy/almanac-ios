# 年度回顾 v1

状态：已实现（2026-11-10）。关联：[视图矩阵](views-navigation.md)、[日记](diary.md)。

## 目标与非目标

目标：以本地数据生成某一年度的日程统计回顾——日程总数 / 总时长 / 最忙月份与星期 / 最长日程 / 月度分布 / 最常用日历 / 里程碑达成——支持一键分享文本摘要。所有统计在设备本地完成。

非目标：

- v1 不含日记心情曲线（日记密文需在日记面板内统计，单独设计）；
- 不生成图片卡片（文本摘要先行，分享卡片后续）；
- 不做跨年对比。

## 数据 / 状态模型

`CalendarAnalysis` 新增纯逻辑：

- 输入 `YearReportEvent { id, title, calendarTitle, startDate, endDate, isAllDay }`（App 侧由 `CalendarEvent` 映射）+ 年份 + 里程碑摘要；
- 输出 `YearReport { year, timedEventCount, allDayEventCount, totalHours, longestEvent(title, hours), busiestMonth(1–12, count), busiestWeekday(名称, count), monthCounts[12], topCalendar(title, count), weekendEventCount, upcomingMilestones, pastMilestones }`；
- 全天事件计次不计时长；跨年事件按当年区间裁剪时长。

## 用户入口与交互

设置页新增「年度回顾」入口 → sheet：年份选择（近三年）→ 自动加载该年日程 → 统计卡片纵向滚动 → 「分享文字摘要」走系统分享面板（复用 ActivityShareSheet）。

## 边界与错误状态

- 日历未授权 / 该年无日程：显示空态与授权入口；
- 加载期间 ProgressView；重复进入按所选年份重新拉取。

## 验收清单

- [x] CalendarAnalysis XCTest：总数 / 时长裁剪 / 最忙月星期 / 最长事件 / 最常用日历 / 空输入
- [x] 设置页入口 + 年份切换 + 统计卡片 + 文本分享
- [x] build + App 测试通过
