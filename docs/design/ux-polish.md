# UX 打磨批次 v1（2026-11-10）

状态：已实现。关联：[性能优化](performance-optimizations.md)、[workday-alarm](workday-alarm.md)、[日程小组件](schedule-widget.md)。

本批为全面复查后确认的五个代码级体验问题 + Widget 深链，全部经代码定位验证。

## 1. 闹钟页击键即全量重排（workday-alarm §13）

**问题**：名称输入框 binding 直写 store，`onChange(of: store.alarms)` 每字符触发 `sync()`——删旧通知 + 重算 60 天计划 + 重写 60+ 条通知 + 重挂保活计时器。

**修正**：600ms 防抖（`Task.sleep` 取消重排）；`onDisappear` 立即冲刷，避免防抖窗口内退出丢编辑。

## 2. 月视图三重计算每次渲染执行（performance-optimizations §补）

**问题**：`grid` 内 `eventCalendarColors`（全事件逐日循环）、`solarTermNames`（**太阳视黄经天文计算**）、`festivalNames` 每帧重算。

**修正**：三者打包为 `MonthDecorations` 缓存于 `@State`，仅在 `visibleMonth` 或 `eventService.events` 变化时重建；议程缓存同思路（performance-optimizations.md 既有模式）。

## 3. 日详情冲突分析重复调用

`conflictGroups` 在条件判断与 body 各算一次 → 提到局部变量算一次。

## 4. 权限被拒无「去设置」入口

新增共享组件 `OpenSettingsLink`（`UIApplication.openSettingsURLString`），接入四处：设置页（日历拒绝）、日历页授权横幅、闹钟页授权脚注、通讯录导入拒绝态。

## 5. Widget 点击无深链（deep-links）

**方案**：

- App 注册 URL scheme `almanac`（CFBundleURLTypes，App Info.plist）；
- `AppRouter.handleURL(_:)`：`almanac://calendar` / `countdown` / `alarm` / `settings`（Tab 直达），`almanac://calendar?date=yyyy-MM-dd`（打开该日详情，复用 `pendingDiaryDate` 载荷）；
- Widget：里程碑 / 日程两族全部挂 `widgetURL`（倒计时 → `almanac://countdown`，日程 → `almanac://calendar`）；
- `RootView.onOpenURL` 接入；深链目标缺失时静默忽略。

**测试**：AppTests 增加 `handleURL` 用例（四 Tab 直达、date 参数、非法 host）。

## 6. App 层测试补充

- 闹钟存储迁移：v1（legacy）/v2（previous）/v3 三代 JSON 在隔离 UserDefaults suite 下的加载与迁移；
- 简报设置持久化恢复（enabled / time）；
- 路由 URL 解析（见上）。

## 验收清单

- [x] 防抖 + onDisappear 冲刷
- [x] 月视图装饰缓存（节气 / 节日 / 事件色点）
- [x] 冲突分析单次调用
- [x] 四处「打开系统设置」
- [x] almanac:// scheme + 两族 Widget widgetURL + 路由消费 + 测试
- [x] 闹钟迁移 / 简报恢复 / 路由 URL 测试
- [x] build + App 测试通过
