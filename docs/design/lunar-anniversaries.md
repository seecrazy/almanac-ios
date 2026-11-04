# 农历生日 / 纪念日设计 v1

状态：设计已冻结（2026-11-02）  
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md)  
关联设计：[里程碑 v1](milestones.md) · [里程碑提醒与小组件](milestone-reminders-widgets.md)

## 1. 目标

支持阳历和农历生日、纪念日、忌日；每年自动换算公历日期，并可显示年龄 / 周年。

## 2. 非目标 v1

- 不做个人八字。
- 不做联系人自动批量导入；只支持手动添加。
- 不写入 EventKit 作为事实源。
- 不做云端同步。

## 3. 数据模型

```swift
enum AnniversaryKind: String, Codable {
    case birthday, memorial, wedding, custom
}

enum AnniversaryCalendar: String, Codable {
    case solar, lunar
}

struct LunarDateSpec: Codable, Hashable {
    var month: Int
    var day: Int
    var isLeapMonth: Bool
}

struct Anniversary: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var personName: String?
    var kind: AnniversaryKind
    var calendar: AnniversaryCalendar
    var solarDate: DateComponents?
    var lunarDate: LunarDateSpec?
    var leapMonthFallback: LeapMonthFallback
    var showAge: Bool
    var showAnniversaryYears: Bool
    var reminders: [MilestoneReminder]
    var notes: String
}

enum LeapMonthFallback: String, Codable, CaseIterable {
    case previousCommonMonth
    case nextCommonMonth
    case skipYear
}
```

约束：

- `calendar == .solar` 时必须有 `solarDate`。
- `calendar == .lunar` 时必须有 `lunarDate`。
- 农历闰月必须显式 `isLeapMonth`，不自动近似。
- `personName` 只用于文案，不请求联系人权限。

## 4. 农历换算

下一次发生规则：

1. 从今天开始查找下一年度对应农历日期。
2. 如果目标年份无该闰月，按用户选择的 fallback 处理。
3. `previousCommonMonth` 是默认。
4. 换算结果固定使用 `Asia/Shanghai`。
5. 保存时同时保留 `originalSpec` 和最近一次 `resolvedDate`。

年龄 / 周年：

| 类型 | 展示 |
|---|---|
| 生日 | `28 岁` 或 `出生第 28 年` |
| 结婚纪念日 | `第 10 年` |
| 纪念日 / 忌日 | `第 5 年` |
| 农历生日 | 按农历年计数，不用公历周年混算 |

## 5. 提醒

复用里程碑提醒模型：

- 提前 7 天 09:00。
- 提前 1 天 09:00。
- 当天 09:00。

通知标题按类型：

| 类型 | 文案 |
|---|---|
| birthday | `今天是张三的生日` |
| wedding | `今天是结婚 10 周年` |
| memorial | `今天是李四的纪念日` |
| custom | `今天是自定义纪念日` |

每年换算成功后重新调度通知。

## 6. UI

倒计时页新增 `生日 / 纪念日` 区块：

- 列表按下一次公历日期升序。
- 卡片显示类型图标、标题、农历或阳历日期、下一次日期、年龄 / 周年。
- 编辑字段：标题、对象、类型、阳历/农历切换、日期、闰月开关、备注、提醒。
- 日详情命中当天 anniversary 时显示横幅。

## 7. 错误与边界

| 场景 | 行为 |
|---|---|
| 农历换算失败 | 显示 `日期暂不可用`，保留原数据 |
| 闰月不存在 | 按 fallback 显示并解释 |
| 出生年份早于 1900 | 允许保存纪念日，但年龄显示“超出农历支持范围” |
| 通知未授权 | 数据保存成功，提醒状态显示未授权 |
| 删除 | 取消所有本地通知 |

## 8. 验收清单

- [ ] 可创建阳历生日。
- [ ] 可创建农历生日。
- [ ] 农历闰月必须显式选择。
- [ ] 闰月不存在时按 fallback 换算。
- [ ] 每年下一次日期自动更新。
- [ ] 年龄 / 周年显示正确。
- [ ] 日详情显示当天 anniversary。
- [ ] 提醒可开启 / 关闭。
- [ ] 通知授权拒绝不阻塞保存。
- [ ] 删除后通知取消。
- [ ] XCTest 覆盖平年、闰月存在、闰月缺失、跨年换算。
