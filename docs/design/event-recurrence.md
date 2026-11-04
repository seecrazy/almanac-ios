# 事件重复规则 UI v1

状态：基础与完整编辑代码已接入（2026-11-04）；GUI / 真机人工验收按当前决策暂跳过
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md)
关联设计：[事件创建](event-creation.md) · [事件详情/编辑/删除](event-detail-editing.md) · [事件提醒](event-reminders.md) · [重复规则完整编辑与系列操作](recurrence-series-editing.md)

## 1. 目标

- 新建日程时可以选择重复规则。
- 非重复日程编辑时可以补充重复规则。
- 重复规则写入 EventKit，由系统日历展开和同步。
- UI 显示未来重复结束方式，避免用户误以为规则只影响当天。
- 已有可表示重复规则可编辑；复杂规则采取只读保护，避免误改。

## 2. 非目标 v1

- 不支持 RRULE 字符串直接导入。
- 不支持农历重复。
- 不支持负数月日、负数周序、BYSETPOS、YEARLY BYDAY 等复杂规则。
- 不支持 RRULE 字符串直接导入。

## 3. 规则模型

| UI 模式 | 语义 | EventKit |
|---|---|---|
| 不重复 | 单次日程 | `recurrenceRules = nil` |
| 每天 | 每 1 天 | `EKRecurrenceFrequency.daily` |
| 每天 | 每 N 天（1–999） | `.daily` + `interval` |
| 每周 | 每 1 周，可多选周几 | `.weekly` + `BYDAY` |
| 每两周 | 每 2 周，可多选周几 | `.weekly` + `interval: 2` + `BYDAY` |
| 每月 | 每月按日期或第 N 个周几 | `.monthly` + `BYMONTHDAY` / nth `BYDAY` |
| 每年 | 每 1 年，按开始日月 / 日 | `.yearly` + month/day |
| 保留现有规则 | 复杂规则保护态 | 不修改 `recurrenceRules` |

结束方式：

| 结束方式 | 语义 | EventKit |
|---|---|---|
| 一直重复 | 无结束条件 | `recurrenceEnd = nil` |
| 到日期重复 | 包含当天 | `EKRecurrenceEnd(end:)` |
| N 次重复 | 含当前发生，总计 N 次 | `EKRecurrenceEnd(occurrenceCount:)` |

规则预览最多展示前三个发生时间，并标明结束语义。

## 4. UI

### 新建 / 编辑非重复事件

```text
重复：每天 / 每周 / 每两周 / 每月 / 每年 / 不重复
结束：一直重复 / 到日期 / N 次
每日间隔、周几、每月规则：按所选模式展示
结束日期：DatePicker
```

- “每周 / 每两周”默认选中开始日星期，可多选周一到周日。
- “每月”支持每月日期和第 N 个周几。
- “每年”按事件开始日的月和日重复。
- 不重复时隐藏结束条件。

### 已有重复事件

详情和编辑页显示当前重复摘要。

编辑已有重复事件时先选择“仅此发生 / 此次及未来 / 整个系列”。仅此发生不改规则；后两者可编辑可表示规则。

保护态包括：

- 多条 recurrence rule。
- 多条 recurrence rule。
- BYSETPOS、负数位置、YEARLY BYDAY、复杂 EXDATE。
- 无法稳定映射到当前编辑模型的 EventKit 组件。
- EventKit 中无法稳定映射到 v1 模型的规则。

## 5. EventKit 映射

服务层写入策略：

```text
新建：
  draft -> EKRecurrenceRule

编辑非重复事件：
  draft -> EKRecurrenceRule

编辑已有重复事件：
  仅此发生 -> 不修改 recurrenceRules
  此次及未来 -> draft -> EKRecurrenceRule + future span
  整个系列 -> master -> draft -> EKRecurrenceRule
```

`EventRecurrenceDraft` 负责双向转换：

```swift
func makeRule(startDate: Date) -> EKRecurrenceRule?
init?(rules: [EKRecurrenceRule]?, startDate: Date)
previewOccurrences(startDate:)
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
| 共 8 次 | `每周 · 8 次` |
| 无法映射 | `较复杂的自定义重复（宜历暂不支持修改）` |

## 7. 错误与边界

| 边界 | 行为 |
|---|---|
| 仅此发生 | 重复 Picker 只读保护，规则不清空 |
| weekly 未选周几 | 禁止保存 |
| COUNT <= 0 | 禁止保存 |
| 事件只读 | 整体不可编辑 |
| 结束日期早于开始时间 | DatePicker 下限限制为开始日期 |
| 每月 31 日遇到短月 | 由系统日历按 EventKit 规则跳过不存在日期 |
| 重复规则保存失败 | 表单就地显示 EventKit 错误 |
| 用户取消编辑 | 不写入 recurrence rule |

## 8. 验收清单

- [x] 新建事件可选择不重复 / 每天 / 每周 / 每两周 / 每月 / 每年。
- [x] 选择重复后可设置“一直重复 / 到日期 / N 次”。
- [x] 不重复时结束条件隐藏。
- [x] `EKEvent.recurrenceRules` 按 draft 正确写入，映射层 6 项 XCTest 全绿。
- [x] 详情页显示重复摘要。
- [x] 已有重复事件可选择影响范围；复杂规则只读保护。
- [x] 保护态不会清空原规则。
- [x] 非重复事件可补充重复规则。
- [x] generic iOS Simulator 构建通过。

## 9. 后续演进

1. 复杂 RRULE 预览与只读解释。
2. 规则编辑冲突检测。
3. 农历生日重复。
