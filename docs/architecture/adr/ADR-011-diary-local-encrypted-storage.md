# ADR-011: 日记使用本地 SQLite 与 AES-256-GCM 加密

状态：已接受（2026-11-05）  
设计来源：[日记 v1](../../design/diary.md) · [历史产品蓝图](../../design/recovered-product-blueprint.md)

## 背景

日记是私密性最强的 App 层数据。历史设计要求本地 SQLite、AES-256-GCM、Keychain 密钥，并且 EventKit 仍是日程事实源。当前项目还未引入 GRDB、CloudKit 和手动导出导入。

## 决策

1. `DiaryKit` 提供离线优先的日记模型和存储；不依赖 EventKit、SwiftUI 或通知。
2. v1 使用系统 SQLite C API，不引入 GRDB。表只保存 `day_key` 与加密 payload，不保存明文正文、心情或日程骨架。
3. payload 使用 AES-256-GCM 的 `combined` 数据编码；主密钥由 App 层写入 Keychain。
4. 日期查询键使用 `HMAC-SHA256(dayKey, diaryKey)`，避免在数据库中留下可读日期；同一天通过 unique key 保证一天一篇。
5. App 层负责获取 / 生成 Keychain 密钥、提供 Application Support 数据库位置和把 EventKit 日程转换为骨架。
6. v1 不做 CloudKit 同步、照片、语音、独立密码、全文 FTS、跨设备迁移和自动晚间提醒。

## 影响

* 数据库文件即使被复制，没有 Keychain 密钥也无法读出正文。
* Keychain 密钥丢失或用户删除后，旧 payload 无法恢复；v1 不做备份密钥。
* 全文搜索先解密后在内存过滤，避免过早引入 FTS 和额外明文索引。
* 后续 CloudKit 或导出只能传输加密 payload，或由用户明确导出解密内容。
