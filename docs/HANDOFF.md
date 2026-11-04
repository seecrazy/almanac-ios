# 会话交接 / 项目现状（Handoff）

> 最后更新：2026-11-04（D-161 农历生日 / 纪念日代码接入） · 供新会话冷启动使用
> 设计来源：产品设计讨论（本文只记录结论与状态，讨论细节见 ADR 与 roadmap）

## 一句话现状

**设计闭环、工程可构建**：七个 SwiftPM 包 XCTest 全绿（60 个测试），SwiftUI App 壳与 Milestone Widget extension 已通过 Xcode 27.2 iOS Simulator 构建；EventKit 只读、手动新建、自然语言创建 v1、事件详情、基础字段编辑、删除、单条提醒、完整重复规则编辑与系列操作、多日历筛选 / 颜色、月 / 周 / 日 / 议程 / 年基础视图矩阵、搜索 v2、里程碑基础闭环、农历生日 / 纪念日、里程碑提醒与小组件、D-110 节假日多年度数据管道、D-160 黄历面板基础闭环已接入。用户已决定暂跳过人工验收，先推进 v1.1 编码；D-100 / D-101 / D-150 / D-160 / D-161 仍保留 GUI / 真机待验收。

## 已完成（截至 2026-11-04 工作树）

| 模块 | 状态 | 验证方式 |
|------|------|----------|
| 文档体系 | ✅ README / roadmap / HANDOFF / ADR-001(EventKit) / ADR-007(跨平台) / ADR-008(自然语言输入) / design-system / event-creation / natural-language-input / event-detail-editing / event-reminders / event-recurrence / recurrence-series-editing / views-navigation / holiday-data-pipeline / milestone-reminders-widgets / calendar-management / month-interaction / event-search / event-search-v2 / almanac-panel / milestones | 内容与当前工作树状态一致 |
| 历史设计 | ✅ `recovered-product-blueprint.md` 恢复核心日历、中国日历、里程碑、闹钟、迁移、日记、智能与跨平台设计 | 来源 Codex rollout `01a19205-ad9f-7731-a10f-fd3c511941d1` |
| 设计差距 | ✅ `design-gap.md` 区分 ✅ / 🟡 / 🔴 | 每次里程碑结束应刷新 |
| LunarKit | ✅ 1900-2100 农历换算、闰月、干支、生肖、月视图文本、黄历规则与宜忌 | 14 项 XCTest 全绿（春节/中秋锚点、1949-10-01 甲子日、往返一致性、冲煞 / 宜忌 / 边界） |
| HolidayData | ✅ manifest + 年度 JSON（2026/2027 sample）+ 跨年查询；来源 / 覆盖状态 / 校验降级；`bundled()` 与 `bundled(years:)` | 12 项 XCTest 全绿 |
| RecurrenceEngine | ✅ 周期步进展开器：d/w/m/y + interval/count/until/EXDATE | 6 项 Sanity 全绿 |
| NaturalInput | ✅ 本地中文规则解析：相对/显式日期、时间区间、时长、全天、基础重复、地点 / 备注；JSON 规则表 | 13 项 XCTest 全绿 |
| EventKitMapping | ✅ `EventRecurrenceDraft` 与 `EKRecurrenceRule` 双向映射、可表示规则、COUNT/UNTIL、月规则、前三项预览、编辑范围模型 | 6 项 XCTest 全绿 |
| MilestoneKit | ✅ Widget 快照模型、7 天优先排序、8 条上限、四类提醒请求模型、60 天调度窗口、通知 ID 与正文、Anniversary Resolver 与闰月 fallback | 10 项 XCTest 全绿 |
| EventSearchKit | ✅ 查询模型、预设 / 自定义日期范围、730 天限制、最近搜索去重与 8 条上限 | 4 项 XCTest 全绿 |
| App 壳 | ✅ Xcode 工程 + 月视图(农历/休班/今日/日程圆点) + 日详情真实日程 + 倒计时列表 + 设置 | Xcode 27.2 iOS Simulator build ✅ |
| EventKit 读写 | ✅ `EventStoreService`、iOS 15/17 授权兼容、系统日历变更监听、月/日视图消费、手动新建事件、可写日历选择、事件详情、基础字段编辑、范围删除、单条提醒、多日历筛选 / 颜色、搜索数据源 | generic iOS Simulator build ✅；GUI / 真机验收待完成 |
| 月视图交互 | ✅ 左右滑动翻月；周一起始 / 周日起始设置；`UserDefaults` 持久化 | generic iOS Simulator build ✅；GUI / 真机验收待完成 |
| 里程碑 | ✅ `Milestone` 模型、JSON / `UserDefaults` 持久化、倒计时列表、创建 / 编辑 / 删除、日详情横幅；旧数据自动迁移 `reminders` | generic iOS Simulator build ✅；GUI / 真机验收待完成 |
| 自然语言创建 v1 | ✅ 月视图输入框 → 解析 → `AddEventView` 预填 → 用户确认保存；警告就地展示 | SwiftPM/XCTest 与 generic iOS Simulator build ✅；GUI / 真机中文输入验收待完成 |
| 节假日数据管道 D-110 | ✅ manifest 多年度加载、日期 / 冲突 / source 校验、`HolidayCoverage`、设置页来源展示、日详情未覆盖与 sample/estimated 提示、月视图弱化 estimated 角标 | HolidayData 12 项 XCTest + generic iOS Simulator build ✅；2026/2027 官方数据待替换 |
| 重复规则完整编辑 D-120 | ✅ 每日间隔、周几多选、每月日期 / 第 N 个周几、一直重复 / 到日期 / N 次、前三项预览、仅此发生 / 此次及未来 / 整个系列、复杂规则只读保护 | EventKitMapping 6 项 XCTest + generic iOS Simulator build ✅；GUI / 真机验收按当前决策暂跳过 |
| 里程碑提醒与小组件 D-130 | ✅ 四类本地通知提醒、60 天调度窗口、App Group 快照、桌面 small / medium Widget、锁屏 circular / inline / rectangular Widget、无数据 / 快照缺失 / 过期状态 | MilestoneKit 4 项 XCTest + generic iOS Simulator build ✅；通知响铃与 Widget 添加人工验收按当前决策暂跳过 |
| 基础视图矩阵 D-140 | ✅ 月 / 周 / 日 / 议程 / 年分段导航、视图模式持久化、共享选中日期与日历筛选、周滑动、日前后切换、议程 30/60/90 天与 500 条上限、年视图 12 迷你月与分批加载 | generic iOS Simulator build ✅；GUI / 真机人工验收按当前决策暂跳过 |
| 搜索 v2 D-150 | ✅ 未来 7/30 天、近 90 天、自定义范围、临时日历筛选、最近搜索、200 条上限、300ms 防抖与请求代际保护 | EventSearchKit 4 项 XCTest + generic iOS Simulator build ✅；GUI / 真机人工验收按当前决策暂跳过 |
| 黄历面板 D-160 | ✅ 年 / 月 / 日干支、生肖、建除十二神、冲煞、24 项 JSON 宜忌、折叠 / 展开、规则损坏降级与农历越界提示 | LunarKit 14 项 XCTest + generic iOS Simulator build ✅；GUI / 真机人工验收按当前决策暂跳过 |
| 农历生日 / 纪念日 D-161 | ✅ 阳历 / 农历模型、下一次发生 Resolver、闰月三种 fallback、年龄 / 周年、倒计时区块、编辑 / 删除、提醒统一调度、日详情横幅 | MilestoneKit 10 项 XCTest + generic iOS Simulator build ✅；GUI / 真机人工验收按当前决策暂跳过 |
| XCTest | ✅ LunarKit 14 / HolidayData 12 / RecurrenceEngine 6 / NaturalInput 13 / EventKitMapping 6 / MilestoneKit 10 / EventSearchKit 4 | `./build.sh test` 全绿 |

