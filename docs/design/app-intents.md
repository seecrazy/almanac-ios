# App Intents / 快捷指令 v1

状态：已实现（2026-11-09）。关联：[自然语言输入](natural-language-input.md)、ADR-008。

## 目标与非目标

目标：把自然语言建日程暴露为 App Intents（iOS 16+，低版本自动不可见）：

- Intent「用自然语言记日程」：参数 `phrase`（如"明天下午3点到5点 开会 @会议室"）→ 打开 App → 复用月视图快速输入解析流 → `AddEventView` 确认保存；
- App Shortcuts 短语："宜历记日程" / "宜历添加日程"（零配置出现在快捷指令 / Siri 建议）。

非目标：

- 不在 Intent 内直接写 EventKit（扩展进程授权与日历写回复杂度高，v1 保留"确认页"边界，与 ADR-008 的确认流一致）；
- 不做「查询今天日程」Intent（本地问答引擎未实现，见 roadmap v2.0+）。

## 数据 / 状态模型

- `QuickEventIntent`（AppIntent）：`openAppWhenRun = true`；`perform()` 把 phrase 写入 `QuickIntentMailbox`（MainActor 单例 ObservableObject）。
- `RootView` `.onReceive(mailbox.$pendingPhrase)` → `AppRouter.pendingQuickPhrase`；`MonthView` 消费：填入快速输入框并走既有 `parseQuickInput()`（解析 → 表单预填 → 用户确认）。
- 消费后清空，避免重复触发。

## 用户入口与交互

- 快捷指令 App / Siri：「宜历记日程」+ 听写或文本参数；
- 快捷指令自动化（如充电时、上车时）传入固定 phrase。

## 边界与错误状态

- 解析警告（未识别日期 / 时间）沿既有快速输入路径就地展示；
- App 已在后台运行：mailbox 照常触发（onReceive 对当前值亦生效）；
- iOS 15：Intent 类型整体 `@available(iOS 16.0, *)`，快捷指令库不出现，App 行为不变。

## 验收清单

- [x] AppIntent + AppShortcutsProvider 编译进 App（iOS 16 门控）
- [x] phrase → 月视图快速输入 → 解析 → 确认表单全链路
- [x] 消费后载荷清空；重复调用幂等
- [x] generic iOS Simulator build 通过（真机 Siri 验收待做，记入 roadmap）
