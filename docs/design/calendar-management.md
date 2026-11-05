# 多日历管理 v1

状态：v1 已实现代码基线；v1.1 本机日历管理代码已接入，均待模拟器 / 真机验收（2026-11-05）
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md)  
关联设计：[事件创建](event-creation.md) · [事件详情/编辑/删除](event-detail-editing.md)

## 1. 目标

- 读取 EventKit 中当前账号可访问的事件日历。
- 显示每个日历的标题、来源和颜色。
- 用户可以按日历显示 / 隐藏日程。
- 月视图日程点使用日历颜色。
- 日详情日程卡左侧色条使用日历颜色。
- 隐藏状态本地持久化；新增日历默认显示。

## 2. 非目标 v1

- 不创建、重命名、删除系统日历。
- 不修改系统日历颜色。
- 不迁移或合并日历。
- 不按账户设置独立同步策略。
- 不做日历订阅管理。
- 不把筛选状态同步到 CloudKit。

## 3. 数据模型

```swift
struct CalendarColorComponents: Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
}

struct CalendarDisplayInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let sourceTitle: String
    let color: CalendarColorComponents
    let allowsContentModifications: Bool
    let isSubscribed: Bool
}
```

`CalendarEvent` 增加：

```swift
let calendarColor: CalendarColorComponents?
```

## 4. EventKit 读取

```swift
store.calendars(for: .event)
```

排序规则：

1. 来源标题，忽略大小写。
2. 日历标题，忽略大小写。

无颜色或颜色无法转换到 sRGB 的日历使用中性主题色兜底。

## 5. 显示 / 隐藏

### 默认状态

- 所有可访问日历默认显示。
- 用户隐藏后写入 `UserDefaults`。
- key：`hidden.event.calendar.identifiers`。
- 下次启动时与当前 EventKit 日历求交集，已删除的隐藏记录自动清理。

### 操作

| 操作 | 行为 |
|---|---|
| 开启某个日历 | 从隐藏集合移除 |
| 关闭某个日历 | 加入隐藏集合 |
| 全部显示 | 清空隐藏集合 |
| 最少保留 | UI 阻止关闭最后一个可见日历 |

## 6. 月视图

- 每天最多显示 3 个日程颜色点。
- 颜色按日历颜色去重。
- 若一天内超过 3 个可见日历有日程，仅显示前 3 个，不显示“更多”角标；v1 保持月格轻量。
- 隐藏日历不参与圆点计算。

## 7. 日详情

- `events(on:)` 只返回可见日历日程。
- 日程卡左侧色条使用日历颜色。
- 日历标题继续展示，方便用户确认来源。

## 8. 筛选入口与 UI

月视图头部新增“日历筛选”按钮。

筛选 sheet：

1. 顶部提供“全部显示”。
2. 日历按来源分组。
3. 每行显示颜色点、日历名、可写 / 订阅状态和 Toggle。
4. 最后一个可见日历的 Toggle 不可关闭。

## 9. 错误与边界

| 边界 | 行为 |
|---|---|
| 日历无颜色 | 使用主题色兜底 |
| 颜色空间无法转换 | 使用主题色兜底 |
| 隐藏记录指向已删除日历 | 自动清理 |
| 日历列表随系统变更 | 监听 `EKEventStoreChanged` 后刷新 |
| 用户隐藏所有日历 | UI 阻止；保持至少一个可见 |

## 10. 验收清单

- [x] generic iOS Simulator 构建通过。
- [ ] 可读取并展示事件日历列表。
- [ ] 日历按来源分组。
- [ ] 每个日历显示系统颜色。
- [ ] 隐藏日历后月视图圆点消失。
- [ ] 隐藏日历后日详情列表消失。
- [ ] 月视图最多显示 3 个颜色点。
- [ ] 颜色缺失时不崩溃并使用兜底色。
- [ ] 隐藏状态重启后保留。
- [ ] 新增日历默认显示。
- [ ] 最后一个可见日历不能被隐藏。

## 11. 后续演进

1. 日历管理入口迁移到设置页。
2. [本地日历管理 v1.1](local-calendar-management.md)：支持创建 / 重命名 / 删除本地日历。
3. 支持订阅日历。
4. 按账户批量显示 / 隐藏。
5. 将筛选状态纳入跨设备同步。
