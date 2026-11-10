# 工作日智能闹钟设计 v1.2

状态：v1.4 响铃体验已接入（2026-11-10：全屏响铃页 / 长铃声 / timeSensitive / 铃声试听 / 保存状态反馈）；真机响铃与闹钟 GUI 验收待完成<br>
架构依据：[ADR-007](../architecture/adr/ADR-007-cross-platform.md) · [ADR-009](../architecture/adr/ADR-009-workday-alarm.md)
关联设计：[官方节假日数据管道](holiday-data-pipeline.md)

## 1. 目标

按「工作日」模板和法定节假日 / 调休数据，为最多 8 个闹钟生成未来 60 天实际触发计划。`工作日` 底层映射为周一至周五，但官方休息日优先关闭、官方补班日优先开启。

启用语义 v1.3：

- 工作日规则没有启用 / 禁用状态；规则只决定日期判定。
- 是否响铃只由每个闹钟自己的 `isEnabled` 决定。
- 不再有全局闹钟总开关。
- 任意启用中的闹钟触发授权请求；全部关闭时只清理 pending 通知。

## 2. 非目标 v1

- 不写系统时钟 App。
- 不做公司政策引擎。
- 不做云同步。
- 不做专注模式穿透配置。
- 不承诺通知触发秒级精确。
- 不申请 Critical Alert；静音键、勿扰和系统通知设置仍按 iOS 规则生效。

## 3. 纯逻辑模型

新增 `WorkdayResolver`：

```swift
public struct WorkdayTemplate: Codable, Hashable {
    public var kind: WorkdayTemplateKind
    public var customWeekdays: Set<Int>
}

public enum WorkdayTemplateKind: String, Codable, CaseIterable {
    case standardFiveDay
    case singleRestDay
    case sixDayWeek
    case custom
}

public struct WorkdayPlan: Hashable {
    public let date: Date
    public let baseIsWorkday: Bool
    public let holidayAdjustment: HolidayAdjustment?
    public let shouldRing: Bool
    public let reason: String
    public let holidayCoverage: HolidayCoverage
}

public struct WorkdayAlarm: Codable, Hashable {
    public let id: UUID
    public var name: String
    public var time: Date
    public var soundID: String
    public var isEnabled: Bool
}

public struct WorkdayAlarmOccurrence: Hashable {
    public let alarm: WorkdayAlarm
    public let plan: WorkdayPlan
    public let fireDate: Date
}

public enum WorkdayAlarmPlanner {
    public static let maximumAlarmCount = 8

    public static func occurrences(
        alarms: [WorkdayAlarm],
        template: WorkdayTemplate,
        holidays: HolidayStore,
        from reference: Date,
        days: Int = WorkdayResolver.maximumPlanDays,
        calendar: Calendar = .current
    ) -> [WorkdayAlarmOccurrence]
}
```

判定优先级：

1. 官方 `workday`：必须响铃。
2. 官方 `restDay`：必须不响。
3. 用户模板。
4. 无节假日覆盖时按模板，并标记 `unknownHoliday`。
- 同一天多个已启用闹钟分别触发，按实际时间升序展示。
- 铃声 ID 只保存在闹钟模型；节假日判定不依赖铃声。

## 4. 输入 / 输出

输入：

```swift
resolver.plan(
    from: Date,
    days: 60,
    template: WorkdayTemplate,
    holidays: HolidayStore
) -> [WorkdayPlan]
```

输出每天：

| 字段 | 说明 |
|---|---|
| `baseIsWorkday` | 模板原始结果 |
| `holidayAdjustment` | 官方休 / 班 |
| `shouldRing` | 最终是否响铃 |
| `reason` | 用户可读原因 |
| `holidayCoverage` | 数据覆盖状态 |

原因示例：

```text
法定休息日，闹钟关闭
调休补班日，闹钟开启
周六，闹钟关闭
周三，闹钟开启
节假日数据未覆盖，按模板执行
```

## 5. UI 流程

独立 `闹钟` 页签替代设置页入口，页面结构固定为：

