# 设计与实现差距清单

状态：2026-11-09 审计（平台能力批次后刷新）。
范围：`docs/design/recovered-product-blueprint.md` + 现有 ADR + 当前代码

图例：✅ 已实现 · 🟡 部分实现 · 🔴 未实现

## 1. 总览

| 设计域 | 状态 | 当前事实 |
|---|---|---|
| EventKit 只读 | ✅ | 月份读取、月历圆点、日详情列表 |
| EventKit 多日历筛选 | ✅ | 日历列表、颜色、来源分组、显示 / 隐藏、本地持久化；月视图最多 3 色圆点 |
| EventKit 搜索 v2 | ✅ | `EventSearchKit` 预设 / 自定义日期范围、临时日历筛选、最近搜索、200 条上限与请求保护；GUI / 真机验收待完成 |
| 搜索本地索引 | ✅ | SQLite FTS5 批量重建、指纹跳过重建、结构化过滤、CJK LIKE 兜底、**拼音全拼 / 首字母（CFStringTransform）**、schema v2 自动迁移已接入；故障注入验收、模糊纠错和复杂查询未实现 |
| 月视图基础交互 | ✅ | 左右滑动翻月；周一起始 / 周日起始设置本地持久化；**周模式收起 / 展开 + 选中日日程列表** |
| 里程碑基础闭环 | ✅ | `Milestone` 模型、本地 JSON 持久化、列表、创建 / 编辑 / 删除、日详情横幅已实现 |
| 农历生日 / 纪念日 | ✅ | Anniversary 模型、Resolver、三种闰月 fallback、年龄 / 周年、倒计时区块、提醒、**通讯录生日导入**与日详情横幅已接入；GUI / 真机验收未完成 |
| 自然语言创建 v1 | ✅ | `NaturalInput` 本地规则表解析 + 13 项测试；月视图输入框预填；**App Intents「记日程」+ App Shortcuts** 已接入；GUI / 真机验收、自然语言问答、复杂表达未实现 |
| EventKit 写入 | ✅ | 手动创建标题/全天/时间/地点/备注/目标日历 |
| EventKit 编辑删除 | ✅ | 详情页可编辑标题/时间/全天/地点/备注/日历，可删除；重复日程支持仅此 / 未来 / 系列范围；**单事件 .ics 分享** |
| EventKit 单条提醒 | 🟡 | 新建/编辑支持不提醒、准时、提前 5/15/30/60 分钟、1 天；详情可展示。多条/自定义提醒默认保留，GUI 验收待完成 |
| EventKit 基础重复规则 | ✅ | 新建/编辑支持基础频率、间隔、周几多选、每月规则和三种结束方式 |
| Xcode 工程 | ✅ | Xcode 27.2 generic simulator build 通过；**AppTests unit-test target + 共享 scheme TestAction 跑通（模拟器 5 项）** |
| 核心引擎测试 | ✅ | LunarKit 22 / HolidayData 20 / RecurrenceEngine 6 / NaturalInput 13 / EventKitMapping 12 / MilestoneKit 15 / EventSearchKit 12 / CalendarAnalysis 7 / DiaryKit 6 |
| 设计系统 | 🟡 | token 和月格/日详情/创建表单基线已文档化；组件覆盖不全 |
| 农历基础 | 🟡 | 公历↔农历、闰月、干支、生肖、月视图文本已实现；月柱为农历月近似，节气月柱未精确计算 |
| 节假日 | ✅ | 2026 / 2027 official、跨年查询、覆盖状态与来源提示；**联网自动更新（ADR-013：双源拉取 + 校验 + 缓存覆盖 + 设置页手动检查）**；真机联网路径验收待做 |
| 完整重复规则 | ✅ | 自定义周几、COUNT 结束、系列编辑、规则预览和复杂规则只读保护已接入；RRULE 手输与复杂规则解释未实现 |
| 里程碑平台能力 | ✅ | 四类本地提醒、桌面 small / medium Widget、锁屏 circular / inline / rectangular Widget、**Live Activity（16.1 门控）**已接入；SQLite、模板和颜色自定义未实现 |
| Widget 矩阵 | ✅ | 里程碑 + **日程（桌面 small / medium、锁屏 inline / rectangular）**两组 Widget；交互式 Widget 与 deep link 未实现 |
| 农历节日 | 🟡 | 10 个常见节日、除夕动态推导与月 / 周 / 日展示已接入；GUI / 真机验收未完成 |
| 智能闹钟 | 🟡 | 独立页签、规则与闹钟启用解耦、工作日模板、官方休 / 班优先级、最多 8 个闹钟、独立时间 / 开关、4 种铃声、**64 条通知配额三路预留与激活重排**、高保真列表 / 下次响铃预览、旧设置迁移与前台声音代理已接入；**v1.4 响铃 + v1.5 后台保活（UIBackgroundModes 已产物级验证）+ v1.6 九种铃声与时钟式选择页已接入**；真机静音键 / 专注模式 / 锁屏点按与 GUI 验收未完成 |
| 公司政策引擎 | 🔴 | 无规则模型、模板、公司码分发 |
| 本地 SQLite / GRDB | 🟡 | 搜索派生索引已使用系统 SQLite FTS5；GRDB 与其他 App 层持久化未引入 |
| CloudKit / SyncProvider | 🔴 | 未实现 |
| 手动导出导入 | ✅ | 单事件 .ics 分享 + **备份导出/导入 v0（里程碑/纪念日/闹钟 JSON，按 id 去重合并）**；日记因加密待 SyncProvider |
| 日记 | 🟡 | `DiaryKit` 模型、AES-256-GCM 加密 SQLite、Keychain 密钥、日程骨架、心情 / 正文、日详情入口、历史列表与查看 / 修改 / 删除、**Spotlight 日期索引（正文永不入索引）**已接入；照片 / 语音 / 独立密码 / FTS / CloudKit / 导出未实现，GUI / 真机验收未完成 |
| 完整多视图 | ✅ | 月 / 年 / 议程 / **周模式**视图、滑动手势、月点日详情、周末 / 法定休班底色角标、今天和年 / 月 / 日三列跳转、**iPad 双栏**已接入；导航 GUI / 真机验收未完成 |
| 每日简报 | ✅ | 14 天预排（农历 / 节日 / 节气 / 宜忌）、设置页开关与时间选择；真机响铃验收未完成 |
| Spotlight | ✅ | 里程碑 / 纪念日按标题、日记按日期；深链路由到对应 Tab 与编辑器 / 日详情 |
| 无障碍专项 | 🟡 | **Dynamic Type 正文适配 v1**（EventRow / 日详情 / 设置页）；逐屏 VoiceOver audit 与大字号走查未完成 |
| Watch | 🟡 | ADR-012 + **代码侧就绪**（WatchBriefingSnapshot 契约、iOS 写入器、staging 页面与复杂功能、GUI 步骤）；target 待 Xcode GUI 创建 |
| 天气 / 任务 / 差旅 | 🔴 | 未实现 |
| 邀请 / RSVP | 🔴 | 未实现 |
| 冲突检测 | 🟡 | `CalendarAnalysis` 冲突组、全天处理、跨日裁剪、新建冲突提醒、日详情冲突摘要与日视图空闲时段已接入；GUI / 真机验收未完成 |
| 性能 | ✅ | DateFormatter 缓存、bundled 单例、年视图单次拉取、议程分组缓存、事件匹配后台线程、索引指纹复用（见 performance-optimizations.md） |
| CI | ✅ | GitHub Actions 三 job（包测试 / App 构建 / App 单测） |
| Android 预留 | 🟡 | 架构原则和 ADR-007 已定；NaturalInput 与规则引擎外没有更多落地 |

