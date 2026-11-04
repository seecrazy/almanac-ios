# 事件搜索 v2 设计

状态：代码已接入（2026-11-04）；GUI / 真机验收待完成  
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md)  
关联设计：[事件搜索 v1](event-search.md) · [多日历管理](calendar-management.md)

## 1. 目标

- 在 v1 关键词搜索上增加日期范围和日历筛选。
- 记住最近搜索。
- 提供更清楚的结果元信息。
- 不引入本地数据库。

## 2. 非目标 v2

- 不做 SQLite / FTS。
- 不搜索重复事件的全部展开。
- 不搜索附件、参与人、URL。
- 不做保存的智能搜索。

## 3. 查询状态

```swift
struct EventSearchQuery {
    var keyword: String
    var range: EventSearchRange
    var calendarIDs: Set<String>?
    var includeAllDay: Bool
}

enum EventSearchRange: Hashable {
    case next7Days
    case next30Days
    case pastAndNext90Days
    case custom(start: Date, end: Date)
}
```

默认范围保持 v1：过去 180 天到未来 365 天。

## 4. 筛选 UI

搜索框下方使用横向滚动 chips：

```text
常用 | 未来7天 | 未来30天 | 近90天 | 自定义
```

日历筛选复用多选：

```text
全部日历 | iCloud 工作 | iCloud 个人 | 本地
```

`nil` 表示跟随当前日历显示设置。

## 5. 搜索规则

1. 关键词去首尾空白。
2. 最少 1 个字符，300ms 防抖。
3. 匹配标题、地点、备注。
4. 使用 `localizedStandardContains`。
5. 请求窗口最大 730 天。
6. 最多返回 200 条。
7. 按开始时间升序。
8. 全天事件优先级只在同一天内生效。

## 6. 最近搜索

`UserDefaults` key：

```text
event.search.recent.v1
```

- 最多 8 条。
- 去重、按最近使用排序。
- 保存关键词和范围；不保存临时日历选择。
- 支持单条删除。

## 7. 结果项

结果卡片显示：

1. 标题。
2. 日期和时间，跨天显示起止日期。
3. 地点。
4. 日历颜色和标题。
5. 重复规则摘要或 `重复`。
6. 提醒摘要，仅在已设置时显示。

命中字段不做高亮；v2 只保证可读性。

## 8. 状态

| 状态 | UI |
|---|---|
| 空关键词 | 显示最近搜索 |
| 搜索中 | 进度条 + 保留旧结果 |
| 无结果 | `没有匹配的日程` |
| 权限拒绝 | 显示授权入口 |
| 范围过大 | 自动限制 730 天并提示 |
| 超过上限 | 显示 `仅显示前 200 条，请缩小范围` |
| 隐藏日历 | 不返回结果 |

## 9. 验收清单

- [ ] 关键词搜索保持可用。（GUI 验收待完成）
- [ ] 可选择未来 7 / 30 天、近 90 天、自定义范围。（GUI 验收待完成）
- [ ] 自定义开始不能晚于结束。（GUI 验收待完成）
- [ ] 可选择单个或多个日历。（GUI 验收待完成）
- [ ] 最近搜索最多 8 条且可删除。（GUI 验收待完成）
- [ ] 结果点击进入详情。（GUI 验收待完成）
- [ ] 连续输入不产生旧结果覆盖新结果。（GUI 验收待完成）
- [ ] 超过 200 条时提示缩小范围。（GUI 验收待完成）
- [ ] 无权限不崩溃。（GUI 验收待完成）
- [x] XCTest 覆盖 query 构建和最近搜索去重。