1. 大标题 `闹钟` 与副标题 `法定休息日自动静默，调休补班日自动开启`。
2. 顶部规则卡：默认选中 `工作日`；其余提供单休、六天工作、自定义。规则卡没有总开关，只负责选择日期判定口径。`工作日` 即周一至周五，并叠加官方休 / 班优先级。
3. 闹钟列表：大号圆角时间、名称、独立开关；展开后编辑名称 / 时间 / 铃声。
4. 底部「下一次响铃」高亮卡与未来 60 天触发列表。
5. 通知授权状态内联展示。

视觉规则：

- 使用宜历纸感 / 赭金 token，不使用系统 Form 默认灰组。
- 时间使用 rounded 等宽数字，未启用闹钟降低不透明度。
- 展开卡片、规则卡、预览卡分别使用连续背景和 18–22pt 圆角。
- 添加按钮固定在列表尾部，达到 8 个上限后禁用并说明原因。

预览列表每天一行：

```text
11月5日 周四 07:30 上班闹钟 · 周四，闹钟开启
11月7日 周六 08:00 补班闹钟 · 调休补班日，闹钟开启
11月8日 周日 —— 法定休息日，闹钟关闭（不进入即将触发）
```

## 6. 通知调度

通知 ID：

```text
workday-alarm.<alarmID>.yyyy-MM-dd
```

只调度未来 60 天内 `shouldRing == true` 的日期。

限制：

- 节假日数据更新后重算。
- 模板变化后重算。
- 时区变化后重算。
- 全部闹钟关闭后取消全部。
- 单个闹钟开关只影响该闹钟；修改规则会影响所有启用中的闹钟。
- 每个闹钟每天最多一次；全局最多 8 个闹钟。
- 每个闹钟可独立选择铃声：默认 / 清晨钟声 / 双响脉冲 / 轻快铃。
- 里程碑与智能闹钟按 `milestone.` / `workday-alarm.` 前缀隔离重建，互不清空。

铃声实现：

- 自定义铃声必须是主 App bundle 内的 30 秒内 `caf` 音频。
- 前台通过 `UNUserNotificationCenterDelegate.willPresent` 返回 `banner`、`list` 和 `sound`。
- 后台 / 锁屏由系统读取通知 content sound。
- 无 Critical Alert entitlement，不绕过静音键或勿扰。

## 7. 边界

| 场景 | 行为 |
|---|---|
| 2027 无节假日数据 | 按模板，行内显示“未覆盖” |
| sample 数据 | 预览标注“示例数据” |
| 权限拒绝 | 计划仍可查看，不能调度 |
| 跨时区 | 展示使用设备时区；节假日日期判定固定 Asia/Shanghai |
| custom 模板为空 | 允许保存，但响铃预览为空 |
| 闹钟超过 8 个 | 新增按钮禁用 |
| 名称空白 | 保存 / 调度时显示为“闹钟” |
| 铃声文件缺失或损坏 | 设置仍可保存；调度降级为系统 default 声音 |
| 静音键 / 勿扰打开 | 不绕过；预览和 pending 请求仍正确 |

## 8. 验收清单

- [x] WorkdayResolver 纯逻辑包无 UI / EventKit 依赖。
- [x] 工作日（底层标准双休）计划正确。（XCTest 已覆盖）
- [x] 单休计划正确。（XCTest 已覆盖）
- [x] 六天工作计划正确。（XCTest 已覆盖）
- [x] 自定义周几正确。（XCTest 已覆盖）
- [x] 法定休覆盖模板。（XCTest 已覆盖）
- [x] 官方补班覆盖模板。（XCTest 已覆盖）
- [x] 未来 60 天预览正确。（XCTest 已覆盖上限与上海日期；GUI 验收待完成）
- [x] 数据未覆盖时标记 unknown。（XCTest 已覆盖）
- [x] 通知权限拒绝不崩溃。（代码已接入；真机验收待完成）
- [x] 模板变化后重算并取消旧通知。（代码已接入；真机验收待完成）
- [x] 同一模板最多 8 个闹钟，每个闹钟独立派生 60 天计划。
- [x] 法定休息日关闭全部已启用闹钟；调休补班日开启全部已启用闹钟。
- [x] 预览显示实际触发时间与闹钟名称，只把 `shouldRing` 日期计入即将触发。
- [x] 默认模板在 UI 中命名为 `工作日`，明确表达周一至周五 + 官方休班语义。
- [x] 智能闹钟从设置页迁移为独立页签；设置页不再保留重复入口。
- [x] 工作日规则与闹钟启用解耦；规则卡不再有总开关。
- [x] 通知调度只读取每个闹钟的独立开关。
- [x] 前台通知代理返回声音与横幅；App 内置铃声资源随主 App 打包。

