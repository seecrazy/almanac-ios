#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import MilestoneKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct MilestoneLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(
            for: MilestoneCountdownAttributes.self
        ) { context in
            lockScreenView(context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdownText(context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.categoryTitle)
                        .font(.system(size: 11))
                        .opacity(0.7)
                }
            } compactLeading: {
                Image(systemName: "hourglass")
                    .font(.system(size: 12))
            } compactTrailing: {
                compactCountdown(context)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "hourglass")
                    .font(.system(size: 12))
            }
        }
    }

    private func lockScreenView(_ context: ActivityViewContext<MilestoneCountdownAttributes>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(context.attributes.categoryTitle)
                    .font(.system(size: 11))
                    .opacity(0.7)
            }
            Spacer()
            countdownText(context)
        }
        .padding(14)
        .activityBackgroundTint(Color(red: 0.988, green: 0.968, blue: 0.929))
    }

    private func countdownText(_ context: ActivityViewContext<MilestoneCountdownAttributes>) -> some View {
        Text(timerInterval: context.state.targetDate...max(context.state.targetDate, .now.addingTimeInterval(1)), countsDown: true)
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .frame(maxWidth: 90)
            .minimumScaleFactor(0.7)
    }

    private func compactCountdown(_ context: ActivityViewContext<MilestoneCountdownAttributes>) -> some View {
        let interval = context.state.targetDate.timeIntervalSince(.now)
        let minutes = max(0, Int(interval / 60))
        if minutes >= 60 { return Text("\(minutes / 60)h") }
        return Text("\(minutes)m")
    }
}
#endif
