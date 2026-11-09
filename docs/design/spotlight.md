# Spotlight 集成 v1

状态：已实现（2026-11-09）。关联：[日记](diary.md)、[里程碑](milestones.md)。

## 目标与非目标

目标：里程碑 / 纪念日按标题进入系统 Spotlight；日记按日期进入（加密正文绝不入系统索引）。命中后冷 / 热启动都能回到对应内容。

非目标：

- 不索引日程（系统日历由系统自己索引）；
- 不索引日记正文关键词（隐私红线，见 ADR-011）；
- 不做 Handoff / 其它 NSUserActivity 类型。

## 数据 / 状态模型

`SpotlightIndexer`（App 层）：

- domain `com.yili.almanac.spotlight`；
- 里程碑条目：`milestone.<uuid>`，标题 + 分类描述 + 关键词；纪念日：`anniversary.<uuid>`；两者在 `MilestoneStore.refreshPlatformState` 时全量重建（数据量小，替换最可靠）；
- 日记条目：`diary.<yyyy-MM-dd>`，仅日期 + 心情描述；保存 / 删除时增删。

`AppRouter`（App 层 ObservableObject）：Tab 选择 + 三个深链载荷（milestoneID / anniversaryID / diaryDate）。`RootView` 通过 `.onContinueUserActivity(CSSearchableItemActionType)` 解析标识并路由：

- 里程碑 / 纪念日 → 倒计时 Tab 并打开对应编辑器；
- 日记 → 日历 Tab 并打开该日详情（日记横幅在详情内）。

## 边界与错误状态

- 索引失败静默（Spotlight 不可用不阻塞主流程）；
- 深链目标已被删除：路由后查不到即忽略；
- 标识格式非法：忽略。

## 验收清单

- [x] 里程碑 / 纪念日保存后重建索引；日记保存 / 删除增删索引
- [x] Spotlight 命中 → 对应 Tab + 详情 / 编辑器
- [x] 日记正文不出现在任何索引字段
- [x] generic iOS Simulator build 通过
