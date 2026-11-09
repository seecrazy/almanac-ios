# iPad 双栏适配 v1

状态：已实现（2026-11-09）。关联：[月视图交互](month-interaction.md)、[周模式](week-mode.md)。

## 目标与非目标

目标：iPad（`horizontalSizeClass == .regular`）上，月视图变为左右双栏——左栏月格与快速输入，右栏常驻日详情（跟随选中日），点日期不再弹 sheet 而是刷新右栏。

非目标：

- 不引入三栏 sidebar（设置 / 日历列表侧栏，后续随 iPad 专项评估）；
- 其余 Tab（倒计时 / 闹钟 / 设置）维持既有单列布局（内容宽度自适应）；
- iPhone 行为完全不变。

## 用户入口与交互

- 点左栏任意日期 → `selectedDate` 更新 → 右栏详情即时切换；
- 右栏详情内的既有交互（黄历、日记、日程、新建）全部保留；
- 周模式下同样双栏（左栏单周 + 日程列表，右栏日详情）。

## 数据 / 状态模型

`MonthView` 增加 `@Environment(\.horizontalSizeClass)`：regular 时渲染 `HStack { 月栏; Divider; DayDetail(date: selectedDate) }`，compact 时维持既有 `.sheet(item: $selectedDay)`。日格点击在 regular 下只更新 `selectedDate`（不置 `selectedDay`，避免误弹 sheet）。

## 边界与错误状态

- 横竖屏切换（size class 变化）：SwiftUI 自动切换布局，状态保持；
- iPad 台前调度窗口压缩成 compact：回退 sheet 行为，已打开的详情以 `selectedDate` 兜底。

## 验收清单

- [x] iPad regular 双栏 / iPhone compact sheet 行为分流
- [x] 双栏下点日期即时切换右栏
- [x] generic iOS Simulator build 通过
- [ ] iPad 模拟器逐屏走查（记入 roadmap 待验收）
