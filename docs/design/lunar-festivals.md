# 农历节日 v1

状态：代码已接入（2026-11-04）；GUI / 真机人工验收待完成  
架构依据：[ADR-007](../architecture/adr/ADR-007-cross-platform.md)  
关联设计：[二十四节气](solar-terms.md) · [官方节假日数据管道](holiday-data-pipeline.md) · [设计系统](design-system.md)

## 1. 目标

- 在 LunarKit 内计算 1900–2100 年常见农历节日。
- 设置页「农历节日」开启后，月视图、周视图和日视图能识别并展示节日名。
- 节日不写入 EventKit，不生成事件，不参与节假日放假判定。

## 2. 非目标 v1

- 不覆盖地方性、宗教性、少数民族全部节日。
- 不做节日提醒。
- 不用节日替代官方法定节假日数据；休 / 班仍以 `HolidayData` 为准。
- 不做节日历史介绍和民俗长文案。

## 3. 节日范围

| 节日 | 农历规则 |
|---|---|
| 春节 | 正月初一 |
| 元宵节 | 正月十五 |
| 龙抬头 | 二月初二 |
| 上巳节 | 三月初三 |
| 七夕 | 七月初七 |
| 中元节 | 七月十五 |
| 中秋节 | 八月十五 |
| 重阳节 | 九月初九 |
| 腊八节 | 腊月初八 |
| 除夕 | 下一个春节前一天 |

固定日期均使用正常农历月；闰月中的同名日期不算节日。除夕按农历年动态推导。

## 4. 数据模型

```swift
public enum LunarFestivalName: String, CaseIterable {
    case springFestival = "春节"
    case lanternFestival = "元宵节"
    // ...
}

public struct LunarFestival: Identifiable, Hashable {
    public let name: LunarFestivalName
    public let date: Date
}
```

API：

```swift
LunarFestivalCalendar.festivals(inLunarYear: 2026) -> [LunarFestival]?
LunarFestivalCalendar.festival(on: Date) -> LunarFestival?
LunarFestivalCalendar.displayName(for: Date) -> String?
```

## 5. 计算与边界

1. 日期换算复用 `LunarCalendar.solar(from:)`，固定 `Asia/Shanghai`。
2. `festivals(inLunarYear:)` 返回按公历日期升序的 10 个节日；农历 2100 年的除夕需要 2101 年春节数据，因此该年除夕省略，其余节日正常返回。
3. `festival(on:)` 查询前后农历年，避免公历年初 / 年末跨农历年漏判。
4. 不支持农历数据时返回 `nil` 或空，不崩溃。
5. 节日名仅用于展示，不能被 `HolidayData` 解释为法定休 / 班。

## 6. UI 规则

| 位置 | 行为 |
|---|---|
| 设置 | 新增「农历节日」开关，默认开启 |
| 月视图格 | 节日名优先于节气和农历日文本，使用朱砂红 |
| 周视图列 | 节日名优先于节气和农历日文本，使用朱砂红 |
| 日视图头 | 农历行下方显示「农历节日 · 名称」 |
| 日详情 | 农历行下方显示「农历节日 · 名称」 |

显示优先级固定为：农历节日 > 二十四节气 > 农历日文本。关闭开关时回退到节气 / 农历展示。

## 7. 验收清单

- [x] `LunarFestivalName` 完整覆盖上述 10 个节日。（XCTest 已覆盖）
- [x] 每个支持农历年（2100 除夕除外）返回 10 个节日且按公历升序。（1900–2099 全量 XCTest 已覆盖）
- [x] 2026 春节、元宵、中秋、除夕锚点日期正确。（XCTest 已覆盖）
- [x] 2024 中秋、除夕锚点日期正确。（XCTest 已覆盖）
- [x] `festival(on:)` 只命中节日当天，且能处理公历 / 农历年跨界。（XCTest 已覆盖）
- [x] 范围外查询显式返回空或 `nil`。（XCTest 已覆盖）
- [x] 月视图、周视图开启开关后显示节日名，关闭后恢复节气 / 农历。（代码已接入；GUI 验收待完成）
- [x] 日视图和日详情显示节日行。（代码已接入；GUI 验收待完成）
- [x] LunarKit XCTest 全绿。（19 项）
- [x] generic iOS Simulator build 全绿。

## 8. 当前落地说明

- `LunarFestivalCalendar` 复用农历数据表和上海时区；除夕通过下一年春节前一天推导。
- 设置页新增 `showLunarFestivals`，默认开启。
- 月 / 周视图按农历年批量构建节日映射，避免逐格重复计算；显示优先级为节日 > 节气 > 农历。
- 节日只做视觉标记，不会写入日历，也不会影响法定休 / 班判定。
