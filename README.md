# 宜历 Almanac

> 输入最快、信息最全的个人时间管理中枢
> 自然语言建事件 · 农历/节气/节日/黄历 · 法定节假日(含调休,联网自动更新) · 里程碑倒计时 · 日详情加密日记 · 独立闹钟页 / 多闹钟 / 铃声 · 冲突检测 / 空闲时段 · 日程+倒计时 Widget · Live Activity · 每日简报 · 拼音搜索 · Spotlight · App Intents · 联系人生日导入 · iPad 双栏 · 年度回顾 · 备份导出导入 · 深链 · 自定义图标（深浅/染色）

## 状态

🚧 核心引擎、EventKit 只读/写入、手动新建、自然语言创建 v1（含 App Intents / 快捷指令）、事件详情/编辑/删除/`.ics` 分享、重复规则完整编辑、多日历筛选、本机日历管理、月 / 年 / 议程 / 周模式视图、iPad 双栏、搜索 v2 与 SQLite FTS5 索引（含拼音全拼/首字母）、倒计时卡片、加密日记、农历生日 / 纪念日（含通讯录导入）、里程碑提醒与小组件、日程小组件（桌面+锁屏）、Live Activity 秒级倒计时、每日简报、独立闹钟页（64 条通知配额三路预留 · 全屏响铃 · 后台保活静音也响 · 9 种铃声）、冲突检测 / 空闲时段、Spotlight 深链、Dynamic Type 正文适配、GitHub Actions CI 已完成代码接入；当前进度见 [docs/product/roadmap.md](docs/product/roadmap.md)。

## 核心包（纯逻辑，跨平台可移植）

| 包 | 职责 |
|----|------|
| `LunarKit` | 农历换算(1900-2100)、干支、生肖、农历文本、二十四节气、农历节日、黄历规则与宜忌、每日简报组装 |
| `HolidayData` | 法定节假日+调休多年度数据管道与查询引擎（manifest、来源标注、覆盖状态、WorkdayResolver、多闹钟计划、通知配额规划） |
| `RecurrenceEngine` | 重复规则(RFC 5545 子集)展开 |
| `NaturalInput` | 本地中文日程输入解析（日期 / 时间 / 全天 / 基础重复 / 地点 / 备注） |
| `MilestoneKit` | 里程碑 Widget 快照、日程 Widget 快照、四类提醒请求模型、60 天调度窗口、农历生日 / 纪念日 Resolver、联系人生日映射、Live Activity Attributes |
| `CalendarAnalysis` | 冲突组识别、全天 / 跨日处理与当日空闲时段计算 |
| `DiaryKit` | 日记模型、AES-256-GCM 加密存储、HMAC 日期键与一天一篇查询 |

原则：**纯逻辑、零 UI 依赖、数据 JSON 化**（ADR-007）。

## 平台映射包

| 包 | 职责 |
|----|------|
| `EventKitMapping` | 重复规则编辑状态与 `EKRecurrenceRule` 双向映射、可表示性判断、前三项预览、重复事件编辑范围、本地日历管理策略、RFC 5545 单事件 .ics 导出 |
| `EventSearchKit` | 搜索范围解析、730 天限制、临时日历筛选状态、最近搜索模型、SQLite FTS5 可重建索引（指纹跳过重建、拼音全拼/首字母） |

## 快速开始

```bash
./build.sh            # 编译全部核心包
./build.sh test       # 编译 + XCTest（119 个测试；另有 App 单测 14 + UI 冒烟 1）
```

构建与测试 iOS App（含 App 层单测）：

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Almanac.xcodeproj \
  -scheme Almanac \
  -destination 'generic/platform=iOS Simulator' build

/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project Almanac.xcodeproj \
  -scheme Almanac \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

依赖：macOS + Xcode/SwiftPM。如果全局 developer directory 仍指向 CLT，可直接使用
`/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild`。

- **会话交接**：[docs/HANDOFF.md](docs/HANDOFF.md)（新会话先读这个）

## 文档索引

