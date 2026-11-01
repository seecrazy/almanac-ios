# ADR-001: EventKit 为事件数据源头，本地 SQLite 仅存 App 层数据

状态：已接受（2026-11-01）

## 背景
用户已有 iCloud/Google/Exchange 日历，自建同步成本极高。

## 决策
事件读写走 EventKit；本地 GRDB(SQLite) 只存纪念日/黄历缓存/里程碑/日记等 App 层数据。

## 后果
+ 兼容所有用户已有日历，零同步成本
- 深度自定义字段受限，扩展数据需自有表映射
- 备选"自建 CalDAV 同步引擎"已否决（工期 6 人月+）

## 当前实现

- 读：`EventStoreService` 拉取月份区间事件，月视图显示日程圆点，日详情显示当日列表。
- 写：`AddEventView` 创建 MVP 日程并保存到用户选择的可写系统日历。
- 变更：监听 `EKEventStoreChanged`，保存成功后也会主动刷新已加载区间。
- iOS 17：使用 full access，因为当前 v1 必须同时读取已有日程和写入新日程。