## 9. 当前落地说明

- `WorkdayResolver` 位于 `HolidayData`，复用 `HolidayStore.effect(for:)`、`coverage(for:)` 和固定 `Asia/Shanghai` 语义。
- 独立闹钟页签提供模板、最多 8 个闹钟、铃声选择、通知授权状态和未来 60 天实际触发预览；设置持久化为 `workday.alarm.alarms.v3`。
- v1 的 `workday.alarm.settings.v1` 读取后迁移为单个默认闹钟；旧通知 ID 会被前缀重建清理。
- App 层为每个已启用闹钟的 `shouldRing` 且未来计划创建本地通知；全部闹钟关闭或权限拒绝时清理本功能前缀。
- `UNUserNotificationCenterDelegate` 在 App 启动时挂载，前台通知补横幅与声音。
- 里程碑通知同步同样只清理 `milestone.` 前缀，避免两个功能互相覆盖。
- 通知响铃、跨时区修改和真机权限路径仍需人工验收。

## 10. v1.4 响铃体验（2026-11-10）

用户反馈两个问题：到点只见表针横幅不"响"；选铃声无法试听、修改保存无感知。根因与对策：

| 问题 | 根因 | 对策 |
|---|---|---|
| 到点不响 | 通知自带声音受静音键 / 专注模式约束，且内置铃声仅 ~2 秒 | 三管齐下（见下） |
| 试听缺失 | Picker 仅写值不播音 | 选中即 `AVAudioPlayer` 试听一次（ambient 会话，尊重静音键） |
| 保存无感知 | 自动保存无任何可见反馈 | 卡片副标题显示「下次响铃 M月d日 HH:mm」；展开区显示「修改自动保存 · 下次响铃 …」；不启用 / 不触发各有明确文案 |

响铃链路：

1. **铃声加长**：三个内置 caf 重新合成为 29 秒（IMA4，约 670KB/个），通知自身可连续响近 30 秒；
2. **timeSensitive**：通知 `interruptionLevel = .timeSensitive`，可穿透专注模式（用户首次需在系统提示中允许）；
3. **全屏响铃页**（`AlarmRingingController` + `AlarmRingingView`）：
   - 触发点：前台到点（`willPresent`）与用户点按通知（`didReceive`），按 `workday-alarm.` 前缀识别，经通知 `userInfo`（alarmName / soundID）还原上下文；
   - `AVAudioSession` **`.playback`** 类别循环播放所选铃声——该类别**无视静音键**，是"会响"的关键；系统默认音无法由 AVAudioPlayer 播放，响铃回退「轻快铃」；
   - 停止 / 稍后提醒（5 分钟后单条即时通知，复用前缀与声音，再次进入响铃链路）；
   - 前台触发时横幅本身不带系统音，避免与循环铃声叠加。

边界：App 被杀死且用户不点通知时，仅通知自身响（受静音键约束）——iOS 本地通知的能力边界，响铃页在该路径下靠"点按即响"补足。

验收清单：

- [x] 29 秒铃声 ×3 打进主包；通知 timeSensitive + userInfo
- [x] willPresent / didReceive → 全屏响铃页（playback 循环、无视静音键）
- [x] 停止 / 稍后提醒 5 分钟
- [x] 选铃声即时试听；卡片与展开区的下次响铃 / 保存状态文案
- [x] generic iOS Simulator build 通过
- [ ] 真机静音键 / 专注模式 / 锁屏点按路径人工验收
