# 联系人生日导入 v1

状态：已实现（2026-11-09）。关联：[农历生日 / 纪念日](lunar-anniversaries.md)。

## 目标与非目标

目标：从系统通讯录一键导入联系人生日为"生日 / 纪念日"条目（阳历、可编辑、可删除），进入倒计时与提醒体系。

非目标：

- 不导入农历生日（系统通讯录生日为公历）；
- 不做通讯录变更同步（导入是快照，联系人改生日后需重新导入）；
- 不读取通讯录其它字段（电话 / 邮箱等一概不取）。

## 数据 / 状态模型

`MilestoneKit` 新增纯逻辑 `ContactBirthdayMapper`：

- 输入 `ContactBirthdayCandidate { contactID, displayName, month, day, year? }`（year 为 nil 表示"无年份生日"，iOS 常见）；
- 输出 `Anniversary`（kind `.birthday`、calendar `.solar`、title `"<姓名>的生日"`、personName、originalYear 仅在 year > 1900 且可信时携带、solarDate 月日）；
- 去重：已有同 contactID 导入记录（notes 存 contactID 标记）跳过。

App 层 `ContactImportSheet`（倒计时页入口）：

- `CNContactStore.requestAccess`（Info.plist `NSContactsUsageDescription` 已声明）；拒绝时展示引导文案，不阻塞页面；
- 拉取含生日的联系人 → 列表勾选 → 批量 `milestoneStore.save(_:)`（逐条保存触发统一通知重建与 Spotlight）。

## 用户入口与交互

倒计时页"生日 / 纪念日"区块右上角"导入"按钮 → 授权 → 联系人列表（姓名 + 生日日期预览）→ 勾选 → 导入。

## 边界与错误状态

- 无生日联系人：空态文案；
- 无年份生日：不显示年龄（showAge = false 由 originalYear == nil 推导，编辑器可改）；
- 授权被拒：文案 + 系统设置跳转提示；
- 重名联系人：title 用姓名 + 生日日期区分（Mapper 保证 title 唯一性不做强制，用户可编辑）。

## 验收清单

- [x] MilestoneKit XCTest：映射字段 / 无年份 / 无效日期（2 月 30）拒绝 / 去重
- [x] 倒计时页导入入口 + 授权 + 勾选导入
- [x] NSContactsUsageDescription 声明
- [x] generic iOS Simulator build 通过（真机通讯录验收待做，记入 roadmap）
