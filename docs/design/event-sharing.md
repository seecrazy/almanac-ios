# 单事件 .ics 分享 v1

状态：已实现（2026-11-09）。关联：[事件详情/编辑/删除](event-detail-editing.md)。

## 目标与非目标

目标：日程详情页新增"分享"——生成 RFC 5545 兼容的 .ics 文件（单个 VEVENT），经系统分享面板发给他人 / 存到文件 / 添加到其它日历应用。

非目标：

- 不做重复规则导出（RRULE）；重复日程只导出当前这一次发生，分享文案注明；
- 不做整日历 / 多事件批量导出（属备份 / SyncProvider 范畴，另行设计）；
- 不做 .ics 导入。

## 数据 / 状态模型

`EventKitMapping` 新增纯逻辑 `ICSExporter`：

```swift
ICSEvent { uid, title, startDate, endDate, isAllDay, location?, notes? }
ICSExporter.calendar(event: ICSEvent, timestamp: Date) -> String
```

- 版本 2.0、PRODID `-//Yili//Almanac//CN`、CALSCALE GREGORIAN；
- 时刻事件 `DTSTART/DTEND` 用 UTC（`yyyyMMdd'T'HHmmss'Z'`），全天事件 `;VALUE=DATE:yyyyMMdd`；
- 文本字段（SUMMARY/LOCATION/DESCRIPTION）按 RFC 5545 转义（`\` `;` `,` 换行）；
- 行尾 CRLF。

## 用户入口与交互

日程详情 toolbar 增加"分享"按钮（`square.and.arrow.up`）：生成临时文件 `宜历-<标题>.ics` → `UIActivityViewController`（iOS 15 兼容，不用 ShareLink）。

## 边界与错误状态

- 标题含文件系统非法字符时替换为 `-`；
- 只读事件同样可分享（分享不写回系统日历）；
- 重复日程仅导出当前发生（详情页此语境下即用户看到的那一次）。

## 验收清单

- [x] EventKitMapping XCTest：CRLF / 转义 / 全天 VALUE=DATE / UTC 时刻 / 空地点备注省略
- [x] 详情页分享按钮 + 系统分享面板
- [x] generic iOS Simulator build 通过
