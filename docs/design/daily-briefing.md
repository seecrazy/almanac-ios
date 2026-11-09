# 每日简报 v1

状态：已实现（2026-11-09）。关联：[通知配额](notification-budget.md)、[黄历面板](almanac-panel.md)、[二十四节气](solar-terms.md)、[农历节日](lunar-festivals.md)。

## 目标与非目标

目标：每天固定时间一条本地通知，内容 = 公历日期星期 + 农历 + 干支年 + 农历节日（如有）+ 节气（如有）+ 宜忌前三项。把"中国日历差异化"串成一条每日触达。

非目标：

- 不包含日程条数（未来日程数量随系统日历变化，预排内容会过期失真）；
- 不做每日不同的铃声 / 通知操作按钮；
- 不做锁屏 Widget 化简报（锁屏已有日程 / 倒计时 accessory）。

## 数据 / 状态模型

- `LunarKit` 新增 `AlmanacBriefingComposer.compose(for:rules:…)` → `AlmanacBriefing { title, body }`。**内容完全由日期确定性推出**（农历 / 节气 / 节日 / 宜忌规则均为静态数据），因此可提前任意天预排而不过期——这是本设计的核心约束。
- App 层 `DailyBriefingService`（`@MainActor ObservableObject`）：
  - 设置：`daily.briefing.enabled`（默认关）、`daily.briefing.time`（默认 08:00，DatePicker 可调）；
  - 预排窗口：14 天，非重复 `UNCalendarNotificationTrigger`；
  - 前缀 `daily-brief.`，调度前实测闹钟 / 里程碑前缀占用并预留（见 [通知配额](notification-budget.md)），窗口受 `min(64 − 预留, 14)` 约束；
  - 重排时机：开关 / 时间变化、App 激活、系统显著时间变化。

## 用户入口与交互

设置页新增"每日简报"开关 + 时间选择（开启后显示）；首次开启请求通知授权，拒绝后可再开重试。

## 边界与错误状态

- 黄历规则损坏（`bundledShared == nil`）：简报省略宜忌行，其余照发；
- 日期超出 1900–2100：正文提示"超出农历支持范围"；
- 通知被拒：开关可开但静默不排，无错误弹窗；
- 配额不足：按天数顺位裁剪（从最远一天开始丢）。

## 验收清单

- [x] LunarKit XCTest：简报包含农历与干支、节气 / 节日出现与不出现、宜忌条数上限、规则缺失降级、越界日期提示
- [x] 14 天预排 + 配额预留 + 前缀清理
- [x] 设置页开关 + 时间选择 + 授权请求
- [x] App 激活 / 显著时间变化重排
- [x] generic iOS Simulator build 通过
