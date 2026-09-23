import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppModel

    @State private var isShowingLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                closeMethodSection
                languageSection
                aboutSection
                logoutSection
            }
            .navigationTitle(app.localized("设置", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(app.localized("完成", "Done")) {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                app.localized("确定要退出登录吗？", "Are you sure you want to sign out?"),
                isPresented: $isShowingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button(app.localized("退出登录", "Sign Out"), role: .destructive) {
                    dismiss()
                    app.logout()
                }
                Button(app.localized("取消", "Cancel"), role: .cancel) { }
            }
        }
    }

    private var accountSection: some View {
        Section(app.localized("账户", "Account")) {
            AccountRow(name: AppCredentials.username)
        }
    }

    private var closeMethodSection: some View {
        Section {
            Toggle(app.localized("摇晃手机", "Shake iPhone"), isOn: $app.shakeToCloseEnabled)
            Toggle(app.localized("4 指触屏", "Four-Finger Tap"), isOn: $app.fourFingerTouchEnabled)
        } header: {
            Text(app.localized("关闭项目原型的方式", "Ways to Close a Project Prototype"))
        } footer: {
            Text(app.localized(
                "同时关闭后仅能通过强制退出APP关闭项目原型",
                "With both options off, the project prototype can only be closed by force quitting the app."
            ))
            .foregroundStyle(.secondary)
            .opacity(app.shakeToCloseEnabled || app.fourFingerTouchEnabled ? 0 : 1)
            .accessibilityHidden(app.shakeToCloseEnabled || app.fourFingerTouchEnabled)
        }
    }

    private var languageSection: some View {
        Section(app.localized("语言", "Language")) {
            Picker(app.localized("界面语言", "App Language"), selection: $app.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var aboutSection: some View {
        Section(app.localized("关于", "About")) {
            LabeledContent(app.localized("版本", "Version"), value: "1.0.0")

            NavigationLink(app.localized("第三方协议", "Third-Party Licenses")) {
                ThirdPartyLicensesView()
            }
        }
    }

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                isShowingLogoutConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text(app.localized("退出登录", "Sign Out"))
                    Spacer()
                }
            }
        }
    }

}

#Preview("设置") {
    SettingsView()
        .environmentObject(AppModel())
}

#Preview("设置 · 深色") {
    SettingsView()
        .environmentObject(AppModel())
        .preferredColorScheme(.dark)
}

#Preview("设置 · 大字体") {
    SettingsView()
        .environmentObject(AppModel())
        .environment(\.dynamicTypeSize, .accessibility2)
}
