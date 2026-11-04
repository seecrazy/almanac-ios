# 二十四节气 v1

状态：代码已接入（2026-11-04）；GUI / 真机人工验收待完成  
架构依据：[ADR-007](../architecture/adr/ADR-007-cross-platform.md)  
关联设计：[设计系统](design-system.md) · [官方节假日数据管道](holiday-data-pipeline.md)

## 1. 目标

- 在 LunarKit 内提供 1900–2100 年二十四节气的天文计算。
- 设置页「二十四节气」开启后，月视图、周视图和日详情能识别并展示节气。
- 节气日期归属固定使用 `Asia/Shanghai`，不随设备时区漂移。

## 2. 非目标 v1

- 不做节气时刻的民俗播报和提醒。
- 不做节气黄历宜忌；黄历继续使用独立规则表。
- 不改变农历月柱近似算法；月柱精度升级另行处理。
- 不引入网络时间或第三方天文服务。

## 3. 数据模型

```swift
public enum SolarTermName: String, CaseIterable {
    case minorCold = "小寒"
    case majorCold = "大寒"
    case springBegins = "立春"
    // 其余 21 个节气按公历年出现顺序排列
}

public struct SolarTerm: Identifiable, Hashable {
    public let name: SolarTermName
    public let date: Date
}
```

API：

```swift
SolarTermCalendar.terms(inGregorianYear: 2026) -> [SolarTerm]?
SolarTermCalendar.term(on: Date) -> SolarTerm?
SolarTermCalendar.displayName(for: Date) -> String?
```

## 4. 计算与边界

1. 使用太阳视黄经达到节气对应角度的时刻计算节气。
2. Julian Day 计算使用 UT，天文公式使用 TT；内部做 Delta T 近似。
3. 日期归属固定使用 `Asia/Shanghai`；展示层可使用设备时区显示当天。
4. 覆盖范围与农历一致：1900–2100；范围外返回 `nil`，不崩溃。
5. `term(on:)` 只有当上海日历当天存在节气时返回结果；同一公历日不重复出现两个节气。
6. 计算误差以「上海日期」为验收口径；不承诺分钟级历史精度。

## 5. UI 规则

| 位置 | 行为 |
|---|---|
| 设置 | 沿用现有「二十四节气」开关，默认开启 |
| 月视图格 | 节气名替换农历日文本，使用 `solarGreen`；无节气时继续显示农历 |
| 周视图列 | 节气名替换农历日文本，使用 `solarGreen`；无节气时继续显示农历 |
| 日详情 | 农历行下方显示「节气 · 立春」 |
| 日视图头 | 农历行下方显示「节气 · 立春」 |

关闭设置开关时，所有 UI 回退为普通农历展示；黄历面板和节假日角标不受影响。

## 6. 验收清单

- [x] `SolarTermName` 完整包含 24 个节气且公历顺序唯一。（XCTest 已覆盖）
- [x] 1900、1949、2024、2026 年立春/春分/夏至/冬至等锚点日期正确。（支持范围与 2026 日锚点 XCTest 已覆盖）
- [x] 24 个节气按公历时间升序且跨度接近一年。（XCTest 已覆盖）
- [x] 1900–2100 外查询显式返回空或 `nil`。（XCTest 已覆盖）
- [x] `term(on:)` 只命中节气当天。（XCTest 已覆盖）
- [x] 月视图、周视图开启开关后显示节气名，关闭后恢复农历。（代码已接入；GUI 验收待完成）
- [x] 日详情和日视图显示节气行。（代码已接入；GUI 验收待完成）
- [x] LunarKit XCTest 全绿。（17 项）
- [x] generic iOS Simulator build 全绿。

## 7. 当前落地说明

- `SolarTermCalendar` 使用太阳视黄经公式与 UT/TT Delta T 近似，不引入第三方依赖。
- 节气日查询固定使用上海时区；展示层读取现有 `showSolarTerms` 开关。
- 月视图和周视图优先用节气名替换农历小字；日详情与日视图在农历行下方追加节气行。
- 尚需人工核对不同年份日视图、跨年周、开关切换和越界年份 UI。
