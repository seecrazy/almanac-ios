# 事件详情、编辑与删除设计 v1

状态：代码基线与重复范围操作已接入（2026-11-04）；GUI / 真机人工验收按当前决策暂跳过
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md)
关联设计：[事件创建](event-creation.md) · [事件提醒](event-reminders.md) · [重复规则](event-recurrence.md) · [重复规则完整编辑与系列操作](recurrence-series-editing.md) · [设计系统](design-system.md)

## 1. 目标

- 用户可以从日详情进入某条系统日程的详情页。
- 用户可以查看日程的标题、时间、全天状态、地点、备注和所属日历。
- 对可写日历中的日程，用户可以编辑基础字段。
- 用户可以删除可写日历中的日程。
- 保存或删除后，月视图日程圆点和日详情列表立刻反映 EventKit 最新状态。

## 2. 非目标 v1

- 复杂重复规则保持只读；可表示规则由 [recurrence-series-editing.md](recurrence-series-editing.md) 接管。
- 不编辑参与人、附件、会议链接；单条提醒由 [event-reminders.md](event-reminders.md) 接管。
- 不处理只读日历的本地草稿或覆盖写入。
- 不做撤销删除；删除直接作用于 EventKit。

## 3. 入口与用户流程

### 查看详情

```text
日详情 → 点击“今日日程”某一行 → EventDetailView
```

详情页展示 EventKit 当前数据，不使用独立缓存作为事实源。

### 编辑

```text
EventDetailView → 编辑按钮 → EventEditView
  → 修改基础字段
  → 重复日程选择影响范围
  → 保存
  → EventStoreService.updateEvent(...)
  → EKEventStore.save(..., span: selected span)
  → 刷新已加载月份
```

### 删除

```text
EventDetailView → 删除按钮
  → 非重复：系统删除确认
  → 重复：仅此发生 / 此次及未来 / 整个系列
  → EventStoreService.deleteEvent(...)
  → EKEventStore.remove(..., span: selected span)
  → 刷新已加载月份
  → 关闭详情 sheet
```

## 4. 字段模型

| 字段 | 可编辑 | EventKit 映射 | v1 行为 |
|---|---:|---|---|
| 标题 | 是 | `EKEvent.title` | 清理首尾空白；为空时禁用保存 |
| 全天 | 是 | `EKEvent.isAllDay` | 开启后只显示日期选择 |
| 开始时间 | 是 | `EKEvent.startDate` | 普通日程显示日期 + 时间 |
| 结束时间 | 是 | `EKEvent.endDate` | 必须晚于开始时间 |
| 地点 | 是 | `EKEvent.location` | 空值写入 `nil` |
| 备注 | 是 | `EKEvent.notes` | 空值写入 `nil` |
| 目标日历 | 是 | `EKEvent.calendar` | 只允许选择可写日历 |
| 重复规则 | 非重复可补充；重复可编辑可表示规则 | `EKEvent.recurrenceRules` | 复杂规则只读保护 |

详情页额外展示：

- 所属日历。
- 是否为重复日程。
- 当前日历是否可写。

## 5. 事件获取与可写性

EventStoreService 新增能力：

```swift
func event(with model: CalendarEvent) -> CalendarEvent?
func updateEvent(...)
func deleteEvent(...)
```

`CalendarEvent.id` 用于 SwiftUI 稳定渲染；写入操作不能只依赖它。因为重复日程的多个发生项可能共享 EventKit event identifier，服务层会用“event identifier + 发生开始时间 + 发生结束时间”在已加载区间附近精确定位当前发生项：

```swift
store.events(matching: predicate)
  .first { candidate in
    (candidate.eventIdentifier ?? candidate.calendarItemExternalIdentifier) == model.eventIdentifier
      && candidate.startDate == model.startDate
      && candidate.endDate == model.endDate
  }
```

可写性判断：

```swift
event.calendar?.allowsContentModifications == true
```

如果事件不存在、事件已被外部删除，或日历只读，UI 必须显示明确错误，不能静默失败。

## 6. 重复日程范围策略

重复日程先选择影响范围，再执行编辑或删除：

| 范围 | 编辑行为 | 删除行为 |
|---|---|
| 仅此发生 | 修改当前发生，保持原 recurrence rules | `remove(..., span: .thisEvent)` |
| 此次及未来 | 从当前发生开始保存新规则 / 字段 | `remove(..., span: .futureEvents)` |
| 整个系列 | 查找 series master 后保存 | master `remove(..., span: .futureEvents)` |

不可表示规则进入只读保护，保存时不改写 `recurrenceRules`。

### 6.1 例外与刷新

“仅此发生”依赖 EventKit 生成本次例外；“此次及未来”由 EventKit 拆分 series；两者都通过 `EKEventStoreChanged` 和主动 reload 刷新月视图与日详情。

## 7. 状态设计

| 状态 | UI 行为 |
|---|---|
| 事件可写 | 显示“编辑”“删除” |
| 事件只读 | 详情可查看；编辑 / 删除不可用，并说明日历只读 |
| 保存中 | 保存按钮禁用并显示进度 |
| 删除确认中 | 显示系统确认；确认按钮为 destructive |
| 保存成功 | 关闭编辑页；详情与日详情刷新 |
| 删除成功 | 关闭详情页；日详情列表移除该事件 |
| 事件已被删除 | 显示“日程不存在或已被删除” |
| EventKit 失败 | 保留系统错误描述并就地显示 |

## 8. 并发与刷新

- 删除和保存仍以 EventKit 为唯一事实源。
- 操作成功后主动触发 `reloadIfNecessary()`。
- 同时继续依赖 `EKEventStoreChanged`，处理 iCloud / 其他客户端引起的变更。
- 日详情 sheet 不缓存永久状态；每次展示时从 `EventStoreService.events(on:)` 读取当前列表。

## 9. 验收清单

- [x] generic iOS Simulator 构建通过。
- [x] 日详情中的每条日程可点击进入详情。
- [x] 详情显示标题、时间、全天、地点、备注、日历。
- [x] 可写事件显示编辑和删除。
- [x] 只读日历事件不显示可用的编辑 / 删除动作。
- [x] 编辑标题、时间、全天、地点、备注、日历后 EventKit 数据更新。
- [x] 删除可写事件后日详情和月视图圆点更新。
- [x] 重复日程可选择仅此发生 / 此次及未来 / 整个系列。
- [x] 仅此发生保持原重复规则。
- [x] 只读事件不会发起 EventKit 写请求。
- [x] 删除确认必须显式确认。

## 10. 后续演进

1. 编辑 / 删除前重新检查事件仍然存在。
2. 编辑多条提醒。
3. 复杂 RRULE 只读解释。
4. 权限被拒后跳系统设置。
5. 使用 SwiftUI Testing 覆盖表单校验和错误状态。
