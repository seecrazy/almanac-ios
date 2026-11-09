import AppIntents
import Foundation
import SwiftUI

/// Intent 与 App 主进程之间的短语信箱：perform() 写入，RootView 消费。
@MainActor
final class QuickIntentMailbox: ObservableObject {
    static let shared = QuickIntentMailbox()

    @Published var pendingPhrase: String?

    private init() {}
}

/// 自然语言记日程：解析与保存全部发生在 App 内（ADR-008 确认流），
/// Intent 只负责带参唤起 App 并预填快速输入框。
@available(iOS 16.0, *)
struct QuickEventIntent: AppIntent {
    static var title: LocalizedStringResource = "用自然语言记日程"
    static var description = IntentDescription(
        "输入如「明天下午3点到5点 开会 @会议室」，宜历解析后打开确认页。"
    )
    static var openAppWhenRun = true

    @Parameter(title: "日程描述", requestValueDialog: "要记什么日程？")
    var phrase: String

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickIntentMailbox.shared.pendingPhrase = phrase
        return .result()
    }
}

@available(iOS 16.0, *)
struct AlmanacShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickEventIntent(),
            phrases: [
                "用\(.applicationName)记日程",
                "用\(.applicationName)添加日程"
            ],
            shortTitle: "记日程",
            systemImageName: "calendar.badge.plus"
        )
    }
}
