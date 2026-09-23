import CoreImage
import CoreImage.CIFilterBuiltins
import Photos
import SwiftUI
import UIKit
import VisionKit

struct ThirdPartyLicensesView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        List {
            Section {
                Label("Apple SwiftUI", systemImage: "swift")
                Label("Apple VisionKit", systemImage: "viewfinder")
                Label("Apple Core Image", systemImage: "photo")
            } footer: {
                Text(app.localized(
                    "当前原型仅使用 Apple 系统框架，没有额外的第三方运行时依赖。",
                    "This prototype uses only Apple system frameworks and has no additional third-party runtime dependencies."
                ))
            }
        }
        .navigationTitle(app.localized("第三方协议", "Third-Party Licenses"))
    }
}

struct LinkShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppModel
    let project: ProjectItem
    let url: URL
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Form {
                Section(app.localized("临时链接", "Temporary Link")) {
                    Text(url.absoluteString)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)

                    Button(
                        app.localized(copied ? "已复制" : "复制链接", copied ? "Copied" : "Copy Link"),
                        systemImage: copied ? "checkmark" : "doc.on.doc"
                    ) {
                        UIPasteboard.general.url = url
                        copied = true
                    }

                    ShareLink(
                        item: url,
                        subject: Text(project.name),
                        message: Text(app.localized(
                            "通过 IxDL Studio 查看项目原型",
                            "View the project prototype with IxDL Studio"
                        ))
                    ) {
                        Label(app.localized("分享链接", "Share Link"), systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    LabeledContent(
                        app.localized("有效期", "Expires In"),
                        value: app.localized("24 小时", "24 Hours")
                    )
                } footer: {
                    Text(app.localized(
                        "链接过期后，访问者会看到恢复提示，需要项目所有者重新生成。",
                        "After the link expires, visitors will see a recovery message and the project owner must generate a new link."
                    ))
                }
            }
            .navigationTitle(app.localized("生成链接分享", "Share with Link"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(app.localized("完成", "Done")) { dismiss() }
                }
            }
        }
    }
}

struct QRShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppModel
    let project: ProjectItem
    let url: URL
    @State private var saveMessage: String?

    private var qrImage: UIImage? { QRCodeRenderer.image(for: url.absoluteString) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        BrandLockup()

                        HStack(alignment: .center, spacing: 20) {
                            Group {
                                if let qrImage {
                                    Image(uiImage: qrImage)
                                        .resizable()
                                        .interpolation(.none)
                                } else {
                                    Image(systemName: "qrcode")
                                        .resizable()
                                }
                            }
                            .frame(width: 150, height: 150)
                            .padding(10)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(.separator))
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Label(app.localized("二维码已生成", "QR Code Ready"), systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.pink)
                                Text(app.localized("扫码查看项目", "Scan to View Project"))
                                    .font(.title2.weight(.bold))
                                Text(app.localized(
                                    "可通过 IxDL Studio 或系统相机扫码，在手机上快速打开项目。",
                                    "Scan with IxDL Studio or the system camera to quickly open the project on your device."
                                ))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 560, alignment: .leading)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 6)

                    Button(
                        app.localized("保存到手机", "Save to Photos"),
                        systemImage: "square.and.arrow.down",
                        action: saveQRCode
                    )
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                    Text(app.localized(
                        "二维码与链接将在生成 24 小时后失效。",
                        "The QR code and link expire 24 hours after they are generated."
                    ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .background(Color(.secondarySystemBackground))
            .navigationTitle(project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(app.localized("完成", "Done")) { dismiss() }
                }
            }
            .alert(app.localized("保存二维码", "Save QR Code"), isPresented: Binding(
                get: { saveMessage != nil },
                set: { if !$0 { saveMessage = nil } }
            )) {
                Button(app.localized("好", "OK"), role: .cancel) { saveMessage = nil }
            } message: {
                Text(saveMessage ?? "")
            }
        }
    }

    private func saveQRCode() {
        guard let qrImage else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    saveMessage = app.localized(
                        "没有照片写入权限，可在系统设置中开启。",
                        "Photo access is not available. You can enable it in Settings."
                    )
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: qrImage)
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    saveMessage = app.localized(
                        success ? "二维码已保存到照片。" : "保存失败，请稍后再试。",
                        success ? "The QR code was saved to Photos." : "The QR code could not be saved. Try again later."
                    )
                }
            }
        }
    }
}

