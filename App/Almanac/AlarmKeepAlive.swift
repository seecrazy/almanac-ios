import AVFoundation
import Foundation
import HolidayData

/// 后台响铃保活：存在启用闹钟时，以极低音量循环播放 keepalive.caf 维持 `.playback`
/// 会话，App 在后台不被挂起；到点由进程内计时器直接进入全屏响铃——无视静音键，
/// 这是通知声音（受静音键约束）之外的兜底响铃路径，也是真闹钟类 App 的通行做法。
/// 能力来源 Info.plist `UIBackgroundModes: audio`。重启后 iOS 清除后台 App，此路径
/// 失效（通知路径仍在），属系统能力边界。
@MainActor
final class AlarmKeepAlive {
    static let shared = AlarmKeepAlive()

    private var player: AVAudioPlayer?
    private var ringTimer: Timer?

    private init() {}

    /// 有任何启用闹钟即保活（音频会话不需要通知权限）。
    func sync(occurrences: [WorkdayAlarmOccurrence], anyAlarmEnabled: Bool) {
        if anyAlarmEnabled {
            startKeepAlive()
            scheduleRingTimer(occurrences: occurrences)
        } else {
            stopKeepAlive()
        }
    }

    private func startKeepAlive() {
        guard player == nil || player?.isPlaying != true else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)

        guard let url = Bundle.main.url(forResource: "keepalive", withExtension: "caf") else {
            return
        }
        let newPlayer = try? AVAudioPlayer(contentsOf: url)
        newPlayer?.volume = 0.01
        newPlayer?.numberOfLoops = -1
        newPlayer?.play()
        player = newPlayer
    }

    private func stopKeepAlive() {
        player?.stop()
        player = nil
        ringTimer?.invalidate()
        ringTimer = nil
        // 响铃中则交由响铃循环持有会话。
        if AlarmRingingController.shared.ringing == nil {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    private func scheduleRingTimer(occurrences: [WorkdayAlarmOccurrence]) {
        ringTimer?.invalidate()
        guard let next = occurrences.first, next.fireDate > Date() else { return }

        ringTimer = Timer(
            fire: next.fireDate,
            interval: 0,
            repeats: false
        ) { [alarm = next.alarm] _ in
            Task { @MainActor in
                AlarmRingingController.shared.start(
                    alarmName: alarm.name,
                    soundID: alarm.soundID
                )
            }
        }
        RunLoop.main.add(ringTimer!, forMode: .common)
    }
}
