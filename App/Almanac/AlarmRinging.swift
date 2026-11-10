import AVFoundation
import SwiftUI
import UserNotifications

/// 响铃上下文：闹钟通知触发（前台 willPresent / 用户点按 didReceive）时生成。
struct AlarmRingingContext: Identifiable {
    let id = UUID()
    let alarmName: String
    let soundID: String
    let firedAt: Date
}

/// 闹钟声音播放。试听走 ambient（尊重静音键）；响铃走 playback（无视静音键，
/// 这是"到点会响"的关键——通知自带声音受静音键约束，App 内循环不受）。
/// 系统默认音无法被 AVAudioPlayer 播放，响铃与试听回退「轻快铃」。
enum AlarmAudio {
    private static var previewPlayer: AVAudioPlayer?
    private static var loopPlayer: AVAudioPlayer?

    static func url(for soundID: String) -> URL? {
        let sound = SmartAlarmSound(rawValue: soundID) ?? .systemDefault
        let fileName = sound == .systemDefault ? SmartAlarmSound.lightBell.rawValue : sound.rawValue
        return Bundle.main.url(forResource: fileName, withExtension: "caf")
    }

    static func preview(soundID: String) {
        stopLoop()
        guard let url = url(for: soundID) else { return }
        let session = AVAudioSession.sharedInstance()
        // 试听是用户主动行为：用 playback 类别，静音键打开也能听到。
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        previewPlayer = try? AVAudioPlayer(contentsOf: url)
        previewPlayer?.volume = 1
        previewPlayer?.numberOfLoops = 0
        previewPlayer?.play()
    }

    static func startLoop(soundID: String) {
        stopLoop()
        guard let url = url(for: soundID) else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        loopPlayer = try? AVAudioPlayer(contentsOf: url)
        loopPlayer?.volume = 1
        loopPlayer?.numberOfLoops = -1
        loopPlayer?.play()
    }

    static func stopLoop() {
        loopPlayer?.stop()
        loopPlayer = nil
        previewPlayer?.stop()
        previewPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

/// 全屏响铃控制器；通知代理经 shared 触发，RootView fullScreenCover 消费。
@MainActor
final class AlarmRingingController: ObservableObject {
    static let shared = AlarmRingingController()

    @Published var ringing: AlarmRingingContext?

    private init() {}

    func start(alarmName: String, soundID: String) {
        // 计时器与前台 willPresent 可能同秒触发；同一闹钟 5 秒内只启动一次。
        if let current = ringing,
           current.alarmName == alarmName,
           Date().timeIntervalSince(current.firedAt) < 5 {
            return
        }
        ringing = AlarmRingingContext(
            alarmName: alarmName,
            soundID: soundID,
            firedAt: Date()
        )
        AlarmAudio.startLoop(soundID: soundID)
    }

    func stop() {
        ringing = nil
        AlarmAudio.stopLoop()
    }

    /// 稍后提醒：5 分钟后单条即时通知，复用闹钟前缀与声音（触发时再次进响铃页）。
    func snooze() {
        guard let context = ringing else { return }
        stop()

        let content = UNMutableNotificationContent()
        content.title = context.alarmName.isEmpty ? "智能闹钟" : context.alarmName
        content.body = "稍后提醒 · 5 分钟后再次响铃"
        content.sound = SmartAlarmSound(rawValue: context.soundID)?.notificationSound ?? .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["alarmName": context.alarmName, "soundID": context.soundID]

        let request = UNNotificationRequest(
            identifier: "workday-alarm.snooze.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5 * 60, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}

/// 全屏响铃页：大号时间 + 循环铃声 + 停止 / 稍后提醒。
struct AlarmRingingView: View {
    @ObservedObject private var controller = AlarmRingingController.shared
    @EnvironmentObject private var alarmStore: WorkdayAlarmStore

    let context: AlarmRingingContext

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 10) {
                Label(
                    context.alarmName.isEmpty ? "智能闹钟" : context.alarmName,
                    systemImage: "alarm.fill"
                )
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))

                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(timeline.date, format: .dateTime.hour().minute().second())
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                }
                Text(context.firedAt, format: .dateTime.month().day().weekday())
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            VStack(spacing: 14) {
                Button {
                    controller.stop()
                    // 停止后重排：滑动通知窗口并重挂下一次响铃计时器。
                    Task { await alarmStore.reschedule() }
                } label: {
                    Text("停止")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().fill(.white))
                }

                Button {
                    controller.snooze()
                } label: {
                    Text("稍后提醒 · 5 分钟")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
    }
}
