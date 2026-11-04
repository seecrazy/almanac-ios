# 宜历 Almanac

> 输入最快、信息最全的个人时间管理中枢
> 自然语言建事件 · 农历/节气/黄历 · 法定节假日(含调休) · 里程碑倒计时 · 智能工作日闹钟

## 状态

🚧 核心引擎、EventKit 只读/写入、手动新建、自然语言创建 v1、事件详情/编辑/删除、单条提醒、重复规则完整编辑与系列操作、多日历筛选、月 / 周 / 日 / 议程 / 年基础视图矩阵、搜索 v2、里程碑基础闭环、农历生日 / 纪念日、里程碑提醒与小组件、节假日多年度数据管道、黄历面板、二十四节气、工作日智能闹钟已完成代码接入；当前进度见 [docs/product/roadmap.md](docs/product/roadmap.md)。

## 核心包（纯逻辑，跨平台可移植）

| 包 | 职责 |
|----|------|
| `LunarKit` | 农历换算(1900-2100)、干支、生肖、农历文本、二十四节气、黄历规则与宜忌 |
| `HolidayData` | 法定节假日+调休多年度数据管道与查询引擎（manifest、来源标注、覆盖状态、WorkdayResolver） |
| `RecurrenceEngine` | 重复规则(RFC 5545 子集)展开 |
| `NaturalInput` | 本地中文日程输入解析（日期 / 时间 / 全天 / 基础重复 / 地点 / 备注） |
| `MilestoneKit` | 里程碑 Widget 快照、四类提醒请求模型、60 天调度窗口、农历生日 / 纪念日 Resolver |

原则：**纯逻辑、零 UI 依赖、数据 JSON 化**（ADR-007）。

## 平台映射包

| 包 | 职责 |
|----|------|
| `EventKitMapping` | 重复规则编辑状态与 `EKRecurrenceRule` 双向映射、可表示性判断、前三项预览、重复事件编辑范围 |
| `EventSearchKit` | 搜索范围解析、730 天限制、临时日历筛选状态与最近搜索模型 |

## 快速开始

```bash
./build.sh            # 编译全部核心包
./build.sh test       # 编译 + XCTest（70 个测试）
```

构建 iOS App：

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Almanac.xcodeproj \
  -scheme Almanac \
  -destination 'generic/platform=iOS Simulator' build
```

依赖：macOS + Xcode/SwiftPM。如果全局 developer directory 仍指向 CLT，可直接使用
`/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild`。

- **会话交接**：[docs/HANDOFF.md](docs/HANDOFF.md)（新会话先读这个）

## 文档索引

- **产品 / 进展**：[roadmap](docs/product/roadmap.md)、[HANDOFF](docs/HANDOFF.md)
- **架构**：[ADR-001 EventKit](docs/architecture/adr/ADR-001-eventkit-as-source-of-truth.md)、[ADR-007 跨平台](docs/architecture/adr/ADR-007-cross-platform.md)、[ADR-008 自然语言输入](docs/architecture/adr/ADR-008-natural-language-input.md)、[ADR-009 工作日闹钟](docs/architecture/adr/ADR-009-workday-alarm.md)
- **设计**：[设计系统 v0.1](docs/design/design-system.md)、[事件创建 v1](docs/design/event-creation.md)、[自然语言输入 v1](docs/design/natural-language-input.md)、[事件详情/编辑/删除 v1](docs/design/event-detail-editing.md)、[事件提醒 v1](docs/design/event-reminders.md)、[重复规则 v1](docs/design/event-recurrence.md)、[重复规则完整编辑与系列操作 v1](docs/design/recurrence-series-editing.md)、[多日历管理 v1](docs/design/calendar-management.md)、[月视图交互 v1](docs/design/month-interaction.md)、[日 / 周 / 年 / 议程视图 v1](docs/design/views-navigation.md)、[事件搜索 v1](docs/design/event-search.md)、[事件搜索 v2](docs/design/event-search-v2.md)、[黄历面板 v1](docs/design/almanac-panel.md)、[农历生日 / 纪念日 v1](docs/design/lunar-anniversaries.md)、[里程碑 v1](docs/design/milestones.md)、[里程碑提醒与小组件 v1](docs/design/milestone-reminders-widgets.md)、[官方节假日数据管道 v1](docs/design/holiday-data-pipeline.md)、[二十四节气 v1](docs/design/solar-terms.md)、[工作日智能闹钟 v1](docs/design/workday-alarm.md)
- **设计恢复 / 差距**：[历史产品蓝图](docs/design/recovered-product-blueprint.md)、[设计与实现差距](docs/design/design-gap.md)

## 协作规范

- 讨论设计并决定开干后，**第一件事是先把设计写成文档，再写生产代码**。
- 实现过程中同步更新设计文档、roadmap、HANDOFF 和 README。
- 详细要求见 [AGENTS.md](AGENTS.md)。
