# 事件重复规则完整编辑与系列操作设计 v1

状态：代码已接入（2026-11-04；GUI / 真机人工验收按当前决策暂跳过）  
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md)  
关联设计：[事件重复规则 v1](event-recurrence.md) · [事件详情/编辑/删除](event-detail-editing.md)

## 1. 目标

- 支持编辑可表示的已有重复规则。
- 支持自定义周几。
- 支持按日期结束和按次数结束。
- 支持“仅此发生 / 此次及未来 / 整个系列”。
- 复杂规则进入只读保护，不猜测改写。

## 2. 非目标 v1

- 不支持 RRULE 字符串手输。
- 不支持农历重复。
- 不支持负数月日，例如每月倒数第二天。
- 不支持时区级重复语义改写。
- 不批量改写订阅日历中的只读事件。

## 3. 编辑器状态

```swift
struct RecurrenceEditorState {
    var frequency: RecurrenceFrequency
    var interval: Int
    var weekdays: Set<Weekday>
    var monthlyRule: MonthlyRule
    var end: RecurrenceEnd
    var endDate: Date
    var occurrenceCount: Int
    var canRepresent: Bool
}

enum RecurrenceFrequency {
    case none, daily, weekly, biweekly, monthly, yearly
}

enum MonthlyRule {
    case dayOfMonth(Int)
    case nthWeekday(week: Int, weekday: Int)
}

enum RecurrenceEnd {
    case never
    case onDate(Date)
    case afterCount(Int)
}
```

## 4. 可表示规则

| 规则 | 可编辑 |
|---|---|
| daily interval 1–999 | 是 |
| weekly interval 1/2，无或多个 BYDAY | 是 |
| monthly day-of-month | 是 |
| monthly nth weekday | 是 |
| yearly month/day | 是 |
| UNTIL 或 COUNT 单一结束方式 | 是 |
| BYSETPOS、复杂 BYMONTHDAY、负数位置、复杂 EXDATE、YEARLY BYDAY | 否，只读 |

无法表示时显示：

> 当前重复规则较复杂，宜历暂不支持修改。

保存时只允许修改非重复字段；重复字段保持原值。

## 5. 用户流程

### 新建

创建表单选择规则 → 预览前 3 次和结束语义 → 保存写入 EventKit。

### 编辑单次日程

如果原事件不重复，可添加规则；保存后变成重复系列。

### 编辑重复事件

进入详情后先选择范围：

| 选项 | 行为 | 语义 |
|---|---|---|
| 仅此发生 | 为该 occurrence 生成 exception | 其他发生不变 |
| 此次及未来 | `EKSpan.futureEvents` | 当前 occurrence 起生效 |
| 整个系列 | 修改 series master | 修改规则 / 字段 |

删除重复事件使用同一范围选择。

## 6. 规则预览

展示前 3 个发生时间：

```text
每周三 18:00，一直重复
下次：11月4日、11月11日、11月18日
```

| 结束 | 预览 |
|---|---|
| 一直重复 | `一直重复` |
| 到日期 | `重复至 2026年12月31日` |
| N 次 | `重复 8 次` |

预览由 `RecurrenceEngine` 展开，最多计算 100 个候选，禁止无限循环。

## 7. 冲突与错误

| 场景 | 行为 |
|---|---|
| EventKit 规则包含不支持组件 | 只读保护，禁用重复字段 |
| 结束日期早于开始日期 | 禁用保存并提示 |
| COUNT <= 0 | 禁用保存 |
| weekly 未选周几 | 使用开始日星期；用户清空全部选择则禁用保存 |
| 只读日历 | 禁用保存 |
| EventKit 保存失败 | 保留系统错误原文 |

## 8. 验收清单

- [x] 可编辑每日 / 每周 / 每两周 / 每月 / 每年基础规则。
- [x] weekly 可多选周一到周日。
- [x] monthly 支持按日期和第 N 个周几。
- [x] 支持一直重复、到日期、N 次。
- [x] 规则预览显示前三个发生时间和结束语义。
- [x] 已有重复事件可选择仅此发生 / 此次及未来 / 整个系列。
- [x] 删除重复事件可选择范围。
- [x] 不支持规则保持只读且不丢规则。
- [x] 保存失败保留表单并显示系统错误。
- [x] 映射层 XCTest 全绿（EventKitMapping 当前 8 项）。
- [x] Xcode iOS Simulator build 全绿。

## 9. 当前落地说明

- 新增 `Packages/EventKitMapping`，把 `EventRecurrenceDraft`、可表示性判断、EventKit 双向映射、规则预览和编辑范围模型从 UI 层抽出，便于 XCTest 覆盖。
- 新建表单支持每日间隔、周几多选、每月按日期 / 第 N 个周几、一直重复 / 到日期 / N 次。
- 编辑重复日程时先选择影响范围：仅此发生、此次及未来、整个系列。
- “仅此发生”保持原重复规则，只允许修改非重复字段；“此次及未来”使用 EventKit future span；“整个系列”查找 series master 后修改。
- `BYSETPOS`、负数月日、负数周序、YEARLY BYDAY、复杂 EXDATE 等不可稳定表达的规则进入 `.preserveExisting`，UI 显示复杂规则保护文案。
