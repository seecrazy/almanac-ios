# ADR-007: 跨平台策略——iOS 原生优先，逻辑层可移植

状态：已接受（2026-11-01）

## 决策
1. UI 永远原生（SwiftUI / 未来 Compose），不引入跨平台 UI 框架
2. 算法模块（LunarKit/RecurrenceEngine/WorkdayEngine/NLP规则）保持纯逻辑、零 UI 依赖
3. 规则类数据（节假日/公司政策/NLP 规则表）全部 JSON，不硬编码
4. 同步抽象 SyncProvider 协议，CloudKit 只是第一个实现；变更集不泄露平台概念
5. ICS + JSON 导出作为跨平台数据迁移兜底

## 触发重估条件
iOS DAU 稳定 + 明确 Android 需求信号后，逻辑层迁 KMP。
