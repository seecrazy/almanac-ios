# 本地通知配额与调度窗口 v1

状态：已实现（2026-11-09）。关联：[ADR-009 工作日闹钟](../architecture/adr/ADR-009-workday-alarm.md)、[智能闹钟 v1.3](workday-alarm.md)、[里程碑提醒与小组件](milestone-reminders-widgets.md)、[每日简报 v1](daily-briefing.md)。

## 问题

iOS 限制每个 App 最多 64 条待发本地通知，超出部分被系统静默丢弃。此前三类通知共用这 64 条配额且互不知情：

- 智能闹钟按 60 天窗口调度，8 个闹钟最坏约 480 条；
- 里程碑 / 纪念日提醒，每条最多 4 类 × 里程碑数量不设上限；
- 每日简报（后引入）需要 1 条常驻 repeating 通知。

后果：闹钟开启 2 个以上时必然溢出，里程碑提醒被挤掉，且没有任何 UI 提示。另外 `WorkdayAlarmStore` 此前只在闹钟页被创建（`@StateObject` 在 `AlarmView` 内），用户不进闹钟页就不会重排通知，窗口过期后闹钟静默失效。

## 目标与非目标

目标：

1. 闹钟、里程碑、简报三类通知总和不超过 64 条，溢出时优先保留最早触发的请求。
2. 每次 App 激活、系统显著时间变化（跨天 / 时区变化）时重排闹钟通知，窗口自动向前滑动。
3. 闹钟页如实展示「计划 N 次 / 实际调度 M 次」，不再承诺做不到的 60 天满额响铃。

非目标：

- 不引入 BGTaskScheduler 后台刷新（受手写工程 Info.plist 配置约束，另行评估）；
- 不改变闹钟响铃方式（本地通知，非系统闹钟框架）；
- 不做配额的跨设备协商。

## 数据 / 状态模型

`HolidayData` 新增纯逻辑 `NotificationBudgetPlanner`：

- `systemPendingLimit = 64`（iOS 文档值）；
- `identifierPrefixes`：闹钟 `workday-alarm.`、里程碑 `milestone.`、简报 `daily-brief.`（与两个服务既有前缀一致，作为唯一事实来源）；
- `trimming<T>(items: [T], budget: Int) -> [T]`：输入按触发时间升序的请求，返回前 `budget` 条；`budget <= 0` 返回空。

App 层两处消费：

- `WorkdayAlarmStore.replacePendingNotifications()`：先读当前 pending 的 `milestone.` 与 `daily-brief.` 数量作为预留，`budget = 64 - 预留`，对 60 天计划按 fireDate 升序裁剪后注册。
- `MilestonePlatformService.sync()`：请求按 fireDate 升序，预留 pending 的 `workday-alarm.` 与 `daily-brief.` 数量后裁剪。

预留采用「调度时实测对方占用」而非固定配额：两边互不持有对方状态，且用户实际配置差异极大（单闹钟用户应能用满里程碑配额，反之亦然）。

## 关键流程

重排时机（`AlmanacApp`）：

1. `WorkdayAlarmStore` 提升为 App 级 `@StateObject` 并注入 environmentObject，闹钟页改为消费方；
2. `scenePhase == .active`：`alarmStore.reschedule()`（刷新授权 → 若已授权则重排；不请求授权、不落盘）+ 里程碑 `refreshPlatformState()`；
3. `significantTimeChangeNotification`（跨天 / 手动改时间 / 时区变化）：同样触发两者重排。

裁剪流程：删除自身前缀的 pending → 统计对方前缀占用 → 计算预算 → 裁剪（保最早）→ 逐条注册。

## 边界与错误状态

- 对方前缀 pending 计数发生在删除自身之后，两服务并发重排的瞬时竞态最多导致本次少排几条，下次激活自愈；
- 预算为 0 时静默不排，闹钟页预览区显示「通知配额已满」；
- 授权被拒：维持既有行为（清空自身 pending，不阻塞保存）。

## 验收清单

- [x] `NotificationBudgetPlanner.trimming` 保留最早 N 条、budget≤0 返回空、budget≥count 全量返回（HolidayData XCTest）
- [x] 闹钟调度数量 = min(60 天计划, 64 − 对方预留)
- [x] 里程碑调度数量同理
- [x] App 激活 / 显著时间变化触发重排，无需进入闹钟页
- [x] 闹钟页显示「未来 60 天计划 N 次 / 将调度 M 次」并在裁剪发生时注明系统上限
- [x] `./build.sh test` 全绿 + generic iOS Simulator build 通过
