# ADR-009: 工作日智能闹钟采用节假日感知纯引擎、多闹钟派生计划与 App 层本地通知

状态：已接受；2026-11-05 修订为多闹钟 v1.3、独立页签与独立开关<br>
设计来源：[workday-alarm](../../design/workday-alarm.md)

## 背景

工作日闹钟的结果同时依赖用户模板和法定节假日 / 调休数据。若把判定写入 SwiftUI 或通知服务，GUI 验收、跨平台迁移和年度数据替换都会耦合在一起；若完全脱离节假日包，又会复制休班口径。

## 决策

1. `WorkdayResolver` 放入 `HolidayData`，复用同一个 `HolidayStore` 与 `HolidayCoverage` 口径；包内只依赖 Foundation，不依赖 SwiftUI、EventKit 或 UserNotifications。
2. 日期判定固定使用 `Asia/Shanghai`；通知展示和响铃时间使用用户设备当前时间解释，通知触发组件固定标记上海时区。
3. 调整优先级固定为：官方休息日 > 官方补班日 > 用户模板；数据未覆盖时按模板执行并保留 `unknown / yearNotLoaded`。
4. 最多预计算未来 60 天；允许最多 8 个闹钟。每个闹钟使用同一官方休 / 班口径，可独立命名、时间、开关和铃声。通知 ID 为 `workday-alarm.<alarmID>.yyyy-MM-dd`。
5. `UNUserNotificationCenter` 只在 App 层调用。工作日规则没有全局开关；独立闹钟页签持久化工作日模板和闹钟数组。调度与授权请求只读取每个闹钟的 `isEnabled`；权限拒绝时仍可预览，但不写通知。
6. UI 使用 `工作日` 作为默认模板名称，其底层判定仍是周一至周五叠加官方休息 / 补班优先级。铃声默认提供系统 `default` 与三个 App 内置短音频；自定义铃声文件必须已随主 App bundle 分发。前台展示由 `UNUserNotificationCenterDelegate` 返回 `banner + sound + list`，后台由系统直接播放通知声音。
6. 里程碑与智能闹钟只按各自 `milestone.` / `workday-alarm.` 前缀替换 pending 通知，禁止一方同步时清空另一方的通知。

## 影响

- 节假日 JSON 更新后无需改 resolver；未来公司政策可作为独立模板提供方接入。
- 60 天外不承诺通知，避免无限制请求和系统通知配额压力。
- 全部闹钟关闭或权限被拒后，只清理 `workday-alarm.` 前缀，兼容清理 v1 的 `workday-alarm.yyyy-MM-dd`；里程碑提醒不受影响。
- 不申请 Critical Alert 权限；静音键 / 勿扰 / 系统通知设置仍会按 iOS 规则影响声音。
- 当前内置 2026 为 official、2027 为 sample；预览必须继续依赖 `HolidayCoverage` 明示可信度，不能把未官方确认年份伪装成官方结果。
