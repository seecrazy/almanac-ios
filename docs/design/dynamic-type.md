# Dynamic Type 正文适配 v1

状态：已实现（2026-11-09）。关联：[设计系统](design-system.md)、[无障碍差距](design-gap.md)。

## 目标与非目标

目标：正文的阅读面跟随系统动态字体（辅助功能 → 更大字体），低视力用户可用。做法：`Font.appText(_:)`（`UIFontMetrics(forTextStyle: .body)` 缩放后的 `system(size:)`），替换固定 `.system(size:)`。

非目标：

- 展示型大数字（倒计时大字、闹钟时间 36pt、日详情日期 56pt）保持固定——它们是装饰性数字，缩放会破坏版式，且语境无关阅读负担；
- 不引入自定义字体家族；
- Widget 与 Live Activity 用系统渲染层级，本阶段不动。

## 已覆盖面（v1）

- `EventRow`：标题 / 时间 / 地点 / 日历名（月视图周模式列表、日详情、议程共用）；
- 日详情头部：公历行 / 农历行 / 节日 / 节气；
- 设置页开关行、简报行。

## 边界与错误状态

- 缩放值由系统 `UIFontMetrics` 给出，超 XXXL 时跟随系统上限；
- 环境变化（用户在控制中心改字号）触发 SwiftUI 重渲染，即时生效。

## 验收清单

- [x] `Font.appText` 工具与上述覆盖面替换
- [x] generic iOS Simulator build 通过
- [ ] 真机 / 模拟器大字号逐屏走查（记入 roadmap 待验收）
