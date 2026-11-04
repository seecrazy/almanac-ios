# Roadmap

> 设计基线：[事件创建](../design/event-creation.md) · [事件详情/编辑/删除](../design/event-detail-editing.md) · [事件提醒](../design/event-reminders.md) · [重复规则](../design/event-recurrence.md) · [多日历管理](../design/calendar-management.md) · [月视图交互](../design/month-interaction.md) · [视图矩阵](../design/views-navigation.md) · [事件搜索](../design/event-search.md) · [黄历面板](../design/almanac-panel.md) · [里程碑](../design/milestones.md) · [自然语言输入](../design/natural-language-input.md) · [官方节假日数据管道](../design/holiday-data-pipeline.md) · [设计系统](../design/design-system.md) · [历史蓝图恢复](../design/recovered-product-blueprint.md) · [设计差距清单](../design/design-gap.md)

## v1.0 MVP
- [x] 核心逻辑包：LunarKit / HolidayData / RecurrenceEngine
- [x] App 壳：Xcode 工程 + 月视图(农历/休班角标) + 日详情 + Tab 框架
- [x] 日历数据层：EventKit 只读接入（iOS 15/17 授权兼容；App 层数据后续再引入本地存储）
- [x] 月/日视图（农历、节日、调休角标、日程圆点、真实日程列表）
- [x] EventKit 写入 + 手动新建事件（标题/全天/起止时间/地点/备注/目标日历）
- [x] EventKit 事件详情 / 编辑 / 删除（基础字段；重复日程支持范围选择）
- [x] EventKit 单条提醒（不提醒 / 准时 / 提前 5、15、30、60 分钟 / 1 天；自定义提醒默认保留）
- [x] EventKit 基础重复规则（每天 / 每周 / 每两周 / 每月 / 每年；复杂规则只读保护）
- [x] 多日历筛选与颜色（读取日历来源 / 颜色；月视图多色圆点；显示 / 隐藏本地持久化）
- [x] 月视图滑动手势 + 周起始日设置（周一 / 周日；本地持久化）
- [x] 事件搜索 v1（标题 / 地点 / 备注；过去 180 天至未来 365 天；最多 100 条）
- [x] 里程碑模型 + 本地列表（全天 / 时刻；创建 / 编辑 / 删除；本地持久化；日详情横幅）
- [ ] 自然语言输入 v1
  - [x] 设计与 ADR 已落文档
  - [x] `NaturalInput` 纯逻辑解析包 + 13 项 XCTest
  - [x] 月视图输入框、解析警告展示与现有表单预填
  - [x] SwiftPM 全量测试 + generic iOS Simulator build
  - [ ] GUI / 真机中文输入验收
- [x] 里程碑倒计时（列表 + 日视图横幅 + 锁屏组件）
  - [x] 本地里程碑基础闭环已完成
  - [x] 本地通知提醒
  - [x] 桌面 small / medium Widget
  - [x] 锁屏 circular / inline / rectangular Widget
- [ ] 阳历 / 农历生日与纪念日
  - [x] `MilestoneKit` Anniversary 模型、校验、下一次发生 Resolver 与 6 项新增 XCTest
  - [x] 阳历 / 农历日期、闰月三种 fallback、年龄 / 周年计数
  - [x] 倒计时页区块、创建 / 编辑 / 删除、日详情横幅
  - [x] 本地提醒与统一通知重建；通知拒绝不阻塞保存
  - [ ] GUI / 真机人工验收

## v1.1
- [ ] 事件搜索 v2
  - [x] `EventSearchKit` 查询模型、范围解析、730 天限制与最近搜索去重
  - [x] 未来 7 / 30 天、近 90 天、自定义范围与临时日历筛选
  - [x] 最多 200 条、300ms 防抖、旧请求保护与结果元信息
  - [ ] GUI / 真机人工验收
- [ ] 官方节假日数据管道
  - [x] manifest + 多年度 JSON 加载
  - [x] 2026–2027 sample 数据、跨年 `nextHoliday` 与覆盖状态
  - [x] 日期 / 冲突 / source 校验与失败降级
  - [x] App 区分 official / sample / estimated，并展示未覆盖状态
  - [ ] 用国务院官方通知替换 sample 数据
- [x] 重复规则完整编辑
  - [x] `EventKitMapping` 映射包 + 6 项 XCTest
  - [x] 每日间隔、周几多选、每月日期 / 第 N 个周几
  - [x] 一直重复 / 到日期 / N 次与前三项预览
  - [x] 仅此发生 / 此次及未来 / 整个系列编辑和删除
  - [x] 复杂规则只读保护
