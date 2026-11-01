# 事件提醒设计 v1

状态：已实现代码基线；待模拟器 / 真机验收（2026-11-01）  
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md)  
关联设计：[事件创建](event-creation.md) · [事件详情/编辑/删除](event-detail-editing.md)

## 1. 目标

- 新建日程时可以选择一条提醒。
- 编辑日程时可以查看、更换或移除提醒。
- 提醒通过 EventKit 写入系统日历，由系统日历 / 通知中心触发。
- 不自建一套与 EventKit 平行的提醒状态。

## 2. 非目标 v1

- 不支持多条提醒。
- 不支持自定义任意提前时间。
- 不支持提醒铃声、重复提醒、 snooze 规则。
- 不修改系统闹钟。
- 不为提醒单独请求通知权限；EventKit 日历提醒由系统日历链路触发。

## 3. 提醒选项

| UI 选项 | 语义 | EventKit 映射 |
|---|---|---|
| 不提醒 | 移除本 App 写入的提醒 | `alarms = nil` |
| 准时 | 事件开始时提醒 | `EKAlarm(relativeOffset: 0)` |
| 提前 5 分钟 | 开始前 5 分钟 | `relativeOffset: -300` |
| 提前 15 分钟 | 开始前 15 分钟 | `relativeOffset: -900` |
| 提前 30 分钟 | 开始前 30 分钟 | `relativeOffset: -1800` |
| 提前 1 小时 | 开始前 60 分钟 | `relativeOffset: -3600` |
| 提前 1 天 | 开始前 24 小时 | `relativeOffset: -86400` |
| 保留现有提醒 | 只读保护态 | 不修改 `EKEvent.alarms` |

默认值：

| 场景 | 默认 |
|---|---|
| 新建日程 | 不提醒 |
| 现有无提醒日程 | 不提醒 |
| 现有日程只有一条可识别的相对提醒 | 映射到对应选项 |
| 现有日程包含多条、绝对时间或无法识别的提醒 | 保留现有提醒 |

## 4. 数据与 UI 模型

```swift
enum EventReminderOption: Hashable, CaseIterable, Identifiable {
    case none
    case atStart
    case minutesBefore(Int)
    case preserveExisting
}
```

`CalendarEvent` 增加只读展示字段：

```swift
let reminderSummary: String
let hasUnsupportedAlarms: Bool
```

编辑表单使用单选 `Picker`。

- 普通可写事件显示全部预设。
- 已有无法安全归一化的提醒时，默认选中“保留现有提醒”。
- 用户没有主动更换选项时，保存流程不得清空原有提醒。

## 5. 写入策略

### 新建

```text
option == none                  -> alarms = nil
option == preserveExisting      -> 不可能出现；新建页不展示
其他                            -> alarms = [EKAlarm(relativeOffset: offset)]
```

### 编辑

```text
option == preserveExisting      -> 不读写 alarms，保持原数组
option == none                  -> alarms = nil
其他                            -> alarms = [EKAlarm(relativeOffset: offset)]
```

服务层签名采用显式参数：

```swift
func updateEvent(
    ...,
    reminderOption: EventReminderOption
) async throws
```

`saveEvent` 同理。

## 6. 展示规则

详情页：

| 状态 | 展示 |
|---|---|
| 无提醒 | “不提醒” |
| 准时 | “事件开始时” |
| 提前 5/15/30/60 分钟 | 对应预设文案 |
| 提前 1 天 | “提前 1 天” |
| 多条或不可识别 | “系统自定义提醒（宜历 v1 不修改）” |

编辑页：

- 显示同一个 Picker。
- 只读日历不显示提醒编辑控件。
- `preserveExisting` 项只在现有事件包含无法安全归一化提醒时出现。

## 7. 错误与边界

| 边界 | 行为 |
|---|---|
| 事件只读 | 不显示提醒编辑；不发起 EventKit 写请求 |
| 现有多条提醒 | 默认保留，不自动合并或删除 |
| 现有绝对时间提醒 | 默认保留，不转换成相对提醒 |
| 用户选择“不提醒” | 显式清空全部提醒 |
| EventKit 保存失败 | 表单就地显示系统错误 |
| 全天日程 | 仍使用相对开始时间的提醒；v1 不做“前一天 20:00”特殊推导 |

## 8. 验收清单

- [x] generic iOS Simulator 构建通过。
- [ ] 新建事件可选择“不提醒 / 准时 / 提前 5 / 15 / 30 / 60 分钟 / 提前 1 天”。
- [ ] 新建选择提醒后，`EKEvent.alarms` 包含一条正确 offset。
- [ ] 编辑无提醒事件可增加提醒。
- [ ] 编辑已有一条可识别提醒事件时，Picker 正确回显。
- [ ] 更换提醒会替换原有单条提醒。
- [ ] 选择“不提醒”会清空提醒。
- [ ] 多条 / 自定义提醒默认不被覆盖。
- [ ] 用户显式更换提醒后，原有多条提醒被替换为一条新提醒。
- [ ] 只读事件不显示提醒编辑控件。

## 9. 后续演进

1. 多条提醒管理。
2. 自定义提前时间。
3. 全天日程的“前一天 20:00”模式。
4. 提醒权限与系统通知状态诊断。
5. 自然语言输入映射：“提前一天提醒我”。
