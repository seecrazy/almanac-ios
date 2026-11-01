# 宜历 Almanac

> 输入最快、信息最全的个人时间管理中枢
> 自然语言建事件 · 农历/节气/黄历 · 法定节假日(含调休) · 里程碑倒计时 · 智能工作日闹钟

## 状态

🚧 核心引擎、EventKit 只读/写入、手动新建日程与设计文档基线已完成；当前进度见 [docs/product/roadmap.md](docs/product/roadmap.md)。

## 核心包（纯逻辑，跨平台可移植）

| 包 | 职责 |
|----|------|
| `LunarKit` | 农历换算(1900-2100)、干支、生肖、农历文本 |
| `HolidayData` | 法定节假日+调休数据与查询引擎（数据与算法分离） |
| `RecurrenceEngine` | 重复规则(RFC 5545 子集)展开 |

原则：**纯逻辑、零 UI 依赖、数据 JSON 化**（ADR-007）。

## 快速开始

```bash
./build.sh            # 编译全部核心包
./build.sh test       # 编译 + XCTest（20 个测试）
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
- **架构**：[ADR-001 EventKit](docs/architecture/adr/ADR-001-eventkit-as-source-of-truth.md)、[ADR-007 跨平台](docs/architecture/adr/ADR-007-cross-platform.md)
- **设计**：[设计系统 v0.1](docs/design/design-system.md)、[事件创建 v1](docs/design/event-creation.md)
