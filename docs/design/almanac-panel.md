# 黄历面板设计 v1

状态：代码已接入（2026-11-04）；GUI / 真机验收待完成  
架构依据：[ADR-007](../architecture/adr/ADR-007-cross-platform.md)  
关联设计：[历史蓝图恢复](recovered-product-blueprint.md) · [设计系统](design-system.md)

## 1. 目标

在日详情中提供可展开的黄历面板，显示：

- 公历 / 农历。
- 年、月、日干支。
- 生肖。
- 建除十二神。
- 冲煞。
- 宜 / 忌活动。

内容由本地规则和数据生成，不使用云端接口。

## 2. 非目标 v1

- 不做择时精确到时辰吉凶。
- 不做个人八字。
- 不做付费玄学建议。
- 不承诺传统文化口径唯一正确。
- 不做云端黄历服务。

## 3. 数据模型

```swift
struct AlmanacDay: Hashable {
    let date: Date
    let lunar: LunarDate?
    let yearGanZhi: String
    let monthGanZhi: String
    let dayGanZhi: String
    let zodiac: String
    let duty: String
    let clash: AlmanacClash?
    let suitable: [AlmanacActivity]
    let avoid: [AlmanacActivity]
    let source: AlmanacSource
}
```

`lunar` 为 `nil` 表示日期超出 1900–2100 农历数据支持范围；此时仍保留可计算的干支索引，但面板显示“超出农历支持范围”。

v1 月干支采用“农历月 + 五虎遁”近似，不按二十四节气精确切换月柱；该限制与“不承诺传统文化口径唯一正确”一致。

```swift
enum AlmanacSource: String, Codable {
    case rule
    case bundledTable
}
```

活动枚举 v1 覆盖 24 个高频项：

```text
祭祀, 出行, 搬家, 开业, 结婚, 签约, 动土, 安床,
入学, 面试, 看病, 手术, 理发, 洗车, 采购, 修剪,
见客, 求职, 诉讼, 安葬, 修屋, 种植, 纳财, 打扫
```

## 4. 规则表

新增 JSON：

```text
Packages/LunarKit/Sources/LunarKit/Resources/almanac-rules.json
```

结构：

```json
{
  "version": 1,
  "duties": ["建", "除", "满", "平", "定", "执", "破", "危", "成", "收", "开", "闭"],
  "clash": [
    { "dayBranch": "子", "conflictBranch": "午", "direction": "南" }
  ],
  "activities": [
    {
      "id": "travel",
      "title": "出行",
      "suitableDuties": ["开", "成", "定"],
      "avoidDuties": ["破", "闭"]
    }
  ]
}
```

计算优先级：

1. 显式 `bundledTable` 特例。
2. duty + activity 规则。
3. 无命中时不显示该活动。

## 5. UI

日详情新增卡片：

```text
黄历
丙午年 · 己亥月 · 甲子日
鼠 · 建 · 冲马 煞南
宜：出行、见客
忌：动土、诉讼
展开完整宜忌
```

规则：

- 默认折叠，只显示干支 / 生肖 / 冲煞和最多 3 个宜、3 个忌。
- 展开后显示全部命中的宜忌。
- “忌”不使用法定节假日红色，避免语义冲突；使用次级文本。
- 农历 / 干支已存在时保持现有展示，不重复占据主标题。

## 6. 错误与边界

| 场景 | 行为 |
|---|---|
| 规则 JSON 损坏 | 面板显示干支，隐藏宜忌 |
| 农历换算失败 | 显示错误占位，不崩溃 |
| 1900–2100 外日期 | 显示“超出农历支持范围” |
| 宜和忌同时命中同一活动 | 只显示在忌 |
| 无任何活动命中 | 显示 `今日无常见宜忌` |

## 7. 验收清单

- [ ] 能计算年 / 月 / 日干支。
- [ ] 能显示生肖。
- [ ] 能计算建除十二神。
- [ ] 能显示冲生肖和煞方。
- [ ] 宜忌来自 JSON，不硬编码在 UI。
- [ ] 默认折叠 / 展开状态正确。
- [ ] 同一活动不会同时出现在宜和忌。
- [ ] 规则损坏不影响日详情主内容。
- [ ] 1900–2100 边界日期有明确提示。
- [x] LunarKit XCTest 覆盖干支、冲煞、规则过滤、宜忌去重和 1900–2100 边界。
