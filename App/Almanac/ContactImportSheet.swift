import Contacts
import MilestoneKit
import SwiftUI

/// 通讯录生日导入面板：授权 → 拉取含生日的联系人 → 勾选 → 批量保存为生日 Anniversary。
struct ContactImportSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var milestoneStore: MilestoneStore

    @State private var candidates: [ContactBirthdayCandidate] = []
    @State private var selectedIDs: Set<String> = []
    @State private var authorizationDenied = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                if authorizationDenied {
                    deniedView
                } else if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 40)
                } else if candidates.isEmpty {
                    emptyView
                } else {
                    list
                }
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("导入联系人生日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "导入中…" : "导入") {
                        importSelected()
                    }
                    .disabled(selectedIDs.isEmpty || isSaving)
                }
            }
            .task { await load() }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(candidates, id: \.contactID) { candidate in
                    Button {
                        toggle(candidate)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(candidate.displayName)
                                    .foregroundColor(palette.ink)
                                Text(birthdayPreview(candidate))
                                    .font(.system(size: 12))
                                    .foregroundColor(palette.secondary)
                            }
                            Spacer()
                            Image(systemName: selectedIDs.contains(candidate.contactID) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedIDs.contains(candidate.contactID) ? palette.accent : palette.secondary)
                        }
                    }
                }
            } footer: {
                Text("仅读取姓名与生日两个字段；导入后为快照，联系人更新生日不会自动同步。")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Text("没有找到带生日的联系人")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(palette.ink)
            Text("在系统通讯录中为联系人填写生日后可再导入。")
                .font(.system(size: 13))
                .foregroundColor(palette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedView: some View {
        VStack(spacing: 10) {
            Text("无法访问通讯录")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(palette.ink)
            Text("请到系统设置 > 隐私与安全性 > 通讯录中开启权限。")
                .font(.system(size: 13))
                .foregroundColor(palette.secondary)
                .multilineTextAlignment(.center)
            OpenSettingsLink()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func birthdayPreview(_ candidate: ContactBirthdayCandidate) -> String {
        let yearText = (candidate.year ?? 0) >= 1901 ? "\(candidate.year!)年" : ""
        return "\(yearText)\(candidate.month)月\(candidate.day)日 · 生日"
    }

    private func toggle(_ candidate: ContactBirthdayCandidate) {
        if selectedIDs.contains(candidate.contactID) {
            selectedIDs.remove(candidate.contactID)
        } else {
            selectedIDs.insert(candidate.contactID)
        }
    }

    private func load() async {
        let store = CNContactStore()
        let granted = (try? await store.requestAccess(for: .contacts)) ?? false
        guard granted else {
            authorizationDenied = true
            isLoading = false
            return
        }

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as NSString,
            CNContactFamilyNameKey as NSString,
            CNContactBirthdayKey as NSString,
            CNContactIdentifierKey as NSString
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var loaded: [ContactBirthdayCandidate] = []
        let existing = milestoneStore.anniversaries

        _ = try? store.enumerateContacts(with: request) { contact, _ in
            guard let birthday = contact.birthday,
                  let month = birthday.month,
                  let day = birthday.day else { return }
            let name = [contact.familyName, contact.givenName]
                .filter { !$0.isEmpty }
                .joined()
            guard !name.isEmpty else { return }
            loaded.append(ContactBirthdayCandidate(
                contactID: contact.identifier,
                displayName: name,
                month: month,
                day: day,
                year: birthday.year
            ))
        }

        // 已导入的联系人不再出现在候选列表。
        candidates = loaded
            .filter { !ContactBirthdayMapper.isImported(contactID: $0.contactID, existing: existing) }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
        isLoading = false
    }

    private func importSelected() {
        isSaving = true
        let chosen = candidates.filter { selectedIDs.contains($0.contactID) }

        Task {
            for candidate in chosen {
                guard let anniversary = ContactBirthdayMapper.anniversary(
                    for: candidate,
                    existing: milestoneStore.anniversaries
                ) else { continue }
                await milestoneStore.save(anniversary)
            }
            isSaving = false
            dismiss()
        }
    }
}
