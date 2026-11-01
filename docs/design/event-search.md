# 事件搜索 v1

状态：已实现代码基线；待模拟器 / 真机验收（2026-11-02）  
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md)  
关联设计：[多日历管理](calendar-management.md) · [事件详情/编辑/删除](event-detail-editing.md)

## 1. 目标

- 用户可以按关键词搜索 EventKit 日程。
- 搜索范围覆盖标题、地点、备注。
- 结果尊重多日历显示 / 隐藏设置。
- 结果可点击进入现有日程详情页。

## 2. 非目标 v1

- 不引入 SQLite / GRDB / FTS。
- 不搜索参与人、附件、重复规则文本。
- 不提供复杂筛选：日期、日历、全天、提醒状态。
- 不搜索全部历史；v1 使用固定时间窗。

## 3. 搜索范围

| 项目 | v1 值 |
|---|---|
| 开始时间 | 当前时间前 180 天 |
| 结束时间 | 当前时间后 365 天 |
| 最大结果 | 100 条 |
| 字段 | 标题、地点、备注 |
| 匹配方式 | 本地化不区分大小写包含 |

## 4. 入口与交互

月视图头部新增搜索按钮。

```text
月视图 → 搜索图标 → 搜索 sheet
输入关键词 → 250ms 防抖 → EventKit 查询 → 展示结果
点击结果 → EventDetailView
```

空关键词显示提示，不自动列出全部日程。  
搜索中显示进度。无结果显示明确空态。

## 5. 结果排序与展示

按开始时间升序。每条结果显示：

- 标题
- 日期 / 时间
- 地点，如果有
- 日历名

结果尊重当前多日历筛选。

## 6. 服务层

EventStoreService 新增：

```swift
func searchEvents(query: String, from start: Date, to end: Date) async
```

状态：

```swift
@Published private(set) var searchResults: [CalendarEvent]
@Published private(set) var isSearching: Bool
@Published private(set) var searchErrorMessage: String?
```

查询通过 EventKit predicate 在指定时间窗读取，再由 App 过滤关键词和可见日历。

## 7. 边界

| 边界 | 行为 |
|---|---|
| 未授权 | 显示未授权提示 |
| 关键词空白 | 清空结果 |
| 超过 100 条 | 只显示前 100 条 |
| 隐藏日历 | 结果不展示 |
| 事件在当前月外 | 详情仍可通过 EventKit 精确获取 |
| EventKit 失败 | 显示系统错误 |

## 8. 验收清单

- [ ] 月视图可进入搜索。
- [ ] 输入关键词后出现结果。
- [ ] 搜索包含标题、地点、备注。
- [ ] 结果按开始时间排序。
- [ ] 隐藏日历结果不出现。
- [ ] 结果可点击进入详情。
- [ ] 空关键词显示提示。
- [ ] 无结果显示空态。
- [x] generic iOS Simulator 构建通过。

## 9. 后续演进

1. 日期范围筛选。
2. 日历筛选器。
3. SQLite / FTS 全文搜索。
4. 搜索参与人和重复规则描述。
5. 最近搜索关键词。