private enum QRCodeRenderer {
    static func image(for value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)) else {
            return nil
        }
        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct ScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppModel
    let onResult: (String) -> Void
    @State private var manualValue = ""

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerView { payload in
                        onResult(payload)
                        dismiss()
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .bottom) {
                        Text(app.localized(
                            "将二维码放入取景框内，或轻点已识别的二维码",
                            "Place the QR code in the viewfinder, or tap a recognized QR code"
                        ))
                            .font(.footnote)
                            .padding()
                            .background(.regularMaterial, in: Capsule())
                            .padding(.bottom)
                    }
                } else {
                    Form {
                        Section {
                            TextField(
                                app.localized("粘贴 IxDL 分享链接", "Paste an IxDL share link"),
                                text: $manualValue,
                                axis: .vertical
                            )
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Button(app.localized("打开链接", "Open Link")) {
                                onResult(manualValue)
                                dismiss()
                            }
                            .disabled(manualValue.isEmpty)
                        } footer: {
                            Text(app.localized(
                                "当前设备或模拟器不支持实时扫码，可粘贴二维码中的分享链接进行验证。",
                                "Live scanning is unavailable on this device or simulator. Paste the share link from the QR code instead."
                            ))
                        }
                    }
                }
            }
            .navigationTitle(app.localized("扫描二维码", "Scan QR Code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(app.localized("取消", "Cancel")) { dismiss() }
                }
            }
        }
    }
}

private struct DataScannerView: UIViewControllerRepresentable {
    let onResult: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        if !controller.isScanning { try? controller.startScanning() }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onResult: (String) -> Void

        init(onResult: @escaping (String) -> Void) {
            self.onResult = onResult
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard case .barcode(let barcode) = item,
                  let payload = barcode.payloadStringValue else { return }
            onResult(payload)
        }
    }
}

private enum PrototypeSheet: Identifiable {
    case link
    case qr

    var id: Int {
        switch self {
        case .link: 0
        case .qr: 1
        }
    }
}

struct PrototypeView: View {
    @EnvironmentObject private var app: AppModel
    let project: ProjectItem
    let onLeave: () -> Void

    @State private var sheet: PrototypeSheet?
    @State private var isShowingExitHint = false
    @State private var isShowingActions = false
    @State private var runNumber = 1