## 2. MVP 内最高优先缺口

按“补上后产品才像完整日历”排序：

1. **搜索升级**：SQLite FTS5 可重建索引已接入；增量更新、拼音 / 模糊纠错、复杂查询与故障注入验收未实现。
2. **中国日历差异化**：黄历面板、生日 / 纪念日、二十四节气与农历节日已接入；地方性 / 少数民族节日未实现。
3. **里程碑平台升级**：Live Activity、SQLite / GRDB、模板与颜色自定义。
4. **2027 官方节假日数据替换**：当前只能保留显式 sample，等待官方通知。

## 3. v1.1 / v1.2 主要缺口

| 领域 | 缺口 |
|---|---|
| 中国日历 | 二十四节气、农历节日与生日 / 纪念日 / 黄历面板待 GUI 验收 |
| 智能闹钟 | 真机响铃、铃声资源、跨时区与闹钟 GUI / 真机验收 |
| 公司政策 | 模板、公司码、版本更新、大小周、月末周六 |
| 平台能力 | Live Activity、App Intents、Shortcuts |
| 里程碑 | 模板、颜色自定义、SQLite / GRDB、Live Activity |
| 数据 | GRDB、CloudKit、SyncProvider、ICS/JSON 导入导出 |
| 日历 | 复杂 RRULE 只读解释、订阅与账户批量管理；本机日历管理和冲突检测已进入基础实现 |
| 搜索 | 增量索引、拼音 / 模糊纠错、复杂查询、故障注入验收；v2 与基础 SQLite FTS 已接入 |
| 日历管理 | 订阅管理、账户批量筛选、颜色修改；本机创建 / 重命名 / 删除已接入 |
| 智能 | NLP 创建、本地问答、场景提醒、年度报告 |

## 4. 文档已恢复但从未落码的高价值设计

这些内容之前只存在于会话中，现已归档到 `recovered-product-blueprint.md`：

1. CloudKit + 系统备份 + 加密导出的三路迁移方案。
2. 里程碑 `auto` 精度策略和秒级展示边界。
3. 智能闹钟 60 天响铃计划预览已落码。
4. 公司政策引擎和公司码分发。
5. 日记自动生成日程骨架。
6. 本地自然语言问答。
7. 去年今天、年度报告、倒计时分享卡。
8. 完整日历核心能力矩阵：多视图、时区、搜索、邀请、冲突检测、任务桥接。

## 5. 下一步文档动作

1. 把 MVP 缺口拆成可验收的 PR 系列。
2. 为多条提醒和 Live Activity 补实现细节。
3. 为 `SyncProvider` 写一份 ADR。
4. 把 `design-gap.md` 纳入每次 milestone 结束时刷新。
| 年度回顾 | ✅ | CalendarAnalysis 统计引擎（6 项 XCTest）+ 设置页入口 + 文本分享；日记心情曲线未含 |
| 深链 | ✅ | almanac:// scheme + 两族 Widget widgetURL + AppRouter 路由（AppTests 覆盖） |
| UI 冒烟 | ✅ | XCUITest 四页签可达，接入 scheme 与 CI |
