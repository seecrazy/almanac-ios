# 倒计时卡片 v1.1

状态：卡片型 UI 重构已确认（2026-11-05）；提醒与小组件由 [milestone-reminders-widgets.md](milestone-reminders-widgets.md) 接管
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md)
关联设计：[设计系统](design-system.md) · [月视图交互](month-interaction.md)

## 1. 目标

- 建立 App 层 `Milestone` 数据模型，替换静态“高考”样卡。
- 支持创建、查看、编辑、删除里程碑。
- 支持日期型里程碑和时刻型里程碑。
- 倒计时列表按紧急程度排序。
- 日详情中展示当天发生的里程碑横幅。
- v1 使用本地 JSON / `UserDefaults` 持久化。
- v1.1 将列表重构为卡片型 UI：倒计时数字是主视觉，类别与日期作为分层元信息。

## 2. 非目标 v1（基础闭环边界）

- 不写入 EventKit。
- 不做 Live Activity。
- 不做重复里程碑。
- 不引入 SQLite / GRDB。
- 不做云同步。
- 不做主题背景图、动态颜色编辑或社交分享模板。

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

## 7. 卡片型 UI

页面结构：

1. 顶部大标题 `倒计时`，右侧保留新建。
2. 统计条显示：`即将到来`、`今天`、`已过期` 三项数量。
3. 生日 / 纪念日独立卡片分组。
4. 里程碑卡片按时间升序，过去项保留最后。

里程碑卡片结构：

1. 顶部类别胶囊：emoji + 类别名；考试使用朱砂、项目使用青瓷、出行使用赭金、纪念日使用暖黄、自定义使用次级色。
2. 主标题一行；备注最多两行。
3. 中部显示 `目标日期 · 提醒 n 项`。
4. 右侧倒计时块：主数字 34–44pt，单位 12pt。
5. 今天 / 过期使用强调边框；过期数字降低透明度。
6. 点击整卡进入编辑；编辑页支持保存和删除，删除需要确认。

## 8. 日详情横幅

如果选中日期命中里程碑：

| 类型 | 命中规则 |
|---|---|
| 全天 | 目标日期与选中日同一天 |
| 时刻型 | 目标时间与选中日在同一天 |

横幅显示标题、类型和倒计时状态。

## 9. 验收清单

- [x] generic iOS Simulator 构建通过。
- [x] 倒计时页不再显示静态假数据。
- [x] 可创建全天里程碑。
- [x] 可创建时刻型里程碑。
- [x] 可编辑和删除里程碑。
- [x] 删除需要确认。
- [x] 数据本地持久化。
- [x] 重启后里程碑保留。
- [x] 列表按紧急程度排序。
- [x] 时刻型倒计时的秒数可见。
- [x] 日详情展示当天里程碑横幅。
- [x] 统计条、类别胶囊与分层倒计时卡片接入。

## 10. 后续演进

1. SQLite / GRDB 持久化。
1. Live Activity。
2. 重复里程碑。
3. 颜色与模板自定义。
4. SQLite / GRDB。

## 编辑器按钮布局 v1.1（2026-11-10）

参照系统时钟「编辑闹钟」范式重排（里程碑与生日 / 纪念日两个编辑器同步）：

- **保存**：导航栏右侧（confirmationAction），始终可见、拇指可达；不可保存时置灰，表单底部 footer 提示原因（标题为空等）；
- **删除**：表单底部独立 Section，左对齐红字 + trash 图标（系统风格），不再与保存并排居中；点击仍有二次确认；
- 新建模式不显示删除行。