    var body: some View {
        ZStack {
            Color(.systemGray5).ignoresSafeArea()

            GeometryReader { proxy in
                VStack(spacing: 24) {
                    Spacer()
                    ProjectThumbnail(project: project)
                        .frame(width: min(proxy.size.width * 0.55, 340), height: min(proxy.size.width * 0.55, 340))
                    Text(app.localized("交互 demo 展示界面", "Interactive Demo"))
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text(app.localized(
                        "\(project.name) · 第 \(runNumber) 次运行",
                        "\(project.name) · Run \(runNumber)"
                    ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        isShowingActions = true
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel(app.localized("原型操作", "Prototype Actions"))
                }
                Spacer()
            }
            .padding()
        }
        .background {
            GestureExitCapture(
                shakeEnabled: app.shakeToCloseEnabled,
                fourFingerEnabled: app.fourFingerTouchEnabled,
                onExit: { isShowingActions = true }
            )
        }
        .confirmationDialog(
            app.localized("原型操作", "Prototype Actions"),
            isPresented: $isShowingActions,
            titleVisibility: .visible
        ) {
            Button(app.localized("重新开始原型展示", "Restart Prototype")) {
                runNumber += 1
            }
            Button(app.localized("生成链接分享", "Share with Link")) { sheet = .link }
            Button(app.localized("生成二维码分享", "Share with QR Code")) { sheet = .qr }
            Button(app.localized("离开项目原型", "Leave Project Prototype"), role: .destructive, action: onLeave)
            Button(app.localized("取消", "Cancel"), role: .cancel) { }
        } message: {
            Text(app.localized(
                "你可以在“设置”中更改触发此菜单的方式。",
                "You can change how this menu is triggered in Settings."
            ))
        }
        .overlay {
            if isShowingExitHint {
                PrototypeExitHintDialog(
                    title: app.localized(
                        "您可以通过摇晃手机或4指触屏来退出项目原型。",
                        "Shake the device or use a four-finger tap to exit a project prototype."
                    ),
                    message: app.localized(
                        "你可以在设置中对这个操作方式进行修改",
                        "You can change these options in Settings."
                    ),
                    doNotShowAgainTitle: app.localized("不再提示", "Don't Show Again"),
                    confirmTitle: app.localized("好的", "OK"),
                    onDoNotShowAgain: {
                        UserDefaults.standard.set(true, forKey: "hidePrototypeExitHint")
                        isShowingExitHint = false
                    },
                    onConfirm: {
                        isShowingExitHint = false
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: isShowingExitHint)
        .sheet(item: $sheet) { destination in
            switch destination {
            case .link:
                LinkShareSheet(project: project, url: app.shareURL(for: project))
            case .qr:
                QRShareSheet(project: project, url: app.shareURL(for: project))
            }
        }
        .task(id: project.id) {
            guard !UserDefaults.standard.bool(forKey: "hidePrototypeExitHint") else { return }

            // Wait until the full-screen-cover transition has installed this
            // view before presenting the modal over it.
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled,
                  !UserDefaults.standard.bool(forKey: "hidePrototypeExitHint") else { return }
            isShowingExitHint = true
        }
    }
}

private struct PrototypeExitHintDialog: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let message: String
    let doNotShowAgainTitle: String
    let confirmTitle: String
    let onDoNotShowAgain: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    VStack(spacing: 14) {
                        Text(title)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(message)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Image("ExitGestureGuide")
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? 105 : 150)
                            .accessibilityLabel(Text(title))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                    Divider()

                    dialogButton(doNotShowAgainTitle, action: onDoNotShowAgain)

                    Divider()

                    dialogButton(confirmTitle, action: onConfirm)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: min(420, proxy.size.width - 40))
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 24, y: 10)
                .padding(.vertical, 24)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
            }
        }
    }

    private func dialogButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
    }
}

private struct GestureExitCapture: UIViewRepresentable {
    let shakeEnabled: Bool
    let fourFingerEnabled: Bool
    let onExit: () -> Void

    func makeUIView(context: Context) -> GestureCaptureUIView {
        let view = GestureCaptureUIView()
        view.configure(shakeEnabled: shakeEnabled, fourFingerEnabled: fourFingerEnabled, onExit: onExit)
        return view
    }

    func updateUIView(_ view: GestureCaptureUIView, context: Context) {
        view.configure(shakeEnabled: shakeEnabled, fourFingerEnabled: fourFingerEnabled, onExit: onExit)
    }
}

private final class GestureCaptureUIView: UIView {
    private var shakeEnabled = true
    private var fourFingerEnabled = true
    private var onExit: (() -> Void)?
    private weak var gestureWindow: UIWindow?
    private lazy var fourFingerTap = UITapGestureRecognizer(target: self, action: #selector(didTapWithFourFingers))

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let gestureWindow, gestureWindow !== window {
            gestureWindow.removeGestureRecognizer(fourFingerTap)
        }
        gestureWindow = window
        fourFingerTap.numberOfTouchesRequired = 4
        fourFingerTap.cancelsTouchesInView = false
        if let window, !(window.gestureRecognizers?.contains(fourFingerTap) ?? false) {
            window.addGestureRecognizer(fourFingerTap)
        }
        becomeFirstResponder()
    }

    deinit {
        gestureWindow?.removeGestureRecognizer(fourFingerTap)
    }

    func configure(shakeEnabled: Bool, fourFingerEnabled: Bool, onExit: @escaping () -> Void) {
        self.shakeEnabled = shakeEnabled
        self.fourFingerEnabled = fourFingerEnabled
        self.onExit = onExit
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard shakeEnabled, motion == .motionShake else { return }
        onExit?()
    }

    @objc private func didTapWithFourFingers() {
        guard fourFingerEnabled else { return }
        onExit?()
    }
}
