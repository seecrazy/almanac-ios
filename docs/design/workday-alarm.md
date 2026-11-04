# 工作日智能闹钟设计 v1

状态：设计已冻结；先实现纯逻辑引擎（2026-11-02）  
架构依据：[ADR-007](../architecture/adr/ADR-007-cross-platform.md)  
关联设计：[官方节假日数据管道](holiday-data-pipeline.md)

## 1. 目标

按用户工作日模板和法定节假日 / 调休数据，生成未来 60 天闹钟计划。

## 2. 非目标 v1

- 不写系统时钟 App。
- 不做公司政策引擎。
- 不做云同步。
- 不做专注模式穿透配置。
- 不承诺通知触发秒级精确。

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
```

判定优先级：

1. 官方 `workday`：必须响铃。
2. 官方 `restDay`：必须不响。
3. 用户模板。
4. 无节假日覆盖时按模板，并标记 `unknownHoliday`。

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

设置页新增 `智能闹钟`：

1. 模板：标准双休 / 单休 / 六天工作 / 自定义周几。
2. 响铃时间。
3. 通知开关。
4. 未来 60 天预览。

预览列表每天一行：

```text
11月4日 周三  07:30  开
11月7日 周六  关闭  法定休息日
11月8日 周日  07:30  调休补班日
```

## 6. 通知调度

通知 ID：

```text
workday-alarm.yyyy-MM-dd
```

只调度未来 60 天内 `shouldRing == true` 的日期。

限制：

- 节假日数据更新后重算。
- 模板变化后重算。
- 时区变化后重算。
- 用户关闭总开关后取消全部。
- 每天最多一个智能闹钟。

## 7. 边界

| 场景 | 行为 |
|---|---|
| 2027 无节假日数据 | 按模板，行内显示“未覆盖” |
| sample 数据 | 预览标注“示例数据” |
| 权限拒绝 | 计划仍可查看，不能调度 |
| 跨时区 | 展示使用设备时区；节假日日期判定固定 Asia/Shanghai |
| custom 模板为空 | 允许保存，但响铃预览为空 |

## 8. 验收清单

- [ ] WorkdayResolver 纯逻辑包无 UI / EventKit 依赖。
- [ ] 标准双休计划正确。
- [ ] 单休计划正确。
- [ ] 六天工作计划正确。
- [ ] 自定义周几正确。
- [ ] 法定休覆盖模板。
- [ ] 官方补班覆盖模板。
- [ ] 未来 60 天预览正确。
- [ ] 数据未覆盖时标记 unknown。
- [ ] 通知权限拒绝不崩溃。
- [ ] 模板变化后重算并取消旧通知。
