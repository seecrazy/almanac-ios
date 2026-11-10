# Watch App 落地步骤（ADR-012）

本目录是 watchOS App 的**就绪代码（staging）**，尚未接入任何 target——watch target 的 embed /
WKCompanion 关系必须由 Xcode GUI 生成（见 [ADR-012](../docs/architecture/adr/ADR-012-watch-app-engineering.md)）。
iOS 侧的快照写入器（`WatchBriefingWriter`）已随主 App 编译，手表未接入前写入只是无消费者，无副作用。

## GUI 步骤（约 5 分钟）

1. Xcode 打开 `Almanac.xcodeproj` → File > New > Target > **watchOS App**：
   - Product Name `Almanac Watch App`；Watch-only App **不勾选**（选"Watch app with companion iOS app"关联到 Almanac）；
   - Interface SwiftUI、Language Swift。
2. 删除 GUI 生成的默认 `ContentView.swift` / `AlmanacWatchApp.swift`（模板生成的同名文件），
   用 **Add Files** 把本目录的 `AlmanacWatchApp.swift`、`AlmanacComplications.swift` 加入 watch target。
3. watch target > General > Frameworks：Add Package Dependency，勾选 **MilestoneKit / LunarKit**（本地包）。
4. watch target > Signing & Capabilities：
   - 勾选 **App Groups**，加入 `group.com.yili.almanac.shared`（与 iOS 一致）。
5. Build & Run（选手表模拟器）。表盘长按添加「宜历今日」复杂功能验证。

## 数据流

- iOS：App 激活 / 显著时间变化 → `WatchBriefingWriter.sync` 写 `App Group/Widgets/watch-briefing.json`
  （农历 / 节气 / 节日 / 宜忌前三 / 下一个里程碑 / 下一次闹钟 / 今日日程数）；
- watch：`WatchBriefingView` onAppear 读快照；复杂功能 30 分钟刷新策略。

## 已知边界

- 手表数据新鲜度取决于 iPhone 端写入时机（后台久了不会主动刷新——watchConnectivity 后续再评估）；
- 快照缺失（从未打开 iOS App / 无 App Group 权限）→ 占位文案"打开 iPhone 上的宜历更新数据"。
