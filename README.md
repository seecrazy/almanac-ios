# 宜历 Almanac

> 输入最快、信息最全的个人时间管理中枢
> 自然语言建事件 · 农历/节气/黄历 · 法定节假日(含调休) · 里程碑倒计时 · 智能工作日闹钟

## 状态

🚧 设计已完成，工程启动中。当前进度见 [docs/product/roadmap.md](docs/product/roadmap.md)。

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
./build.sh test       # 编译 + 测试
```

依赖：macOS + Swift 5.4+。完整 Xcode 走 SwiftPM（含 XCTest）；仅 Command Line Tools 自动降级为 swiftc 直编 + Sanity 可执行验证（CLT 缺 xctest 运行时）。

- **会话交接**：[docs/HANDOFF.md](docs/HANDOFF.md)（新会话先读这个）

## 文档索引

- 产品：docs/product/ · 架构：docs/architecture/（含 ADR 决策记录）· 设计：docs/design/
