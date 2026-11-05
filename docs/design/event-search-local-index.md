# 事件本地搜索索引 v1

状态：已实现并接入 App v1（2026-11-05）
架构依据：[ADR-010](../architecture/adr/ADR-010-event-search-sqlite-index.md)
关联设计：[事件搜索 v2](event-search-v2.md)

## 1. 目标

- 使用 SQLite FTS5 建立可重建的事件文本索引。
- 在索引层完成关键词、日期重叠、日历、全天过滤和排序。
- 搜索结果上限继续为 200 条。
- SQLite 异常时自动降级为现有内存过滤。
- 索引逻辑不依赖 EventKit、SwiftUI 或 App 生命周期。

## 2. 非目标

- 不改变 EventKit 作为日程事实源。
- 不做跨设备索引同步。
- 不在 v1 做全库后台增量索引。
- 不支持语义搜索、拼音、模糊纠错或复杂布尔表达式。
- 不引入 GRDB 等第三方依赖。

## 3. 数据 / 状态模型

```swift
struct IndexedEventRecord {
    let eventID: String
    let calendarID: String
    let title: String
    let location: String?
    let notes: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
}
```

SQLite 表：

- `event_metadata(event_id, calendar_id, start_time, end_time, is_all_day)`
- `event_fts(event_id, title, location, notes)`，FTS5 `unicode61`
- FTS 普通文本列不接受 `NULL`；`location` / `notes` 为空时写入空字符串，查询回填时仍保留模型中的 `nil`。

索引文件位于 App Support 下的 `EventSearchIndex.sqlite`；文件可删除，下次搜索自动重建。

## 4. 用户流程

1. 用户输入关键词并选择日期 / 日历 / 全天条件。
2. App 拉取该搜索窗口内的 EventKit 事件。
3. 先按用户选择的日历与已可见日历求有效日历集合；空集合直接返回空结果。
4. 批量替换 SQLite 索引记录。
5. SQLite 查询返回命中事件 ID。
6. App 用 EventKit 拉取到的领域模型按 ID 回填并展示。

## 5. 关键交互

- 关键词按空白拆分为 FTS 前缀短语，多词之间为 AND。
- FTS5 `unicode61` 无法稳定切分中文短词；包含 CJK 字符的关键词同时使用转义后的 `LIKE` 子串匹配兜底。
- FTS `MATCH` 放在 CTE 内先解析候选记录，再与 metadata JOIN；避免把 FTS 表作为普通列参与 JOIN 时出现运行时类型错误。
- CJK 关键词的 CTE 不预过滤 FTS，后续 SQL `LIKE` 才能命中字段中部的连续子串。
- FTS 字符串短语使用成对双引号转义；`LIKE` 使用反斜杠转义 `%`、`_` 和 `\`。
- 日期使用事件与搜索窗口重叠判断：`start < window.end && end > window.start`。
- `calendarIDs == nil` 表示全部日历；空集合返回空结果。
- `includeAllDay == false` 时排除全天事件。
- 排序：开始时间升序；同日开始的全天事件优先；再按结束时间升序。

## 6. 边界与错误处理

| 场景 | 行为 |
|---|---|
| 索引目录 / 数据库无法创建 | 丢弃索引对象，降级内存过滤 |
| SQL 创建或写入失败 | 本次搜索降级内存过滤 |
| FTS 关键词语法异常 | 关键词按短语转义；仍失败则降级 |
| EventKit 领域模型与索引 ID 回填失败 | 只丢弃无法回填的结果 |
| EventKit 窗口为空 | 重建为空索引，返回空结果 |
| 结果超过 200 | 截断并继续展示超限提示 |
| 数据库残留损坏 | 可删除索引文件自动重建；v1 不自动删除 |

## 7. 验收清单

- [x] 建库与 schema 初始化成功。
- [x] 标题 / 地点 / 备注关键词均可命中。
- [x] 日期重叠、日历集合、全天过滤正确。
- [x] 排序与 200 条上限正确。
- [x] 批量替换会清除旧记录。
- [x] FTS 输入转义不会执行任意查询语法。
- [ ] SQLite 失败时 App 搜索降级可用。
- [x] EventSearchKit XCTest 与 generic iOS Simulator build 通过。
