# 会话交接 / 项目现状（Handoff）

> 最后更新：2026-11-01（EventKit 单条提醒基线） · 供新会话冷启动使用
> 设计来源：产品设计讨论（本文只记录结论与状态，讨论细节见 ADR 与 roadmap）

## 一句话现状

**设计闭环、工程可构建**：三大核心引擎 + XCTest 全绿（20 个测试），SwiftUI App 壳已通过 Xcode 27.2 iOS Simulator 构建；EventKit 只读、手动新建、事件详情、基础字段编辑、删除和单条提醒已接入。重复日程 v1 只修改/删除当前发生；自定义提醒默认保护。GUI / 真机验收仍待完成。

## 已完成（截至 2026-11-01 工作树）

| 模块 | 状态 | 验证方式 |
|------|------|----------|
| 文档体系 | ✅ README / roadmap / HANDOFF / ADR-001(EventKit) / ADR-007(跨平台) / design-system / event-creation / event-detail-editing / event-reminders | 内容与当前工作树状态一致 |
| 历史设计 | ✅ `recovered-product-blueprint.md` 恢复核心日历、中国日历、里程碑、闹钟、迁移、日记、智能与跨平台设计 | 来源 Codex rollout `01a19205-ad9f-7731-a10f-fd3c511941d1` |
| 设计差距 | ✅ `design-gap.md` 区分 ✅ / 🟡 / 🔴 | 每次里程碑结束应刷新 |
| LunarKit | ✅ 1900-2100 农历换算、闰月、干支、生肖、月视图文本 | 17 项 Sanity 全绿（春节/中秋锚点、1949-10-01 甲子日、往返一致性） |
| HolidayData | ✅ 年度 JSON（休/班）+ 查询引擎；`bundled()` 双路径入口 | 5 项 Sanity 全绿 |
| RecurrenceEngine | ✅ 周期步进展开器：d/w/m/y + interval/count/until/EXDATE | 6 项 Sanity 全绿 |
| App 壳 | ✅ Xcode 工程 + 月视图(农历/休班/今日/日程圆点) + 日详情真实日程 + 倒计时样卡 + 设置 | Xcode 27.2 iOS Simulator build ✅ |
| EventKit 读写 | ✅ `EventStoreService`、iOS 15/17 授权兼容、系统日历变更监听、月/日视图消费、手动新建事件、可写日历选择、事件详情、基础字段编辑、单次删除、单条提醒 | generic iOS Simulator build ✅；GUI / 真机验收待完成 |
| XCTest | ✅ LunarKit 9 / HolidayData 5 / RecurrenceEngine 6 | `./build.sh test` 全绿 |

构建命令：`./build.sh test`（20 个 XCTest + 三包编译）。

## 环境与构建路径（重要）

- 已安装 **Xcode 27.2**（`/Applications/Xcode.app`），但 `xcode-select -p` 仍指向 Command Line Tools；命令行构建可直接使用完整路径：
  `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild`
- 三包 manifest 已升到 Swift tools 6.0，并设置 `swiftLanguageModes: [.v5]`；`./build.sh test` 已走 SwiftPM/XCTest 路径
- 手写 pbxproj 已修复三个会导致 Xcode 27 打不开的问题：本地包引用不应作为 main group children；App group path 必须是 `App/Almanac`；Swift tools 6.0 才接受现有 `executableTarget` 签名
- `.gitignore` 已停止忽略整个 `*.xcodeproj`，否则仓库实际不含 Xcode 工程；现在只忽略用户态数据
- 真机/模拟器运行仍建议先打开 Xcode GUI 检查签名与 runtime

## 下一步（按优先级）

1. **Xcode GUI 模拟器运行**：验证权限弹窗 → 新建日程（含提醒） → 点击日程 → 详情 → 编辑（改提醒） → 删除 → 月历圆点刷新
2. **真机 / iCloud 日历实测**：普通事件、重复事件、只读日历、自定义提醒、权限拒绝路径
3. **翻月手势**（swipe）+ 周起始日设置
4. **自然语言输入 v1**（规则表 JSON 化，见 ADR-007；表单可抽取 `EventDraft`）
5. **里程碑倒计时**：数据模型（`Milestone`，isAllDay 精度切换）+ 列表页 + 锁屏小组件
6. 节假日数据管道：当前 `holiday-2026.json` 为 **sample 标注**；接国务院年度通知更新流程 + 生成 2027 数据
7. 更远：黄历面板(v1.1)、智能闹钟工作日引擎(v1.1)、公司政策引擎(v1.2)——编码前补 ADR

## 设计结论速查（详见各文档）

- 日程源头：EventKit 读/写已接（ADR-001）；App 层数据后续用本地 SQLite
- 跨平台：UI 原生、逻辑零依赖、规则 JSON 化、同步协议化（ADR-007）
- 命名：产品「宜历」/ 仓库 almanac-ios / Bundle `com.yili.almanac`
- 设计 token：[docs/design/design-system.md](docs/design/design-system.md) 已建立 v0.1（纸感/墨感、朱砂/赭金/青瓷）
- 事件创建：[docs/design/event-creation.md](docs/design/event-creation.md) 记录入口、字段映射、授权流、状态和验收清单
- 事件详情 / 编辑 / 删除：[docs/design/event-detail-editing.md](docs/design/event-detail-editing.md) 记录重复日程边界、只读状态和刷新策略
- 事件提醒：[docs/design/event-reminders.md](docs/design/event-reminders.md) 记录单条提醒映射、自定义提醒保护和 v1 边界
- 历史蓝图：[docs/design/recovered-product-blueprint.md](docs/design/recovered-product-blueprint.md) 汇总之前会话未落码设计
- 差距清单：[docs/design/design-gap.md](docs/design/design-gap.md) 是当前“文档设计 vs 代码实现”事实表
- 明确不做：社交流、云端日程 AI、广告

## 新会话接手姿势

**协作纪律**：讨论设计并决定开干时，先落设计文档；实现过程中同步更新设计、进展文档和 README。完整规则见仓库根目录 `AGENTS.md`。

```bash
cd ~/IdeaProjects/almanac-ios
git log --oneline        # 看提交
cat docs/product/roadmap.md   # 看进度
./build.sh test          # 确认 20 个 XCTest 仍全绿
```
