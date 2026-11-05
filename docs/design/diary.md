# 日记 v1.1

状态：日详情入口已实现，独立页签移除（2026-11-05；GUI / 真机验收待完成）  
架构依据：[ADR-001](../architecture/adr/ADR-001-eventkit-as-source-of-truth.md) · [ADR-007](../architecture/adr/ADR-007-cross-platform.md) · [ADR-011](../architecture/adr/ADR-011-diary-local-encrypted-storage.md)  
关联设计：[事件详情 / 编辑 / 删除](event-detail-editing.md) · [历史蓝图](recovered-product-blueprint.md)

## 1. 目标

- 一天只保留一篇日记。
- 用户可选择从当日 EventKit 日程生成只读骨架，再补充心情和感受。
- 数据本地加密存储，Keychain 保存 AES-256-GCM 主密钥。
- 月视图点击某一天后，在日详情中新增 / 查看该日日记。
- 日记面板内的历史列表可切换查看、修改和删除已保存日记。

## 2. 非目标 v1

- 不写 EventKit，不修改日程。
- 不做 CloudKit 同步。
- 不做照片、语音、天气附件。
- 不做独立日记密码、FaceID 锁屏页。
- 不做 SQLite FTS 全文索引。
- 不做自动晚间提醒和年度报告。
- 不做导出 / 导入。

## 3. 用户流程

### 月视图日详情入口

1. 用户在月视图点击日期，打开日详情。
2. 日详情底部显示“写日记”或“查看日记”入口。
3. 点击后在该日详情上方打开日记面板。
4. 若该日没有日记，面板处于新增态，可选择心情、编辑正文并从日程生成骨架。
5. 若已有日记，面板直接显示心情、正文和骨架；可切换到编辑态。
6. 删除需要确认；删除后面板回到新增态。
7. 面板底部显示已保存日记历史列表；点击其他日期可在同一面板内查看 / 编辑 / 删除该日日记。

## 4. 数据 / 状态模型

```swift
public enum DiaryMood: String, Codable, CaseIterable, Sendable {
    case great, good, calm, tired, sad
}

public struct DiarySkeletonItem: Codable, Hashable, Sendable {
    public let title: String
    public let timeText: String
    public let calendarTitle: String
    public let isAllDay: Bool
}

public struct DiaryEntry: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public var mood: DiaryMood?
    public var body: String
    public var skeleton: [DiarySkeletonItem]
    public var createdAt: Date
    public var updatedAt: Date
}
```

校验：

- `body` trim 后为空且无心情时不能保存。
- 正文上限 20,000 字符。
- `date` 保存为当前日历时区的当天开始。
- 一天一篇；重复保存同一日期是更新，不是新增。

## 5. 加密与存储

SQLite 表：

```sql
CREATE TABLE IF NOT EXISTS diary_entries (
    day_key BLOB PRIMARY KEY,
    payload BLOB NOT NULL
) WITHOUT ROWID
```

- `payload` 是 `DiaryEntry` JSON 经 AES-256-GCM `combined` 加密后的数据。
- `day_key` 是 `HMAC-SHA256("yyyy-MM-dd", diaryKey)`，不可读、不可逆推日期。
- AES 主密钥 256 位，首次使用生成并写入 Keychain。
- Keychain account：`diary.v1`；accessibility：`AfterFirstUnlockThisDeviceOnly`。
- 数据库文件：Application Support / `DiaryStore.sqlite`。

## 6. 关键交互

- 日程骨架按钮把当前选中日期的 EventKit 日程转换为条目，每条显示 `时间 · 标题 · 日历`。
- 全天日程显示 `全天`；非全天显示 `HH:mm–HH:mm`。
- 骨架只在用户主动生成或确认时写入日记。
- 历史列表按日期倒序展示最近 30 天；面板内切换目标日期。
- 保存成功后刷新历史列表、当前卡片和小组件之外的本地状态。
- 删除需要二次确认。

## 7. 边界与错误处理

| 场景 | 行为 |
|---|---|
| 无日历授权 | 骨架按钮提示未授权，日记正文和心情仍可保存 |
| 当天无日程 | 骨架为空数组；正文显示“今天没有日程骨架” |
| Keychain 读取失败 | 显示无法解锁日记，不创建新密钥覆盖旧数据 |
| 数据库损坏 | 显示错误并保留文件；v1 不自动删除 |
| payload 解密失败 | 跳过该条并统计失败数量；列表仍显示可用条目 |
| 保存失败 | 保留编辑器内容和错误提示 |
| 正文超限 | 输入可显示，保存按钮禁用并提示上限 |

## 8. 验收清单

- [x] `DiaryKit` 模型、加密、SQLite 存储有 XCTest。（6 项 XCTest）
- [x] 同一日期重复保存更新原记录。
- [x] 数据库文件中看不到明文正文、心情或日期。
- [x] 日期键稳定，跨进程可查询同一天。
- [x] 错误密钥解密失败不会崩溃。
- [x] App 能生成当日日程骨架并保存。
- [x] 日详情入口能打开日记面板。
- [x] 日记面板支持该日新增 / 查看 / 编辑 / 删除。
- [x] 历史日记可在面板内切换查看、修改和删除。
- [x] 不存在独立日记 Tab。
- [x] generic iOS Simulator build 通过。
