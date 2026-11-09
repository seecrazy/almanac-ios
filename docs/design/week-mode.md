# 月视图周模式 v1

状态：已实现（2026-11-09）。关联：[月视图交互](month-interaction.md)、[视图矩阵](views-navigation.md)。

## 目标与非目标

目标：月视图可收起为"单周视图"——只显示选中日期所在周的一行日格，下方直接列出该日日程，点日程进详情。提供两种切换方式：

1. 网格上滑（上移手势）收起为周、下拉展开为月；
2. 头部按钮显式切换。

非目标：不做独立周视图页签；不做周日程时间轴（时段图形化）；不改既有月视图数据加载。

## 用户入口与交互

- 手势：在月格区域，竖直位移 ≥ 56pt 且明显大于水平位移时触发（与既有横滑翻月手势互斥：按主导轴判定）；上滑收起、下拉展开。
- 头部按钮：`rectangle.compress.vertical` / `rectangle.expand.vertical` 图标，VoiceOver 标签"切换周视图 / 月视图"。
- 周模式下点周内任意一天：切换选中日，日程列表跟随。
- 周模式下横滑：选中日 ±7 天（保持时刻），月 / 周区间跟随选中日。

## 数据 / 状态模型

- `@AppStorage("month.view.weekMode")`：Bool，跨会话保留。
- 网格 cells：周模式取 `calendar.dateInterval(of: .weekOfYear, for: selectedDate)`（周起始日设置继续生效），月模式不变。
- 周模式下方追加 `selectedDate` 的日程列表：复用 `EventRow` + `EventDetailView` sheet；空态"这一天暂无日程"。

## 边界与错误状态

- 选中日在周区间跨月（如月初 / 月末周）：visibleMonth 通过既有 `onChange(selectedDate)` 跟随；
- 未授权 / 无日程：空态文案，不阻塞；
- 周模式切换不触发数据重载（月份数据已覆盖相邻周）。

## 验收清单

- [x] 手势上 / 下滑切换周 / 月，与横滑翻月互斥
- [x] 头部按钮切换 + VoiceOver 标签
- [x] 周模式显示单周日格 + 选中日日程列表，可点入详情
- [x] 周模式横滑按 ±7 天移动选中日
- [x] 周模式偏好持久化
- [x] generic iOS Simulator build 通过
