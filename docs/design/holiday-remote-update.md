# 节假日联网更新 v1

状态：已实现（2026-11-10）。关联：[ADR-013 远程数据集](../architecture/adr/ADR-013-remote-holiday-dataset.md)、[官方节假日数据管道](holiday-data-pipeline.md)。

## 目标与非目标

目标：App 自动获取次年官方放假安排（国务院无 API，采用 holiday-cn 数据集转录），校验通过后覆盖同年内置数据并持久化；离线 / 失败时回退内置。**内置 2027 已随 2026-11 官方通知同步替换为官方数据。**

非目标：不做节假日数据的人工编辑；不接入其它第三方 API；不做推送通知告知更新。

## 数据 / 状态模型

- `HolidayData`（纯逻辑）：`RemoteHolidayDataset`（holiday-cn 格式解析）、`HolidayRemoteUpdate.validatedYear`（年份集合 / 日期词法 / 去重 / 年内归属 / 休日 ≥5 / 总天数 ≤80 七道校验 → `HolidayYear(official)`）、`HolidayStore.bundledWithRemote`（同年覆盖、他年保留）、`encodeForCache / decodeFromCache`（落盘往返格式）。
- App 层 `HolidayDataCoordinator`：`@Published store` 与 `updateState`；磁盘缓存 `Application Support/HolidayRemote/<year>.json`；启动合并缓存 + 内置。
- 数据链路：激活 / 跨天 → `checkForUpdates`（24h 节流，设置页可 force）→ 双源拉取（GitHub raw → jsdelivr，10s 超时）→ 校验 → 落盘 → `store` 重建 → `AlmanacApp.onReceive` → 闹钟 `applyHolidayStore` 重排 + 手表快照刷新。

## 用户入口与交互

设置页「节假日数据」卡：年度来源列表（原有）+「检查更新」按钮 + 检查中进度 + 状态行（已更新 / 已最新 / 失败原因）+ 数据来源说明。

## 边界与错误状态

- 网络失败 / 校验失败：静默回退，状态行说明，内置数据不受影响；
- 数据集内容转录错误（非结构错误）：无法自动识别——接受（数据集带官方原文链接，设置页可溯源）；
- 远程年份越界（≠ 当前年 / 次年）：整年拒绝；
- 重复检查：24h 节流 + 手动 force。

## 验收清单

- [x] HolidayData 24 项 XCTest（远程校验 4 项 + 合并覆盖 1 项 + 2027 官方化 1 项）
- [x] 内置 2027 → official（manifest 含通知原文链接）
- [x] 设置页检查更新 + 状态；激活自动检查节流
- [x] 远程生效后闹钟计划与手表快照联动刷新
- [x] generic iOS Simulator build + App 单测通过
- [ ] 真机联网更新路径验收
