# 里程碑提醒与小组件设计 v1

状态：代码已接入（2026-11-04；GUI / 真机人工验收按当前决策暂跳过）  
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md)  
关联设计：[里程碑 v1](milestones.md)

## 1. 目标

- 里程碑可配置提前提醒。
- 提醒由本地通知调度，不写入 EventKit。
- 提供桌面 Widget 和锁屏 Widget 的静态倒计时。
- Widget 与 App 使用同一个只读快照数据。

## 2. 非目标 v1

- 不做 Live Activity / 灵动岛。
- 不做云同步。
- 不引入 SQLite。
- 不做 Widget 内编辑。
- 不承诺通知秒级精确触发。

## 3. 数据模型扩展

在现有 `Milestone` 上新增：

```swift
struct MilestoneReminder: Codable, Hashable {
    var kind: MilestoneReminderKind
    var isEnabled: Bool
}

enum MilestoneReminderKind: String, Codable, CaseIterable {
    case sevenDaysAtNine
    case oneDayAtNine
    case sameDayAtNine
    case sameDayAtTarget
}
```

迁移规则：

- 旧数据没有 `reminders` 字段时补默认空数组。
- 通知授权状态不改变本地数据。
- 删除里程碑时取消全部待通知。

## 4. App 数据快照

新增 App Group：

```text
group.com.yili.almanac.shared
```

文件：

```text
Widgets/milestone-widget-snapshot.json
```

快照最多保留 8 个：

1. 未来 7 天内最早的目标。
2. 之后按目标时间升序补齐。

快照字段：

| 字段 | 说明 |
|---|---|
| `version` | 数据版本 |
| `generatedAt` | 上次写入时间 |
| `milestones` | id / title / targetDate / isAllDay / category |

每次里程碑变化、通知授权变化、App 前台进入时重写。

## 5. Widget 展示

| family | 内容 |
|---|---|
| systemSmall | 最近 1 个：标题 + 天数 / 时间 |
| systemMedium | 最近 1 个主卡片 + 后 2 个紧凑列表 |
| accessoryCircular | 最近 1 个标题缩写 + 天数 |
| accessoryInline | `高考 · 180天` |
| accessoryRectangular | 标题 + 类型 + 倒计时 |

规则：

- 全天里程碑只显示天。
- 时刻型 24 小时内可使用系统 `Text(timerInterval:)`。
- Widget timeline 每 15 分钟到 1 小时刷新；目标日 0 点、目标时刻、提醒时间必须重建 timeline。
- 无里程碑显示“添加第一个倒计时”。
- 快照过期或缺失显示“打开宜历更新数据”。

## 6. 提醒调度

通知 ID：

```text
milestone.<uuid>.<reminderKind>
```

标题：`倒计时提醒`  
副标题：里程碑标题  
正文：

| kind | 正文 |
|---|---|
| sevenDaysAtNine | `距离「高考」还有 7 天` |
| oneDayAtNine | `明天是「高考」` |
| sameDayAtNine | `今天是「高考」` |
| sameDayAtTarget | `「高考」时间到了` |

限制：

- 只调度未来 60 天内的通知。
- 同一里程碑最多 4 条。
- 目标时间已过期时不再调度。
- 授权拒绝时表单仍可保存，但显示“通知未授权”。

## 7. 错误与边界

| 场景 | 行为 |
|---|---|
| 通知权限未决定 | 保存里程碑后请求权限 |
| 权限拒绝 | 数据保存成功；列表显示提醒状态 |
| App Group 不可用 | App 内功能正常；Widget 显示快照缺失 |
| milestone 数据损坏 | 丢弃快照并显示更新提示，不崩溃 |
| 删除里程碑 | 取消通知并重建快照 |

## 8. 验收清单

- [x] 可开启 / 关闭四类提醒。
- [ ] 授权成功后按计划收到本地通知（真机 / 模拟器人工验收暂跳过）。
- [x] 授权拒绝时数据不会丢失，表单和列表显示通知未授权。
- [x] 删除里程碑后重建通知计划，待通知会被取消。
- [x] App Group 快照写入代码接入；模拟器构建产物包含 App Group entitlement。
- [x] 新增 Widget extension target `MilestoneWidget`。
- [ ] 桌面 small / medium Widget 可添加（人工验收暂跳过）。
- [ ] 锁屏 circular / inline / rectangular 可添加（人工验收暂跳过）。
- [x] Widget 无里程碑、快照缺失、已过期状态有独立视图。
- [x] 全天里程碑不显示时分秒。
- [x] App 删除数据后重建快照，Widget 下次 timeline 不再显示该条。
- [x] XCTest 覆盖快照生成和通知请求模型（MilestoneKit 4 项）。

## 9. 当前落地说明

- 新增 `Packages/MilestoneKit`：快照模型、8 条上限与 7 天优先排序、4 类提醒请求模型、60 天调度窗口、通知 ID 与正文生成。
- `Milestone` 新增 `reminders` 字段，旧 JSON 缺字段时自动迁移为空数组。
- App 新增 `MilestonePlatformService`：读取通知授权、请求授权、重建待通知、写入 App Group 快照。
- 保存 / 删除里程碑和 App 回到前台都会重建快照；保存启用提醒的里程碑时才请求通知权限。
- 新增 `MilestoneWidget.appex`，支持 `systemSmall`、`systemMedium`、`accessoryCircular`、`accessoryInline`、`accessoryRectangular`。
- Widget timeline 常规 15 分钟刷新，并在目标日 0 点、目标时刻、潜在 09:00 提醒点后重建。
- App 与 Widget 都声明 `group.com.yili.almanac.shared`。