- [x] 里程碑提醒与小组件
  - [x] `MilestoneKit` 快照与通知请求模型 + 4 项 XCTest
  - [x] 四类本地通知提醒与 60 天调度窗口
  - [x] App Group 快照 `Widgets/milestone-widget-snapshot.json`
  - [x] Widget extension：桌面 small / medium + 锁屏 circular / inline / rectangular
  - [ ] 通知实际响铃与 Widget 添加人工验收（按当前决策暂跳过）
- [x] 日 / 周 / 年 / 议程视图
  - [x] 顶部月 / 周 / 日 / 议程 / 年分段导航，视图模式本地持久化
  - [x] 共享选中日期、可见月份、日历筛选与 EventKit 数据流
  - [x] 周视图 7 天 / 农历 / 事件摘要与左右滑动
  - [x] 日视图前后切换、农历 / 干支 / 节假日、里程碑与新建入口
  - [x] 议程 30 / 60 / 90 天、按日分组、500 条渲染上限与加载更多
  - [x] 年视图 12 个迷你月、今日 / 休班 / 事件点，点击进入月视图
- [ ] 黄历面板（宜忌/干支/冲煞，查表+规则生成）
  - [x] `LunarKit` 年 / 月 / 日干支、生肖、建除十二神、冲煞与 JSON 宜忌规则
  - [x] 24 个高频宜忌项、同一活动优先归忌、规则损坏降级与农历越界提示
  - [x] 日详情折叠面板、设置开关与 LunarKit XCTest
  - [ ] GUI / 真机人工验收
- [ ] 农历生日（闰月规则）
- [ ] 智能闹钟：工作日/休息日（调休感知）
- [ ] 桌面大组件、倒计时模板
- [ ] 联系人生日导入

## v1.2
- [ ] 公司政策引擎（模板 + 公司码分发）
- [ ] Live Activity 秒级倒计时
- [ ] 多级自定义提醒

## v2.0+
自然语言问答 · 年度报告 · 日记 · Android（KMP，见 ADR-007）

## 明确不做
社交信息流 / 云端日程 AI 分析 / 广告

## 设计文档状态

- [x] 设计系统 v0.1：色彩、字体、布局、月格/日详情/创建表单状态
- [x] 事件创建 v1：入口、字段模型、授权数据流、状态与验收清单
- [x] 事件详情 / 编辑 / 删除 v1：入口、字段映射、重复日程边界、状态与验收清单
- [x] 事件提醒 v1：预设映射、自定义提醒保护、详情展示与验收清单
- [x] 事件重复规则 v1：基础预设、EventKit 映射、复杂规则保护与验收清单
- [x] 多日历管理 v1：日历列表、颜色、来源分组、显示 / 隐藏与验收清单
- [x] 月视图交互 v1：滑动手势、周起始日设置与验收清单
- [x] 事件搜索 v1：时间窗、字段范围、防抖、结果列表与验收清单
- [x] 事件搜索 v2：日期范围、临时日历筛选、最近搜索与结果边界
- [x] 黄历面板 v1：干支 / 冲煞 / 建除十二神、JSON 宜忌、折叠展示与越界提示
- [x] 农历生日 / 纪念日 v1：Anniversary 模型、闰月 fallback、倒计时区块与提醒
- [x] 里程碑 v1：数据模型、精度策略、本地持久化、列表编辑和日详情横幅
- [x] 自然语言输入 v1：本地规则表、表单确认流、解析边界与验收清单
- [x] 官方节假日数据管道 v1：manifest、多年度加载、来源标注、覆盖状态与校验降级
- [x] 重复规则完整编辑与系列操作 v1：可表示规则映射、范围选择与预览
- [x] 里程碑提醒与小组件 v1：四类提醒、快照与基础 Widget
- [x] 日 / 周 / 年 / 议程视图 v1：共享状态、分段导航与基础视图矩阵
- [x] 历史设计恢复：核心日历、中国日历、里程碑、闹钟、迁移、日记、智能、打包与跨平台
- [x] 设计 vs 实现差距清单：区分已实现、部分实现、未实现
- [x] 翻页与手势设计
- [x] 自然语言输入规则表 UI/UX
- [x] 里程碑提醒与小组件设计
- [ ] 多条自定义提醒 UI 设计
- [ ] WorkdayResolver / SyncProvider ADR
