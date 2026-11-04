import Foundation
import NaturalInput

struct QuickComposerContext: Identifiable {
    let id = UUID()
    let date: Date
    let draft: QuickEventDraft?
    let warnings: [String]
}