- **产品 / 进展**：[roadmap](docs/product/roadmap.md)、[HANDOFF](docs/HANDOFF.md)
- **架构**：[ADR-001 EventKit](docs/architecture/adr/ADR-001-eventkit-as-source-of-truth.md)、[ADR-007 跨平台](docs/architecture/adr/ADR-007-cross-platform.md)、[ADR-008 自然语言输入](docs/architecture/adr/ADR-008-natural-language-input.md)、[ADR-009 工作日闹钟](docs/architecture/adr/ADR-009-workday-alarm.md)、[ADR-010 搜索索引](docs/architecture/adr/ADR-010-event-search-sqlite-index.md)、[ADR-011 日记存储](docs/architecture/adr/ADR-011-diary-local-encrypted-storage.md)、[ADR-012 Watch App](docs/architecture/adr/ADR-012-watch-app-engineering.md)、[ADR-013 节假日联网更新](docs/architecture/adr/ADR-013-remote-holiday-dataset.md)
- **设计（UX 打磨与回顾批次 2026-11-10）**：[UX 打磨](docs/design/ux-polish.md)、[年度回顾](docs/design/year-in-review.md)、[备份导出导入](docs/design/backup-export.md)
- **设计（平台能力批次 2026-11）**：[通知配额](docs/design/notification-budget.md)、[性能优化](docs/design/performance-optimizations.md)、[日程小组件](docs/design/schedule-widget.md)、[周模式](docs/design/week-mode.md)、[每日简报](docs/design/daily-briefing.md)、[.ics 分享](docs/design/event-sharing.md)、[Spotlight](docs/design/spotlight.md)、[拼音搜索](docs/design/pinyin-search.md)、[App Intents](docs/design/app-intents.md)、[联系人生日导入](docs/design/contacts-birthdays.md)、[Live Activity](docs/design/live-activity.md)、[Dynamic Type](docs/design/dynamic-type.md)、[iPad 适配](docs/design/ipad-adaptation.md)
- **设计（既有）**：[设计系统 v0.1](docs/design/design-system.md)、[事件创建 v1](docs/design/event-creation.md)、[自然语言输入 v1](docs/design/natural-language-input.md)、[事件详情/编辑/删除 v1](docs/design/event-detail-editing.md)、[事件提醒 v1](docs/design/event-reminders.md)、[重复规则 v1](docs/design/event-recurrence.md)、[重复规则完整编辑与系列操作 v1](docs/design/recurrence-series-editing.md)、[多日历管理 v1](docs/design/calendar-management.md)、[月视图交互 v1](docs/design/month-interaction.md)、[月 / 年 / 议程视图 v1.3](docs/design/views-navigation.md)、[事件搜索 v1](docs/design/event-search.md)、[事件搜索 v2](docs/design/event-search-v2.md)、[搜索本地索引 v1](docs/design/event-search-local-index.md)、[黄历面板 v1](docs/design/almanac-panel.md)、[农历生日 / 纪念日 v1](docs/design/lunar-anniversaries.md)、[倒计时卡片 v1.1](docs/design/milestones.md)、[日记 v1.1](docs/design/diary.md)、[里程碑提醒与小组件 v1](docs/design/milestone-reminders-widgets.md)、[官方节假日数据管道 v1](docs/design/holiday-data-pipeline.md)、[二十四节气 v1](docs/design/solar-terms.md)、[农历节日 v1](docs/design/lunar-festivals.md)、[工作日智能闹钟 v1.3](docs/design/workday-alarm.md)
- **设计恢复 / 差距**：[历史产品蓝图](docs/design/recovered-product-blueprint.md)、[设计与实现差距](docs/design/design-gap.md)
- **本地日历管理**：[设计 v1.1](docs/design/local-calendar-management.md)
- **搜索本地索引**：[设计 v1](docs/design/event-search-local-index.md)

## 协作规范

- 讨论设计并决定开干后，**第一件事是先把设计写成文档，再写生产代码**。
- 实现过程中同步更新设计文档、roadmap、HANDOFF 和 README。
- 详细要求见 [AGENTS.md](AGENTS.md)。
