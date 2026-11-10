import SwiftUI

/// 铃声选择页：参照系统时钟「声音」页——点行即试听短节选并选中（勾选跟随），
/// 换行即换播，关闭页面即停；无独立"确定"步骤，选中即保存（闹钟本就自动保存）。
struct AlarmSoundPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @Binding var selection: String

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(SmartAlarmSound.allCases) { sound in
                        Button {
                            selection = sound.rawValue
                            AlarmAudio.preview(soundID: sound.rawValue)
                        } label: {
                            HStack {
                                Text(sound.title)
                                    .font(.appText(16))
                                    .foregroundColor(palette.ink)
                                Spacer()
                                if sound.rawValue == selection {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(palette.accent)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("点按任一铃声立即试听片段并选中；系统默认由 iOS 决定音效，响铃页回退「轻快铃」。")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("铃声")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .onDisappear {
            AlarmAudio.stopPreview()
        }
    }
}
