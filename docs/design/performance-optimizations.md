# 性能优化 v1（渲染与 IO 热点）

状态：已实现（2026-11-09）。关联：[ADR-010 搜索索引](../architecture/adr/ADR-010-event-search-sqlite-index.md)、[视图矩阵](views-navigation.md)。

## 问题清单（逐项：现象 → 根因）

1. **DateFormatter 在 body 里反复创建**。`anchorTitle`、`dayTitle`、`monthTitle`、`intervalText`、`slotText`、`EventRow.timeText`、`EventDetailView.timeText`、`MilestoneWidgetView.targetText` 等每次视图求值都 new 一个 DateFormatter——iOS 上出名的昂贵对象（首次创建约毫秒级、涉及 ICU 规则解析）。
2. **bundled JSON 每次视图初始化重新读盘解析**。`AlmanacPanel.body` 直接调用 `AlmanacRuleSet.bundled()`（读盘 + JSONDecoder）；`CalendarScreen` / `MonthView` / `DayDetail` / `SettingsView` / `AlarmView` 把 `HolidayStore.bundled()`（manifest + 多个年度 JSON）写成视图结构体成员，SwiftUI 重建结构体时重复读盘。
3. **年视图 12 次串行 EventKit 拉取**。`loadYearByMonth` 逐月 `loadEvents(appending:)`，每次 append 对越来越长的数组整体重排（12 次 O(n log n)）。
4. **议程视图每次渲染全量重算分组**。`agendaSections` 与 `totalEventCount` 在 body 中对最多 90 天 × 全部事件做过滤，任何 state 变化、滚动都触发。
5. **编辑/删除前的事件匹配在主线程查 EventKit**。`ekEvent(matching:)` 同步执行 `predicateForEvents + events(matching:)`，`loadEvents` 却已正确走 `Task.detached`。
6. **每次搜索全量重建 SQLite 索引**。`searchEvents` 每次 `replaceAll` 整表重写；索引生命周期应跟随事件数据而非关键词。

## 方案

1. 新增 `AppFormatters`（App 层工具）：静态缓存的 `DateFormatter`（zh_CN、固定 format），全部替换点改用缓存实例；Widget 侧同样处理。DateFormatter 线程安全（iOS 7+），缓存是标准做法。
2. 规则/节假日数据进程内单例：
   - `LunarKit`：`AlmanacRuleSet.bundledShared`（`static let`，immutable，一次解析）；
   - `HolidayData`：`HolidayStore.bundledShared`（`static let`）。App 与 Widget 全部改用；视图不再持有 store 实例。
3. 年视图一次拉取：整年区间单次 `loadEvents`；`loadEvents` 保持既有合并/排序逻辑。
4. 议程分组缓存：`CalendarAgendaView` 以 `eventService.events` + 天数范围 + visibleLimit 为 key，将分组结果缓存在 `@State`，`.onChange` 失效重算。
5. `ekEvent(matching:)` 移入 `Task.detached`：匹配为纯查询（无 UI 状态），结果回主 actor 后继续编辑/删除流程。
6. 索引复用与重建节流：`EventSearchIndex` 增加记录集指纹（count + 首末 eventID + 内容 hash 的轻量指纹）；`searchEvents` 仅当指纹变化时 `replaceAll`，否则直接查询。派生缓存语义不变（仍可随时整表重建）。

## 非目标

- 不引入 GRDB 或换存储；
- 不改 FTS tokenizer（拼音列另见 [pinyin-search](pinyin-search.md)）；
- 不做 EventKit 增量拉取（系统 API 限制，只有全量 predicate）。

## 验收清单

- [x] 全部 body 内 DateFormatter 创建点清零（静态缓存）
- [x] `AlmanacRuleSet.bundledShared` / `HolidayStore.bundledShared` 单例化，视图成员清零
- [x] 年视图单次区间拉取
- [x] 议程分组按事件/范围变化重算，渲染期零过滤
- [x] 事件匹配在后台线程执行
- [x] 搜索在索引未变化时跳过重建（EventSearchKit XCTest 覆盖指纹语义）
- [x] `./build.sh test` 全绿 + generic iOS Simulator build 通过
