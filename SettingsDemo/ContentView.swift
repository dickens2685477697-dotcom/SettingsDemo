import PhotosUI
import SwiftUI
import UIKit

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: Self { self }

    var title: String {
        switch self {
        case .chinese: "中文"
        case .english: "English"
        }
    }

    func text(_ chinese: String, _ english: String) -> String {
        self == .chinese ? chinese : english
    }
}

enum AppCredentials {
    static let username = "Joker"
    static let password = "123456"
}

struct ProjectItem: Identifiable, Hashable {
    let id: UUID
    var name: String
    var updatedAt: Date
    var sizeDescription: String
    var thumbnailData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        updatedAt: Date,
        sizeDescription: String = "500 KB",
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.updatedAt = updatedAt
        self.sizeDescription = sizeDescription
        self.thumbnailData = thumbnailData
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var isAuthenticated: Bool
    @Published var projects: [ProjectItem]
    @Published var activeProject: ProjectItem?
    @Published var recoveryMessage: String?
    @Published var shakeToCloseEnabled = true
    @Published var fourFingerTouchEnabled = true
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "ixdl.appLanguage")
        }
    }

    private var pendingProject: ProjectItem?

    private static let authenticationKey = "ixdl.isAuthenticated.v2"

    init() {
        let initialLanguage = AppLanguage(
            rawValue: UserDefaults.standard.string(forKey: "ixdl.appLanguage") ?? ""
        ) ?? .chinese
        isAuthenticated = UserDefaults.standard.bool(forKey: Self.authenticationKey)
        language = initialLanguage
        projects = [
            ProjectItem(name: "文件名1", updatedAt: .now.addingTimeInterval(-1_440)),
            ProjectItem(name: "文件名2", updatedAt: .now.addingTimeInterval(-86_400))
        ]
    }

    var sortedProjects: [ProjectItem] {
        projects.sorted { $0.updatedAt > $1.updatedAt }
    }

    func localized(_ chinese: String, _ english: String) -> String {
        language.text(chinese, english)
    }

    func listDateTime(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(Locale(identifier: language.rawValue))
                .month(.abbreviated).day().hour().minute()
        )
    }

    func abbreviatedDateTime(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(Locale(identifier: language.rawValue))
                .year().month(.abbreviated).day().hour().minute()
        )
    }

    func login(account: String, password: String) -> Bool {
        let normalizedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedAccount == AppCredentials.username,
              password == AppCredentials.password else { return false }

        isAuthenticated = true
        UserDefaults.standard.set(true, forKey: Self.authenticationKey)
        UserDefaults.standard.removeObject(forKey: "hidePrototypeExitHint")
        if let pendingProject {
            activeProject = pendingProject
            self.pendingProject = nil
        }
        return true
    }

    func logout() {
        activeProject = nil
        pendingProject = nil
        isAuthenticated = false
        UserDefaults.standard.set(false, forKey: Self.authenticationKey)
        UserDefaults.standard.removeObject(forKey: "hidePrototypeExitHint")
    }

    @discardableResult
    func importProject(imageData: Data) -> ProjectItem {
        let project = ProjectItem(
            name: localized("新项目 \(projects.count + 1)", "New Project \(projects.count + 1)"),
            updatedAt: .now,
            sizeDescription: ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file),
            thumbnailData: imageData
        )
        projects.append(project)
        return project
    }

    func remove(_ project: ProjectItem) {
        projects.removeAll { $0.id == project.id }
    }

    func shareURL(for project: ProjectItem) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "share.ixdl.studio"
        components.path = "/project/\(project.id.uuidString)"
        components.queryItems = [
            URLQueryItem(name: "name", value: project.name),
            URLQueryItem(name: "expires", value: String(Int(Date().addingTimeInterval(86_400).timeIntervalSince1970)))
        ]
        return components.url!
    }

    func handleIncomingURL(_ url: URL) {
        guard url.scheme == "ixdl" || url.host == "share.ixdl.studio" else {
            recoveryMessage = localized(
                "该链接不是有效的 IxDL Studio 项目链接。",
                "This is not a valid IxDL Studio project link."
            )
            return
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let expiryText = components?.queryItems?.first(where: { $0.name == "expires" })?.value,
           let expiry = TimeInterval(expiryText),
           Date(timeIntervalSince1970: expiry) < .now {
            recoveryMessage = localized(
                "该分享已过期。请联系项目所有者重新生成链接或二维码。",
                "This share has expired. Ask the project owner to generate a new link or QR code."
            )
            return
        }

        let idText = url.pathComponents.last(where: { $0 != "/" })
        let parsedID = idText.flatMap(UUID.init(uuidString:))
        let name = components?.queryItems?.first(where: { $0.name == "name" })?.value
            ?? localized("共享项目", "Shared Project")
        let project = parsedID.flatMap { id in projects.first { $0.id == id } }
            ?? ProjectItem(id: parsedID ?? UUID(), name: name, updatedAt: .now)

        if isAuthenticated {
            activeProject = project
        } else {
            pendingProject = project
        }
    }

    func handleScannedPayload(_ payload: String) {
        guard let url = URL(string: payload) else {
            recoveryMessage = localized(
                "二维码内容无法识别。请确认它来自 IxDL Studio。",
                "The QR code could not be recognized. Make sure it came from IxDL Studio."
            )
            return
        }
        handleIncomingURL(url)
    }
}

