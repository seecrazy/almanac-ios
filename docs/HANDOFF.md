# 会话交接 / 项目现状（Handoff）

> 最后更新：2026-11-01 · 供新会话冷启动使用
> 设计来源：产品设计讨论（本文只记录结论与状态，讨论细节见 ADR 与 roadmap）

## 一句话现状

**设计全部闭环，工程已启动**：三大核心引擎完成并全绿（28 检查），SwiftUI App 壳完成并通过本地 typecheck。下一步 = 安装 Xcode → 真机构建验证 → EventKit 接入。

## 已完成（commit 152c50f）

| 模块 | 状态 | 验证方式 |
|------|------|----------|
| 文档体系 | ✅ README / roadmap / ADR-001(EventKit) / ADR-007(跨平台) | — |
| LunarKit | ✅ 1900-2100 农历换算、闰月、干支、生肖、月视图文本 | 17 项 Sanity 全绿（春节/中秋锚点、1949-10-01 甲子日、往返一致性） |
| HolidayData | ✅ 年度 JSON（休/班）+ 查询引擎；`bundled()` 双路径入口 | 5 项 Sanity 全绿 |
| RecurrenceEngine | ✅ 周期步进展开器：d/w/m/y + interval/count/until/EXDATE | 6 项 Sanity 全绿 |
| App 壳 | ✅ Xcode 工程 + 月视图(农历/休班角标/今日圆标) + 日详情 sheet + 倒计时样卡 + 设置 | swiftc typecheck ✅（macOS 11 SDK，iOS 15 API 范围） |

构建命令：`./build.sh test`（28 检查 + 三包编译，无需 Xcode）。

## 环境与构建路径（重要）

- 本机**未安装 Xcode**，仅 Command Line Tools（Swift 5.4，darwin23）
- Swift 5.4 的 SwiftPM 在纯 CLT 下探测 xctest 失败 → `build.sh` 自动降级 **swiftc 直编 + `*Sanity` 可执行验证**
- 模块缓存固定在 `/tmp/swift-module-cache`（`~/.cache` 不可写时需此参数）
- App 层验证目标固定 `arm64-apple-macos11.0`（与包的 swiftmodule 一致）
- **装上 Xcode 16+ 后**：同一脚本自动切换 SwiftPM 路径；届时恢复 XCTest 目标（LunarKit 的测试文件已在 `Tests/LunarKitTests/`，Package.swift 里 testTarget 被注释待启用；HolidayData/RecurrenceEngine 的 Tests 目录为空，可补测试或继续用 Sanity）

## 下一步（按优先级）

1. **安装 Xcode 16+** → `open Almanac.xcodeproj` 选模拟器 ⌘R；手写 pbxproj 首次打开如有自动修复属正常
2. **恢复 XCTest**：三个 Package.swift 启用 testTarget，跑 `swift test` 双路径齐备
3. **EventKit 接入**（ADR-001）：真日历读写 → 月视图日程圆点 → 日详情真实日程列表
4. **翻月手势**（swipe）+ 周起始日设置
5. **事件创建 + 自然语言输入 v1**（规则表 JSON 化，见 ADR-007）
6. **里程碑倒计时**：数据模型（`Milestone`，isAllDay 精度切换）+ 列表页 + 锁屏小组件
7. 节假日数据管道：当前 `holiday-2026.json` 为 **sample 标注**；接国务院年度通知更新流程 + 生成 2027 数据
8. 更远：黄历面板(v1.1)、智能闹钟工作日引擎(v1.1)、公司政策引擎(v1.2)——设计已在会话中闭环，编码前补 ADR

## 设计结论速查（详见各文档）

- 数据源头：EventKit + 本地 SQLite 缓存（ADR-001）
- 跨平台：UI 原生、逻辑零依赖、规则 JSON 化、同步协议化（ADR-007）
- 命名：产品「宜历」/ 仓库 almanac-ios / Bundle `com.yili.almanac`
- 设计 token：docs/design/design-system.md 待补（色彩已在 Theme.swift 落码：纸感/墨感、朱砂/赭金/青瓷）
- 明确不做：社交流、云端日程 AI、广告

## 新会话接手姿势

```bash
cd ~/IdeaProjects/almanac-ios
git log --oneline        # 看提交
cat docs/product/roadmap.md   # 看进度
./build.sh test          # 确认 28 检查仍全绿
```
