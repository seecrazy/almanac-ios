# 拼音搜索 v1

状态：已实现（2026-11-09）。关联：[搜索本地索引](event-search-local-index.md)、[ADR-010](../architecture/adr/ADR-010-event-search-sqlite-index.md)。

## 目标与非目标

目标：日程搜索支持拼音全拼与首字母——输入 `kaui` / `tdhy` 能命中「团队会议」。转写用系统 `CFStringTransform`（Mandarin-Latin + 去声调），零数据文件、零第三方依赖。

非目标：

- 不做模糊纠错 / 编辑距离（后续评估）；
- 不做多音字消歧（系统转写取默认读音）；
- 不改 CJK 关键词既有 LIKE 路径。

## 数据 / 状态模型

`EventSearchKit` 新增 `PinyinText`：

- `plain(_:)`：`团队会议` → `tuandahui`（小写、无声调、无分隔）；
- `initials(_:)`：`团队会议` → `tdhy`（逐音节首字母）。

实现：整串 `kCFStringTransformMandarinLatin` 转写（音节间留空格）→ 去组合音符 → 小写；initials 取每个空格分隔音节的首字符。非汉字字符原样保留在 plain 中、不参与 initials。

SQLite 表结构迁移（FTS5 虚表无法加列）：

- `event_fts` 增加 `title_pinyin`、`title_initials`、`location_pinyin`、`location_initials`、`notes_pinyin`、`notes_initials` 六列，插入时由 `PinyinText` 生成；
- `index_meta` 记录 `schemaVersion = 2`；打开时版本不符则 DROP 重建（派生缓存可随时重建，语义不变）。

## 关键流程

搜索时关键词只含 ASCII 字母时走拼音分支：

- `title_pinyin LIKE %kw%`（全拼包含）或 `title_initials LIKE %kw%`（首字母包含），location / notes 同理，与既有日期 / 日历 / 全天过滤叠加；
- 含 CJK 或其它字符时维持原 LIKE / FTS 路径不变。

## 边界与错误状态

- 空转写（纯符号标题）：拼音列为空串，拼音搜索不命中，中文路径不受影响；
- 多音字：接受系统默认读音（设计边界，文档明示）；
- 旧库自动迁移：首次打开检测 schemaVersion 重建，无用户可见状态。

## 验收清单

- [x] `PinyinText` XCTest：全拼 / 首字母 / 非汉字混合 / 空串
- [x] 拼音与首字母关键词命中中文标题事件；与日期过滤叠加
- [x] schema 版本迁移触发重建
- [x] EventSearchKit 全量 XCTest 绿 + generic iOS Simulator build 通过