struct ContentView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        Group {
            if app.isAuthenticated {
                AdaptiveHomeView()
            } else {
                LoginView()
            }
        }
        .fullScreenCover(item: $app.activeProject) { project in
            PrototypeView(project: project) {
                app.activeProject = nil
            }
            .environmentObject(app)
        }
        .alert(
            app.localized("无法打开项目", "Unable to Open Project"),
            isPresented: Binding(
                get: { app.recoveryMessage != nil },
                set: { if !$0 { app.recoveryMessage = nil } }
            )
        ) {
            Button(app.localized("好", "OK"), role: .cancel) { app.recoveryMessage = nil }
        } message: {
            Text(app.recoveryMessage ?? app.localized("未知错误", "Unknown error"))
        }
    }
}

private struct LoginView: View {
    @EnvironmentObject private var app: AppModel
    @State private var account = AppCredentials.username
    @State private var password = ""
    @State private var remembersAccount = true
    @State private var isPasswordVisible = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case account, password }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(app.localized("登录到", "Sign in to"))
                            .font(.largeTitle.weight(.semibold))
                        BrandLockup(isLarge: true)
                    }
                    .accessibilityElement(children: .combine)

                    VStack(spacing: 20) {
                        Label {
                            TextField("Account", text: $account)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .account)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                        } icon: {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                        Label {
                            HStack {
                                Group {
                                    if isPasswordVisible {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit(login)

                                Button {
                                    isPasswordVisible.toggle()
                                } label: {
                                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(app.localized(
                                    isPasswordVisible ? "隐藏密码" : "显示密码",
                                    isPasswordVisible ? "Hide password" : "Show password"
                                ))
                            }
                        } icon: {
                            Image(systemName: "lock")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                        Toggle(app.localized("记住账号", "Remember account"), isOn: $remembersAccount)
                    }

                    Button(action: login) {
                        Text(app.localized("登录", "Sign In"))
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(account.isEmpty || password.isEmpty)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .padding(.vertical, 80)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemBackground))
        }
    }

    private func login() {
        if app.login(account: account, password: password) {
            errorMessage = nil
        } else {
            errorMessage = app.localized(
                "账号或密码错误，请使用已保存的账号登录。",
                "Incorrect account or password. Use the saved account to sign in."
            )
        }
    }
}

private enum HomeSheet: Identifiable {
    case settings
    case scanner
    case link(ProjectItem)
    case qr(ProjectItem)

    var id: String {
        switch self {
        case .settings: "settings"
        case .scanner: "scanner"
        case .link(let project): "link-\(project.id)"
        case .qr(let project): "qr-\(project.id)"
        }
    }
}