构建命令：`./build.sh test`（60 个 XCTest + 七包编译）。

## 环境与构建路径（重要）

- 已安装 **Xcode 27.2**（`/Applications/Xcode.app`），但 `xcode-select -p` 仍指向 Command Line Tools；命令行构建可直接使用完整路径：
  `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild`
- 七个 SwiftPM 包 manifest 均为 Swift tools 6.0，并设置 `swiftLanguageModes: [.v5]`；`./build.sh test` 已走 SwiftPM/XCTest 路径
- 手写 pbxproj 已修复三个会导致 Xcode 27 打不开的问题：本地包引用不应作为 main group children；App group path 必须是 `App/Almanac`；Swift tools 6.0 才接受现有 `executableTarget` 签名
- `.gitignore` 已停止忽略整个 `*.xcodeproj`，否则仓库实际不含 Xcode 工程；现在只忽略用户态数据
- App 与 Milestone Widget 均声明 App Group `group.com.yili.almanac.shared`；模拟器构建产物已包含对应 entitlement
- 真机/模拟器运行仍建议先打开 Xcode GUI 检查签名与 runtime

## 下一步（按优先级）

1. **D-170 WorkdayResolver 纯逻辑**：调休感知的工作日 / 休息日闹钟引擎（当前默认下一步）
2. **D-150 / D-160 / D-161 GUI / 真机验收**：按设计清单逐项勾选；用户当前可继续暂跳过
3. **官方节假日数据替换**：管道已完成；等待国务院 2026/2027 年度通知人工核对后替换 sample
4. **暂缓项**：D-100 / D-101 GUI 与真机验收、通知实际响铃与 Widget 添加验收、Live Activity、SQLite / GRDB、自然语言问答 / 英文输入 / 复杂表达、完整日历管理

