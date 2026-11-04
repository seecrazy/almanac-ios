# 事件创建设计 v1

状态：已实现手动创建基线；重复规则基础项由 [event-recurrence.md](event-recurrence.md) 接管（2026-11-01）；自然语言入口设计见 [natural-language-input.md](natural-language-input.md)。
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md)  
视觉基线：[design-system.md](design-system.md)

## 1. 目标

- 用户能把日程写入自己已有的 iCloud / Google / Exchange / 本地日历，不需要 App 自建同步。
- 保存后月视图和日详情立即反映系统日历事实。
- 表单足够短，让用户 10 秒内完成一条 MVP 日程。

## 2. 非 v1 目标

- 重复规则完整编辑；基础预设由 [event-recurrence.md](event-recurrence.md) 接管。
- 提醒规则完整编辑；单条预设由 [event-reminders.md](event-reminders.md) 接管。
- 跨日复杂时段。
- 参与人和会议室。

这些能力会进入后续版本；v1 表单字段必须保持可映射到 `RecurrenceEngine` 与未来提醒引擎。

## 3. 入口

| 入口 | 初始日期 | 场景 |
|---|---|---|
| 月视图右上角 `+` | 今天 | 快速建今日日程 |
| 日详情“今日日程”旁 `+` | 当前选中日期 | 看到某天空闲后立即补日程 |

两个入口打开同一个 `AddEventView`，避免维护两套表单语义。

## 4. 表单模型

| 表单字段 | 必填 | EventKit 映射 | 说明 |
|---|---:|---|---|
| 标题 | 是 | `EKEvent.title` | 空白字符会被清理；为空时禁用保存 |
| 全天 | 否 | `EKEvent.isAllDay` | 开启后只选择日期 |
| 开始时间 | 是 | `EKEvent.startDate` | 普通日程默认 09:00 |
| 结束时间 | 普通日程是 | `EKEvent.endDate` | 普通日程默认开始后 1 小时 |
| 地点 | 否 | `EKEvent.location` | 保存前清理空白 |
| 备注 | 否 | `EKEvent.notes` | v1 不做富文本 |
| 目标日历 | 是，有默认值 | `EKEvent.calendar` | 只列出可写日历 |
| 重复规则 | 否 | `EKEvent.recurrenceRules` | 不重复 / 每天 / 每周 / 每两周 / 每月 / 每年；可到日期结束 |

约束：

- 普通日程：`endDate > startDate`。
- 全天日程：开始日期取当日 `startOfDay`，结束时间取次日零点，符合 EventKit 的全天区间表达。

## 5. 授权与数据流

```text
入口点击
  → AddEventView onAppear
  → EventStoreService.loadWritableCalendars()
  → 读取默认日历
  → 用户编辑
  → saveEvent(...)
  → EKEventStore.save(...)
  → reloadIfNecessary()
  → MonthView / DayDetail 更新
```

授权兼容：

| 系统 | API | 说明 |
|---|---|---|
| iOS 15–16 | `requestAccess(to: .event)` | 授权后可读可写 |
| iOS 17+ | `requestFullAccessToEvents` | 当前 App 需要完整读写，因为月历要展示已有日程 |

当前 iOS 17 的 “Add Events Only / 只写权限” 不能支撑只读视图，因此被视作不可用状态；后续如果要支持只写模式，需要把读写授权拆成两个独立能力状态。

## 6. 状态设计

| 状态 | UI |
|---|---|
| 未授权 | 设置页提供“允许访问”；表单保存失败时显示具体原因 |
| 已授权但无可写日历 | 日历区显示“没有可写入日历”；保存失败提示 `noWritableCalendar` |
| 表单校验失败 | 标题为空禁用保存；结束时间错误显示就地错误 |
| 保存中 | 主按钮禁用并显示 `ProgressView` |
| 保存成功 | 关闭 sheet；EventKit 变更通知 + 主动刷新让视图更新 |
| EventKit 失败 | 显示系统错误描述，不覆盖成笼统失败 |

## 7. 验收清单

- [x] 月视图可进入创建表单。
- [x] 日详情可带着选中日期进入创建表单。
- [x] 标题为空时不能保存。
- [x] 普通日程结束时间不能早于开始时间。
- [x] 全天日程只暴露日期选择。
- [x] 只列出可写日历。
- [x] iOS 15 和 iOS 17+ 都能请求完整访问。
- [x] 保存后主动刷新已加载月份。
- [ ] 真机/iCloud 日历保存实测。
- [ ] 权限被拒后的系统设置跳转。

## 8. 下一步

1. 模拟器和真机实测 iCloud / 本地日历。
2. 权限拒绝状态增加“打开系统设置”。
3. 表单接入 [自然语言输入 v1](natural-language-input.md) 的解析草稿；仍由用户确认后保存。
4. 重复规则自定义周几、COUNT 结束和系列编辑。
