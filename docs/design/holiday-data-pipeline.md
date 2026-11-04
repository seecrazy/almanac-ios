# 官方节假日数据管道设计 v1

状态：代码已接入（2026-11-03；2026/2027 内置数据仍为 sample，待官方通知替换）  
架构依据：[ADR-007](../architecture/adr/ADR-007-cross-platform.md)  
关联代码：`Packages/HolidayData`

## 1. 目标

- 保留 JSON 与算法分离，支持 2026 起多个年份。
- 明确区分 `official`、`sample`、`estimated` 数据来源。
- 官方年度通知发布后，可以用固定流程生成和校验新年份 JSON。
- App 在数据未覆盖时给出明确状态，不误报节假日。

## 2. 非目标 v1

- 不自动抓取并直接信任网页数据。
- 不做服务器下发。
- 不预测未经官方确认的未来安排；`estimated` 只能显式标注。
- 不把跨年调休混入单年文件。

## 3. 数据文件

```text
Packages/HolidayData/Sources/HolidayData/Resources/
  holiday-2026.json
  holiday-2027.json
  holiday-manifest.json
```

`holiday-manifest.json`：

```json
{
  "version": 1,
  "years": [
    {
      "year": 2026,
      "file": "holiday-2026.json",
      "source": "official",
      "sourceName": "国务院办公厅通知",
      "sourceURL": "https://www.gov.cn/",
      "issuedAt": "2025-11-01"
    }
  ]
}
```

年度 JSON 继续使用现有 `HolidayYear` 结构，允许字段：

| 字段 | 必填 | 说明 |
|---|---:|---|
| `year` | 是 | 公历年 |
| `source` | 是 | `official` / `sample` / `estimated` |
| `note` | 否 | 数据说明或警告 |
| `holidays` | 是 | 节假日组 |

每个 `HolidayGroup` 必须有唯一 `name`；同一天禁止同时出现在一个年度文件的 `daysOff` 和 `workdays`。

## 4. 运行时模型

```swift
struct HolidayManifest: Codable {
    let version: Int
    let years: [HolidayManifestEntry]
}

struct HolidayManifestEntry: Codable {
    let year: Int
    let file: String
    let source: String
    let sourceName: String?
    let sourceURL: String?
    let issuedAt: String?
}
```

API：

```swift
HolidayStore.bundled() // 保持兼容，加载 manifest 内数据
HolidayStore.bundled(years: 2026...2027)
store.coverage(for: date) -> HolidayCoverage
store.status(for year: Int) -> HolidayYearStatus?
```

`HolidayCoverage`：

| case | UI 语义 |
|---|---|
| `.covered` | 正常显示休 / 班 |
| `.noSpecialDay` | 正常日期，无角标 |
| `.yearNotLoaded` | 显示“该年份未加载” |
| `.unknown` | 显示“节假日数据未覆盖” |

## 5. 生成流程

1. 等待国务院办公厅发布下一年通知。
2. 从官方网页人工核对放假日期、调休补班日、节日名称。
3. 复制模板生成本地 JSON，只允许 `source: official`。
4. 运行校验：
   - JSON 可解码。
   - 日期格式为 `yyyy-MM-dd`。
   - 所有日期属于 `year`。
   - 同一文件无重叠冲突。
   - 春节 / 国庆 / 劳动节至少存在一个组。
   - `source` 与 manifest 一致。
5. 更新 manifest 的 `issuedAt`、`sourceName`、`sourceURL`。
6. 运行全部测试和 iOS 构建。

## 6. UI 状态

| 状态 | 展示 |
|---|---|
| official + 休 | 红色 `休`，保留节日名 |
| official + 班 | 灰色 `班` |
| sample | 月视图角标继续展示；设置页显示“示例数据” |
| estimated | 角标必须弱化，并显示“预测，未官方确认” |
| 未覆盖 | 不显示休 / 班；日详情显示“节假日数据未覆盖” |

## 7. 错误处理

- JSON 解码失败：跳过该年度并记录错误，不能让 App 崩溃。
- manifest 指向缺失文件：视为未覆盖。
- 日期不属于声明年份：测试失败，禁止发布。
- 同一天重复冲突：测试失败，禁止发布。
- 时区固定 `Asia/Shanghai`。

## 8. 验收清单

- [x] 2026 JSON 保持可加载。
- [x] manifest 可解码。
- [x] 支持加载 2026–2027 两个年度（当前均为 sample）。
- [x] 同一天不会同时为休和班。
- [x] `nextHoliday` 跨年度可找到下一条。
- [x] App 能区分 official / sample / estimated。
- [x] 2027 官方通知发布后，按流程可在不改算法代码的情况下新增数据。
- [x] 未覆盖年份不影响月视图渲染，并显示未覆盖状态。
- [x] `swift test` 全绿（HolidayData 14 项，含 WorkdayResolver）。
- [x] Xcode iOS Simulator build 全绿。

## 9. 当前落地说明

- `HolidayStore.bundled()` 现在读取 `holiday-manifest.json`，再按 manifest 加载年度 JSON。
- 年度校验覆盖日期格式、年份归属、重复节日名、休/班冲突、manifest 与年度 source 一致性；单个年度损坏会跳过并记录，不影响其他年度。
- `coverage(for:)` 区分已覆盖特殊日、普通日、年度未加载和未知数据状态。
- 设置页展示各年度数据来源；日详情展示 sample / estimated 提示和未覆盖提示；月视图弱化 estimated 角标。
