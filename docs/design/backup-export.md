# 备份导出 / 导入 v0

状态：已实现（2026-11-10）。关联：ADR-012 前的数据安全空缺、[日记](diary.md)（本版不含）。

## 目标与非目标

目标：里程碑 / 纪念日 / 闹钟（含工作日模板）一键导出为 JSON 文件，换机或重装后导入恢复。

非目标：

- **日记不导出**——正文 AES-256-GCM 加密且密钥在 Keychain，跨设备恢复需要密钥迁移方案（SyncProvider ADR 范畴，明确不在 v0）；
- 不含 AppStorage 显示偏好（低价值，重置成本低）；
- 不做自动 iCloud 备份。

## 数据 / 状态模型

`BackupDocument { version: 1, exportedAt, milestones: [Milestone], anniversaries: [Anniversary], alarmTemplate: WorkdayTemplate, alarms: [WorkdayAlarm] }`（ISO8601 日期编码）。导出文件名 `宜历备份-yyyy-MM-dd.json`。

导入合并策略（不覆盖、可重复导入前确认）：

- 里程碑 / 纪念日：按 id 去重追加（已存在的跳过）；
- 闹钟：按 id 并集合并，模板取文档值；
- 导入前 confirmationDialog 展示将新增的条数；导入后触发既有保存路径（通知 / 快照 / Spotlight 自动刷新）。

## 用户入口与交互

设置页「备份与恢复」区：导出（系统分享面板）/ 导入（fileImporter 限 .json → 解析 → 确认 → 合并）。

## 边界与错误状态

- 文件损坏 / version 不识别：解析失败提示，不改动任何数据；
- 解析成功但确认前取消：无副作用；
- 空字段安全缺省（alarms 为空则跳过闹钟合并）。

## 验收清单

- [x] 导出 JSON 可往返（XCTest：编码 → 解码 → 字段一致）
- [x] 导入按 id 去重合并（XCTest）
- [x] 设置页导出 / 导入入口 + 确认对话框
- [x] build + App 测试通过
