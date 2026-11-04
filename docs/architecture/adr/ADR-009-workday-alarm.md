# ADR-009: 工作日智能闹钟采用节假日感知纯引擎与 App 层本地通知

状态：已接受（2026-11-04）<br>
设计来源：[workday-alarm](../../design/workday-alarm.md)

## 背景

工作日闹钟的结果同时依赖用户模板和法定节假日 / 调休数据。若把判定写入 SwiftUI 或通知服务，GUI 验收、跨平台迁移和年度数据替换都会耦合在一起；若完全脱离节假日包，又会复制休班口径。

## 决策

1. `WorkdayResolver` 放入 `HolidayData`，复用同一个 `HolidayStore` 与 `HolidayCoverage` 口径；包内只依赖 Foundation，不依赖 SwiftUI、EventKit 或 UserNotifications。
2. 日期判定固定使用 `Asia/Shanghai`；通知展示和响铃时间使用用户设备当前时间解释，通知触发组件固定标记上海时区。
3. 调整优先级固定为：官方休息日 > 官方补班日 > 用户模板；数据未覆盖时按模板执行并保留 `unknown / yearNotLoaded`。
4. 最多预计算未来 60 天；每天最多一个智能闹钟，通知 ID 为 `workday-alarm.yyyy-MM-dd`。
5. `UNUserNotificationCenter` 只在 App 层调用。设置页持久化模板、开关和响铃时间；权限拒绝时仍可预览，但不写通知。
6. 里程碑与智能闹钟只按各自 `milestone.` / `workday-alarm.` 前缀替换 pending 通知，禁止一方同步时清空另一方的通知。

## 影响

- 节假日 JSON 更新后无需改 resolver；未来公司政策可作为独立模板提供方接入。
- 60 天外不承诺通知，避免无限制请求和系统通知配额压力。
- 用户关闭总开关或权限被拒后，只清理智能闹钟前缀；里程碑提醒不受影响。
- 当前内置 2026/2027 仍为 sample；预览必须继续依赖 `HolidayCoverage` 明示可信度，不能伪装成官方结果。
