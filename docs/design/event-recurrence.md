# 事件重复规则 UI v1

状态：已实现代码基线；待模拟器 / 真机验收（2026-11-01）  
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md)  
关联设计：[事件创建](event-creation.md) · [事件详情/编辑/删除](event-detail-editing.md) · [事件提醒](event-reminders.md)

## 1. 目标

- 新建日程时可以选择重复规则。
- 非重复日程编辑时可以补充重复规则。
- 重复规则写入 EventKit，由系统日历展开和同步。
- UI 显示未来重复结束方式，避免用户误以为规则只影响当天。
- 对已存在的复杂重复规则采取只读保护，避免 v1 误改。

## 2. 非目标 v1

- 不编辑已有重复事件的规则。
- 不支持“仅此次 / 此次及未来 / 整个系列”三选一。
- 不支持自定义周几多选。
- 不支持每月第几个周几、农历重复。
- 不支持 RRULE 字符串直接导入。

## 3. 规则模型

| UI 模式 | 语义 | EventKit |
|---|---|---|
| 不重复 | 单次日程 | `recurrenceRules = nil` |
| 每天 | 每 1 天 | `EKRecurrenceFrequency.daily` |
| 每周 | 每 1 周，按开始日星期 | `.weekly` + start weekday |
| 每两周 | 每 2 周，按开始日星期 | `.weekly` + `interval: 2` |
| 每月 | 每 1 月，按开始日日期 | `.monthly` + day of month |
| 每年 | 每 1 年，按开始日月 / 日 | `.yearly` + month/day |
| 保留现有规则 | 复杂规则保护态 | 不修改 `recurrenceRules` |

结束方式：

| 结束方式 | 语义 | EventKit |
|---|---|---|
| 一直重复 | 无结束条件 | `recurrenceEnd = nil` |
| 到日期重复 | 包含当天 | `EKRecurrenceEnd(end:)` |

v1 不提供 `COUNT` 结束方式；已有 count 结尾的规则会进入保护态。

## 4. UI

### 新建 / 编辑非重复事件

```text
重复：每天 / 每周 / 每两周 / 每月 / 每年 / 不重复
结束：一直重复 / 到日期重复
结束日期：DatePicker
```

- “每周 / 每两周”按事件开始日的星期重复。
- “每月”按事件开始日的日期重复。
- “每年”按事件开始日的月和日重复。
- 不重复时隐藏结束条件。

### 已有重复事件

详情和编辑页显示当前重复摘要。

v1 编辑已有重复事件的基础字段时，只允许修改当前发生；重复规则保持只读保护。

保护态包括：

- 多条 recurrence rule。
- 周几多选。
- 与开始日不一致的月 / 年规则。
- `COUNT` 结尾。
- EventKit 中无法稳定映射到 v1 模型的规则。

## 5. EventKit 映射

服务层写入策略：

```text
新建：
  draft -> EKRecurrenceRule

编辑非重复事件：
  draft -> EKRecurrenceRule

编辑已有重复事件：
  不修改 recurrenceRules
```

`EventRecurrenceDraft` 负责双向转换：

```swift
func makeRule(startDate: Date) -> EKRecurrenceRule?
static func init?(rules: [EKRecurrenceRule]?, startDate: Date) -> EventRecurrenceDraft?
```

无法映射的规则返回 `.preserveExisting`。

## 6. 展示摘要

| 示例 | 展示 |
|---|---|
| 不重复 | 不在详情中显示 |
| 每天 | `每天` |
| 每周 | `每周` |
| 每两周 | `每两周` |
| 每月 | `每月` |
| 每年 | `每年` |
| 到 2027-06-07 | `每天 · 至 2027年6月7日` |
| 无法映射 | `自定义重复（宜历 v1 不修改）` |

## 7. 错误与边界

| 边界 | 行为 |
|---|---|
| 已有重复事件 | 重复 Picker 只读保护 |
| 事件只读 | 整体不可编辑 |
| 结束日期早于开始时间 | DatePicker 下限限制为开始日期 |
| 每月 31 日遇到短月 | 由系统日历按 EventKit 规则跳过不存在日期 |
| 重复规则保存失败 | 表单就地显示 EventKit 错误 |
| 用户取消编辑 | 不写入 recurrence rule |

## 8. 验收清单

- [ ] 新建事件可选择不重复 / 每天 / 每周 / 每两周 / 每月 / 每年。
- [ ] 选择重复后可设置“一直重复”或“到日期重复”。
- [ ] 不重复时结束条件隐藏。
- [ ] `EKEvent.recurrenceRules` 按 draft 正确写入。
- [ ] 详情页显示重复摘要。
- [ ] 已有重复事件进入编辑时规则只读保护。
- [ ] 保护态不会被 `save(span: .thisEvent)` 清空。
- [ ] 非重复事件可补充重复规则。
- [x] generic iOS Simulator 构建通过。

## 9. 后续演进

1. 自定义周几多选。
2. `COUNT` 结束方式。
3. 已有重复事件的“仅此次 / 此次及未来 / 整个系列”编辑。
4. `RecurrenceEngine` 的未来发生预览。
5. 农历生日重复。
