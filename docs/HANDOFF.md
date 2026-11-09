# 会话交接 / 项目现状（Handoff）

> 最后更新：2026-11-09（平台能力批次：通知配额修复 / 性能六项 / 日程 Widget / 周模式 / 每日简报 / .ics 分享 / Spotlight / 拼音搜索 / App Intents / 联系人生日导入 / Live Activity / Dynamic Type / iPad 双栏 / AppTests + CI） · 供新会话冷启动使用
> 设计来源：产品设计讨论（本文只记录结论与状态，讨论细节见 ADR 与 roadmap）

## 一句话现状

**设计闭环、工程可构建、测试扩容**：九个 SwiftPM 包 XCTest 全绿（113 项），新增 App 层 XCTest（AppTests target，模拟器 5 项），generic iOS Simulator build 通过；在既有 v1.1 能力之上完成"平台能力批次"——通知配额三路预留与重排、六项性能修复、日程小组件四族、月视图周模式、每日简报、单事件 .ics 分享、Spotlight 深链、拼音搜索、App Intents 快捷指令、联系人生日导入、Live Activity 秒级倒计时、Dynamic Type 正文适配、iPad 双栏、CI。全部功能仍待 GUI / 真机人工验收。

## 已完成（截至 2026-11-09 工作树）

| 模块 | 状态 | 验证方式 |
|------|------|----------|
| 文档体系 | ✅ README / roadmap / HANDOFF / ADR-001/007/008/009/010/011/**012(Watch)** / 全部设计文档（新增 notification-budget / performance-optimizations / schedule-widget / week-mode / daily-briefing / event-sharing / spotlight / pinyin-search / app-intents / contacts-birthdays / live-activity / dynamic-type / ipad-adaptation） | 内容与当前工作树状态一致 |
| LunarKit | ✅ 1900-2100 农历、干支、节气、节日、黄历 + **每日简报组装 AlmanacBriefingComposer**、`bundledShared` 单例 | 22 项 XCTest 全绿 |
| HolidayData | ✅ 多年度节假日管道、WorkdayResolver、闹钟计划 + **NotificationBudgetPlanner（64 条三路预留）**、`bundledShared` | 20 项 XCTest 全绿 |
| RecurrenceEngine | ✅ RFC 5545 子集展开 | 6 项 XCTest 全绿 |
| NaturalInput | ✅ 中文自然语言解析 | 13 项 XCTest 全绿 |
| EventKitMapping | ✅ 重复规则双向映射 + **ICSExporter（RFC 5545 单事件导出）** | 12 项 XCTest 全绿 |
| MilestoneKit | ✅ 快照 / 提醒 / Anniversary + **日程 Widget 快照**、**联系人生日映射**、**Live Activity Attributes** | 15 项 XCTest 全绿 |
| EventSearchKit | ✅ 搜索 v2 + SQLite FTS5 + **指纹跳过重建**、**拼音全拼 / 首字母列与 schema v2 迁移** | 12 项 XCTest 全绿 |
| CalendarAnalysis | ✅ 冲突 / 空闲 | 7 项 XCTest 全绿 |
| DiaryKit | ✅ 加密日记 | 6 项 XCTest 全绿 |
| App 壳 | ✅ 月 / 年 / 议程 / **周模式**、**iPad 双栏**、**Dynamic Type 正文**、搜索、闹钟、倒计时、日记、设置 | generic iOS Simulator build ✅ |
| 通知可靠性 | ✅ 64 条配额三路预留（闹钟 / 里程碑 / 简报互相实测对方占用）；App 激活 + 显著时间变化重排；闹钟 store 提升为 App 级（无需进闹钟页即重排）；闹钟页显示"计划 N / 调度 M" | HolidayData 20 项 + build ✅；真机响铃验收待做 |
| 性能 | ✅ AppFormatters 缓存（body 内 DateFormatter 清零）、bundledShared、年视图单次拉取、议程分组缓存、事件匹配后台线程、索引指纹复用 | EventSearchKit 指纹测试 + build ✅ |
| 日程 Widget | ✅ 桌面 small / medium + 锁屏 inline / rectangular；App Group 快照随 loadEvents / 激活写入 | MilestoneKit 2 项 + build ✅；Widget 添加验收待做 |
| 每日简报 | ✅ 14 天预排（农历 / 节日 / 节气 / 宜忌，内容日期确定性）；设置页开关 + 时间 | LunarKit 3 项 + build ✅ |
| .ics 分享 | ✅ 详情页分享按钮；CRLF / 转义 / 全天 VALUE=DATE / UTC 时刻 | EventKitMapping 4 项 + build ✅ |
| Spotlight | ✅ 里程碑 / 纪念日按标题、日记按日期（正文永不入索引）；深链 → 对应 Tab + 编辑器 / 日详情 | AppTests 路由测试 4 项 ✅ |
| 拼音搜索 | ✅ CFStringTransform 全拼 / 首字母；ASCII 关键词 9 列 LIKE；schema v2 自动迁移 | EventSearchKit 5 项 ✅ |
| App Intents | ✅ 「记日程」AppIntent + App Shortcuts 短语（iOS 16 门控）→ 月视图确认流 | build ✅；Siri / 快捷指令真机验收待做 |
| 联系人生日导入 | ✅ 倒计时页导入入口；CNContact 授权 + 勾选导入；无年份 / 非法日期 / 重复处理 | MilestoneKit 3 项 + build ✅；真机通讯录验收待做 |
| Live Activity | ✅ 24h 内时刻里程碑锁屏 / 灵动岛秒级倒计时（16.1 门控；MilestoneKit 条件编译不破坏 macOS 包测试） | build ✅；真机灵动岛验收待做 |
| 工程质量 | ✅ AppTests unit-test target（模拟器 5 项，共享 scheme Test action）；GitHub Actions 三 job（包测试 / App 构建 / App 单测） | xcodebuild test TEST SUCCEEDED ✅ |

构建与验证命令：

```bash
./build.sh test                                                    # 113 项包 XCTest
xcodebuild test -scheme Almanac -destination 'platform=iOS Simulator,name=iPhone 18 Pro'   # App 层 5 项
```

## 本批次关键工程决策（详见对应设计文档 / ADR）

1. **通知配额**（notification-budget.md）：预留采用"调度时实测对方前缀占用"而非固定配额；裁剪保最早触发。
2. **周视图**（week-mode.md）：不设独立页签，月视图收起为单周 + 日程列表；手势按主导轴与横滑翻月互斥。
3. **简报**（daily-briefing.md）：内容必须"日期确定性"才可预排——因此不含日程条数；占 ≤14 条配额。
4. **拼音**（pinyin-search.md）：FTS5 MATCH 不能与列级 OR 混用，纯字母关键词改走 9 列 LIKE；转写分段处理混合文本。
5. **Watch**（ADR-012）：watch target 必须在 Xcode GUI 创建（embed / WKCompanion 关系不适合手写 pbxproj），代码侧方案已定（复用纯逻辑包 + App Group 快照）。
6. **Live Activity**：iOS 16.1 API（ActivityContent 需 16.2，用旧式 contentState API 兼容 16.1）；MilestoneKit 内 `#if canImport(ActivityKit) && os(iOS)`（macOS 15 可 import ActivityKit 但类型不可用）。
7. **iPad**：`horizontalSizeClass == .regular` 双栏；iPhone 行为零变化。

## 环境与构建路径（重要）

- Xcode 27.2（`/Applications/Xcode.app`）；`xcode-select -p` 指向完整 Xcode
- pbxproj 手写维护：本批次新增文件沿用 `7A111111…02xx` 合成 UUID 段；**AppTests target（0280-0291 段）与共享 scheme 的 TestAction 已手工接入并跑通**
- App Group `group.com.yili.almanac.shared`：里程碑 / 日程两份快照 + （Watch 落地后）简报快照
- 模拟器：iOS 27.2 运行时（iPhone 18 Pro 等已就绪）

## 下一步（按优先级）

1. **GUI / 真机人工验收批次**（本批次全部功能 + 此前遗留 D-140~D-210）：Widget 添加、灵动岛、Siri / 快捷指令、通讯录导入、大字号走查、iPad 双栏、闹钟真机响铃
2. **2027 官方节假日数据替换**：等待国务院通知
3. **Watch App 落地**：按 ADR-012 在 Xcode GUI 建 target（人工步骤）
4. **SyncProvider ADR**：CloudKit / 备份 / 导入导出抽象仍未成文
5. **暂缓**：BGTaskScheduler 后台重排、多条自定义提醒、公司政策引擎、年度报告、自然语言问答

## 新会话接手姿势

**协作纪律**：讨论设计并决定开干时，先落设计文档；实现过程中同步更新设计、进展文档和 README。完整规则见仓库根目录 `AGENTS.md`。

```bash
cd ~/IdeaProjects/almanac-ios
git log --oneline        # 看提交
cat docs/product/roadmap.md   # 看进度
./build.sh test          # 113 项包 XCTest
```
