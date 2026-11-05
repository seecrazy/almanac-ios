# ADR-010: 事件搜索使用可重建 SQLite FTS5 派生索引

状态：已接受（2026-11-05）

## 背景

EventKit `predicateForEvents` 依赖日期窗口，关键词、日历与全天过滤目前发生在 App 内存中。搜索范围扩大后需要遍历较多事件，且后续本地日历数据、复杂查询和分页也需要可测试的查询层。

## 决策

1. `EventSearchKit` 增加纯逻辑 `EventSearchIndex`，使用系统 SQLite 与 FTS5。
2. SQLite 文件是可随时删除重建的派生缓存；EventKit 仍是日程事实源（ADR-001）。
3. 搜索窗口内先从 EventKit 拉取事件，批量重建 `metadata + FTS`，再由 SQLite 统一执行关键词、日期重叠、日历、全天与排序过滤。
4. 索引初始化、重建或查询失败时降级为现有内存过滤，不让搜索不可用。
5. 不引入 GRDB；当前 schema 极小，直接使用 SQLite C API 可避免额外依赖。

## 影响

- 搜索核心可脱离 EventKit 与 SwiftUI 做 XCTest。
- 关键词与结构化过滤逐步迁移到 SQL，为后续分页、复杂查询与本地数据源预留路径。
- 每次搜索窗口内重建索引，牺牲部分写入成本换取无需增量同步的状态一致性。
- 未来若索引规模或更新频率变高，再演进为增量 upsert / delete 与后台刷新。
