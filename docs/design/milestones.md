# 里程碑倒计时 v1

状态：基础闭环已实现；提醒与小组件由 [milestone-reminders-widgets.md](milestone-reminders-widgets.md) 接管（2026-11-04）
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md)
关联设计：[设计系统](design-system.md) · [月视图交互](month-interaction.md)

## 1. 目标

- 建立 App 层 `Milestone` 数据模型，替换静态“高考”样卡。
- 支持创建、查看、编辑、删除里程碑。
- 支持日期型里程碑和时刻型里程碑。
- 倒计时列表按紧急程度排序。
- 日详情中展示当天发生的里程碑横幅。
- v1 使用本地 JSON / `UserDefaults` 持久化。

## 2. 非目标 v1（基础闭环边界）

- 不写入 EventKit。
- 不做 Live Activity。
- 不做重复里程碑。
- 不引入 SQLite / GRDB。
- 不做云同步。

## 3. 数据模型

```swift
struct Milestone: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var targetDate: Date
    var isAllDay: Bool
    var category: MilestoneCategory
    var notes: String
    var createdAt: Date
}

enum MilestoneCategory: String, Codable, CaseIterable {
    case exam
    case project
    case travel
    case anniversary
    case custom
}
```

存储：

- `UserDefaults` key：`milestones.v1`
- JSONEncoder / JSONDecoder
- `dateEncodingStrategy = .iso8601`

SQLite / GRDB 仍留在后续版本；v1 只解决模型和交互闭环。

## 4. 精度策略

| 类型 | 展示 |
|---|---|
| 全天日期 | 只显示天：今天 / 明天 / N 天 |
| 时刻型，超过 7 天 | N 天 |
| 时刻型，1–7 天 | N 天 H 小时 |
| 时刻型，24 小时内 | HH:mm:ss |
| 已过期 | 已开始 / 已过去 N 天 |

列表在前台每秒刷新一次；如果当前只有全天里程碑，则每分钟刷新。

## 5. 列表排序

1. 时刻型按目标时间升序。
2. 全天型按当天开始时间升序。
3. 未完成优先于已完成。

## 6. 编辑字段

| 字段 | 必填 | 说明 |
|---|---:|---|
| 标题 | 是 | 首尾空白清理；为空禁用保存 |
| 目标日期 / 时间 | 是 | 全天只显示日期 |
| 类型 | 是 | 考试 / 项目 / 出行 / 纪念日 / 自定义 |
| 备注 | 否 | v1 单行文本 |
| 全天 | 否 | 默认开启 |

## 7. 列表 UI

- 顶部：标题 + 新建按钮。
- 空态：说明可添加中考、高考、项目发布、旅行、纪念日。
- 卡片：类型图标、标题、目标日期、倒计时、备注。
- 操作：点击卡片进入编辑。
- 编辑页支持保存和删除，删除需要确认。

## 8. 日详情横幅

如果选中日期命中里程碑：

| 类型 | 命中规则 |
|---|---|
| 全天 | 目标日期与选中日同一天 |
| 时刻型 | 目标时间与选中日在同一天 |

横幅显示标题、类型和倒计时状态。

## 9. 验收清单

- [x] generic iOS Simulator 构建通过。
- [ ] 倒计时页不再显示静态假数据。
- [ ] 可创建全天里程碑。
- [ ] 可创建时刻型里程碑。
- [ ] 可编辑和删除里程碑。
- [ ] 删除需要确认。
- [ ] 数据本地持久化。
- [ ] 重启后里程碑保留。
- [ ] 列表按紧急程度排序。
- [ ] 时刻型倒计时的秒数可见。
- [ ] 日详情展示当天里程碑横幅。

## 10. 后续演进

1. SQLite / GRDB 持久化。
1. Live Activity。
2. 重复里程碑。
3. 颜色与模板自定义。
4. SQLite / GRDB。
