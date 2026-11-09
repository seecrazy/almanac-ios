# ADR-012: watchOS App 的工程接入方式

状态：已接受（2026-11-09）；实施待 Xcode GUI 完成 target 创建。

## 背景

[设计差距](../../design/design-gap.md) 将 Apple Watch 列为完全空白。iOS App 的核心卖点——农历 / 节气 / 宜忌 / 倒计时 / 智能闹钟预览——在手表上有天然场景（表盘复杂功能、快捷一瞥）。

## 决策

1. **架构**：watchOS App 复用现有纯逻辑包（LunarKit / HolidayData / MilestoneKit），UI 用 SwiftUI 原生 watch App（watchOS 9+，单 target，不用 WatchKit 旧模板）。数据经 App Group 同步快照（与 Widget 相同模式），不在手表侧写 EventKit。
2. **v1 范围**：今日一瞥页（农历 / 节气 / 节日 / 宜忌前三）+ 下一个里程碑倒计时 + 下一次闹钟预览；表盘复杂功能（accessoryCircular / accessoryRectangular / accessoryInline）复用同一快照。
3. **工程落地方式**：新建 watchOS App target 及其与 iOS App 的 embed 关系属于 Xcode 工程结构变更。本仓库 pbxproj 为手写维护（见 HANDOFF"手写 pbxproj"注记），**watch target 必须在 Xcode GUI 中创建**（File > New > Target > watchOS App），由 GUI 生成正确的 WatchKit embed / container 关系后再把包依赖（LunarKit / HolidayData / MilestoneKit）与源码文件加入 target。禁止盲写该部分 pbxproj——embed watch app 的 Copy Files 阶段与 WKCompanionAppBundleIdentifier 关联容易写错且难以静态验证。
4. **数据同步**：延续 App Group 快照（`milestone-widget-snapshot.json` 已存在；新增 `watch-briefing.json` 由 iOS 侧写入：今日农历文本 + 节气 + 节日 + 宜忌前三 + 下次闹钟时间）。手表只读，无回写。

## 后果

- 正面：复用九包纯逻辑，零重写；快照模式已在 Widget 验证。
- 负面：需要一次 Xcode GUI 操作（人工步骤，本 ADR 记录后从 roadmap 跟踪）；手表端数据新鲜度受 iOS 侧写入时机限制（激活 / 显著时间变化时刷新）。
- 后续：手表侧编辑（快速新建日程）需 App Intents / WatchConnectivity，另行评估。

## 验收（实施时）

- [ ] Xcode GUI 创建 watchOS target 并通过构建
- [ ] 今日一瞥页 + 三种表盘复杂功能
- [ ] App Group 快照读取（无快照时空态）