private struct AdaptiveHomeView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedProjectID: ProjectItem.ID?
    @State private var sheet: HomeSheet?
    @State private var actionProject: ProjectItem?
    @State private var isShowingProjectActions = false
    @State private var importedPhoto: PhotosPickerItem?

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .settings:
                SettingsView()
                    .environmentObject(app)
            case .scanner:
                ScannerSheet { payload in
                    sheet = nil
                    app.handleScannedPayload(payload)
                }
            case .link(let project):
                LinkShareSheet(project: project, url: app.shareURL(for: project))
            case .qr(let project):
                QRShareSheet(project: project, url: app.shareURL(for: project))
            }
        }
        .confirmationDialog(
            actionProject.map { "\($0.name)  \($0.sizeDescription)" }
                ?? app.localized("项目操作", "Project Actions"),
            isPresented: $isShowingProjectActions,
            titleVisibility: .visible
        ) {
            if let project = actionProject {
                Button(app.localized("生成链接分享", "Share with Link")) { sheet = .link(project) }
                Button(app.localized("生成二维码分享", "Share with QR Code")) { sheet = .qr(project) }
                Button(app.localized("移除项目原型", "Remove Project Prototype"), role: .destructive) {
                    app.remove(project)
                    if selectedProjectID == project.id { selectedProjectID = nil }
                }
            }
            Button(app.localized("取消", "Cancel"), role: .cancel) { }
        }
        .onChange(of: importedPhoto) { newValue in
            guard let newValue else { return }
            Task {
                guard let data = try? await newValue.loadTransferable(type: Data.self) else { return }
                let project = app.importProject(imageData: data)
                selectedProjectID = project.id
                importedPhoto = nil
            }
        }
    }

    private var iPhoneLayout: some View {
        NavigationStack {
            projectList { project in
                app.activeProject = project
            }
            .toolbar { homeToolbar }
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            projectList { project in
                selectedProjectID = project.id
            }
            .navigationTitle(app.localized("项目原型", "Project Prototypes"))
            .toolbar { homeToolbar }
        } detail: {
            if let project = app.sortedProjects.first(where: { $0.id == selectedProjectID }) {
                ProjectDetailView(project: project) {
                    app.activeProject = project
                } shareLink: {
                    sheet = .link(project)
                } shareQR: {
                    sheet = .qr(project)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(.largeTitle, design: .rounded).weight(.light))
                        .foregroundStyle(.secondary)
                    Text(app.localized("选择一个项目原型", "Select a Project Prototype"))
                        .font(.title2)
                    Text(app.localized(
                        "查看项目详情，或直接打开原型进行体验。",
                        "Select a project, then open its prototype to begin."
                    ))
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding()
            }
        }
    }

    private func projectList(open: @escaping (ProjectItem) -> Void) -> some View {
        List {
            Section(app.localized("项目原型", "Project Prototypes")) {
                ForEach(app.sortedProjects) { project in
                    ProjectRow(project: project) {
                        open(project)
                    } showActions: {
                        actionProject = project
                        isShowingProjectActions = true
                    }
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
    }

    @ToolbarContentBuilder
    private var homeToolbar: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .navigationBarLeading) {
                BrandLockup()
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigationBarLeading) {
                BrandLockup()
            }
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            PhotosPicker(selection: $importedPhoto, matching: .images) {
                Image(systemName: "camera")
            }
            .accessibilityLabel(app.localized("导入项目预览", "Import Project Preview"))

            Button { sheet = .scanner } label: {
                Image(systemName: "qrcode.viewfinder")
            }
            .accessibilityLabel(app.localized("扫描项目二维码", "Scan Project QR Code"))

            Button { sheet = .settings } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(app.localized("设置", "Settings"))
        }
    }
}

private struct ProjectRow: View {
    @EnvironmentObject private var app: AppModel
    let project: ProjectItem
    let open: () -> Void
    let showActions: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 12) {
                    ProjectThumbnail(project: project)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(project.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(app.localized(
                            "更新于 \(app.listDateTime(project.updatedAt))",
                            "Updated \(app.listDateTime(project.updatedAt))"
                        ))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: showActions) {
                Image(systemName: "ellipsis")
                    .frame(width: 30, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(app.localized("\(project.name)操作", "Actions for \(project.name)"))
        }
        .frame(minHeight: 83)
    }
}

struct ProjectThumbnail: View {
    let project: ProjectItem

    var body: some View {
        Group {
            if let data = project.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("ProjectPreview")
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 83, height: 83)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.separator), lineWidth: 0.5)
        }
    }
}

private struct ProjectDetailView: View {
    @EnvironmentObject private var app: AppModel
    let project: ProjectItem
    let open: () -> Void
    let shareLink: () -> Void
    let shareQR: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ProjectThumbnail(project: project)
                    .frame(width: 220, height: 220)
                VStack(spacing: 8) {
                    Text(project.name)
                        .font(.largeTitle.weight(.semibold))
                    Text(app.localized(
                        "更新于 \(app.abbreviatedDateTime(project.updatedAt))",
                        "Updated \(app.abbreviatedDateTime(project.updatedAt))"
                    ))
                        .foregroundStyle(.secondary)
                }
                Button(app.localized("打开项目原型", "Open Prototype"), systemImage: "play.fill", action: open)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                HStack {
                    Button(app.localized("分享链接", "Share Link"), systemImage: "link", action: shareLink)
                    Button(app.localized("二维码", "QR Code"), systemImage: "qrcode", action: shareQR)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(40)
        }
        .navigationTitle(project.name)
    }
}

struct BrandLockup: View {
    var isLarge = false

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: isLarge ? 12 : 8) {
            Image("IxDLLogo")
                .resizable()
                .scaledToFit()
                .frame(width: isLarge ? 118 : 62, height: isLarge ? 40 : 22)
                .alignmentGuide(.lastTextBaseline) { dimensions in
                    dimensions[.bottom]
                }
            Text("studio")
                .font(isLarge ? .largeTitle.weight(.semibold) : .title2.weight(.semibold))
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("IxDL studio")
    }
}

#Preview("登录") {
    ContentView()
        .environmentObject(AppModel())
}
