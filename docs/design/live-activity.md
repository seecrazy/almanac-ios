# 里程碑 Live Activity 秒级倒计时 v1

状态：已实现（2026-11-09）。关联：[里程碑提醒与小组件](milestone-reminders-widgets.md)、[倒计时卡片](milestones.md)。

## 目标与非目标

目标：时刻里程碑进入 24 小时窗口后，锁屏 / 灵动岛出现秒级倒计时 Live Activity（iOS 16.1+ 门控，低版本无感降级）。

非目标：

- 不做日程 Live Activity（系统日历场景弱，优先级低）；
- 不做推送更新（push token / 服务端不在范围，仅本地更新）；
- 全天里程碑不进 Live Activity（无秒级语义，用通知 + Widget）。

## 数据 / 状态模型

- `MilestoneCountdownAttributes`（`MilestoneKit`，`#if canImport(ActivityKit)` 条件编译，macOS 包测试不受影响）：`title`、`categoryTitle` + ContentState `targetDate`。
- `LiveActivityScheduler`（App，iOS 16.1 门控）：`MilestoneStore.refreshPlatformState` 后同步——
  - 无候选 / 未授权（系统设置 Live Activities 关闭）：结束全部既有活动；
  - 有候选（未来 24h 内最近的时刻里程碑，仅保留一条）：复用既有活动 `update`，否则 `request`；多余活动全部结束。
- Widget 侧 `MilestoneLiveActivity`：锁屏横幅（标题 + 类别 + `Text(timerInterval:)` 秒级倒计时）+ 灵动岛 expanded / compact / minimal 三形态。
- Info.plist `NSSupportsLiveActivities = YES`（App target 构建设置注入）。

## 用户入口与交互

- 无显式入口：倒计时页存在 24h 内时刻里程碑且系统开启 Live Activities 时自动出现；
- 点按活动打开 App（默认行为）。

## 边界与错误状态

- 系统关闭 Live Activities：静默结束，无提示；
- 多条候选：只保留最近一条（设计取舍：多条活动噪音大）；
- 跨过目标时间：倒计时归零后由系统 8 小时自动清理；下次刷新亦会结束。

## 验收清单

- [x] Attributes 与 Widget UI 编译进包（16.1 门控，iOS 15 不受影响）
- [x] 调度器单候选 / 复用更新 / 全量结束路径
- [x] NSSupportsLiveActivities 声明
- [x] generic iOS Simulator build 通过（真机灵动岛验收待做，记入 roadmap）