## 设计结论速查（详见各文档）

- 日程源头：EventKit 读/写已接（ADR-001）；App 层数据后续用本地 SQLite
- 跨平台：UI 原生、逻辑零依赖、规则 JSON 化、同步协议化（ADR-007）
- 命名：产品「宜历」/ 仓库 almanac-ios / Bundle `com.yili.almanac`
- 设计 token：[docs/design/design-system.md](docs/design/design-system.md) 已建立 v0.1（纸感/墨感、朱砂/赭金/青瓷）
- 事件创建：[docs/design/event-creation.md](docs/design/event-creation.md) 记录入口、字段映射、授权流、状态和验收清单
- 自然语言输入：[docs/design/natural-language-input.md](docs/design/natural-language-input.md) 记录本地规则表、表单确认流和解析边界
- 事件详情 / 编辑 / 删除：[docs/design/event-detail-editing.md](docs/design/event-detail-editing.md) 记录重复日程边界、只读状态和刷新策略
- 事件提醒：[docs/design/event-reminders.md](docs/design/event-reminders.md) 记录单条提醒映射、自定义提醒保护和 v1 边界
- 重复规则：[docs/design/event-recurrence.md](docs/design/event-recurrence.md) 与 [recurrence-series-editing.md](docs/design/recurrence-series-editing.md) 记录完整规则、EventKit 映射、范围操作、复杂规则保护和 v1 边界
- 多日历管理：[docs/design/calendar-management.md](docs/design/calendar-management.md) 记录颜色、来源分组、显示 / 隐藏和持久化策略
- 月视图交互：[docs/design/month-interaction.md](docs/design/month-interaction.md) 记录手势阈值、周起始日和持久化策略
- 视图矩阵：[docs/design/views-navigation.md](docs/design/views-navigation.md) 记录月 / 周 / 日 / 议程 / 年导航、数据加载与手势
- 事件搜索：[docs/design/event-search.md](docs/design/event-search.md) 记录时间窗、字段范围、防抖和结果边界
- 事件搜索 v2：[docs/design/event-search-v2.md](docs/design/event-search-v2.md) 记录日期范围、临时日历筛选、最近搜索和 200 条上限
- 黄历面板：[docs/design/almanac-panel.md](docs/design/almanac-panel.md) 记录干支、建除十二神、冲煞、JSON 宜忌与越界提示
- 农历生日 / 纪念日：[docs/design/lunar-anniversaries.md](docs/design/lunar-anniversaries.md) 记录农历换算、闰月 fallback、年龄 / 周年与提醒
- 里程碑：[docs/design/milestones.md](docs/design/milestones.md) 与 [milestone-reminders-widgets.md](docs/design/milestone-reminders-widgets.md) 记录数据模型、精度策略、本地持久化、提醒和 Widget 边界
- 历史蓝图：[docs/design/recovered-product-blueprint.md](docs/design/recovered-product-blueprint.md) 汇总之前会话未落码设计
- 差距清单：[docs/design/design-gap.md](docs/design/design-gap.md) 是当前“文档设计 vs 代码实现”事实表
- 明确不做：社交流、云端日程 AI、广告

## 新会话接手姿势

**协作纪律**：讨论设计并决定开干时，先落设计文档；实现过程中同步更新设计、进展文档和 README。完整规则见仓库根目录 `AGENTS.md`。

```bash
cd ~/IdeaProjects/almanac-ios
git log --oneline        # 看提交
cat docs/product/roadmap.md   # 看进度
./build.sh test          # 确认 60 个 XCTest 仍全绿
```
