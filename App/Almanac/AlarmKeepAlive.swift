import AVFoundation
import Foundation
import HolidayData

/// 后台响铃保活：存在启用闹钟时，以极低音量循环播放 keepalive.caf 维持 `.playback`
/// 会话，App 在后台不被挂起，到点由进程内计时器直接全屏响铃——无视静音键。
///
/// 健壮性设计（v1.6，修真机"只有通知不响铃"）：
/// 1. 有效电平约 -60dB（文件 0.05 × 音量 0.2）——实际听不见但非数字静音，
///    避免 iOS 回收输出静音的会话；
/// 2. 会话带 `.mixWithOthers`：与用户音乐 / 视频**共存**而非互斥，不会被对方
///    抢占导致保活中断（睡前听歌场景）；
/// 3. 监听音频会话中断与媒体服务重置，结束后自动恢复播放。
///
/// 系统能力边界（无法绕过）：用户上滑强杀 App、手机重启后保活与通知双双失效，
/// 需开一次 App 重挂；极端内存压力下长夜后台存在小概率被回收。
@MainActor
final class AlarmKeepAlive {
    static let shared = AlarmKeepAlive()

    private var player: AVAudioPlayer?
    private var ringTimer: Timer?
    private var interruptionObserver: NSObjectProtocol?
    private var mediaResetObserver: NSObjectProtocol?

    private init() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeRaw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let type = typeRaw.flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            Task { @MainActor in
                self?.handleInterruption(type: type ?? .began)
            }
        }
        mediaResetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.restart()
            }
        }
    }

    /// 供闹钟页展示的自检状态。
    var isRunning: Bool {
        player?.isPlaying == true
    }

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
        if player?.isPlaying == true { return }
        try? startPlayer()
    }

    private func startPlayer() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)

        guard let url = Bundle.main.url(forResource: "keepalive", withExtension: "caf") else {
            return
        }
        let newPlayer = try AVAudioPlayer(contentsOf: url)
        newPlayer.volume = 0.2
        newPlayer.numberOfLoops = -1
        newPlayer.play()
        player = newPlayer
    }

    /// 中断结束 / 媒体服务重置后恢复：重建会话与播放器。
    private func handleInterruption(type: AVAudioSession.InterruptionType) {
        switch type {
        case .ended:
            restart()
        case .began:
            break
        @unknown default:
            break
        }
    }

    private func restart() {
        guard player != nil else { return }
        player?.stop()
        player = nil
        try? startPlayer()
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
