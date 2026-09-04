import AppKit

final class SettingsWindowController: NSWindowController {
    private let iconPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let dndOnlyCheckbox = NSButton(checkboxWithTitle: "방해금지 모드만 사용 (시계는 안 가림)", target: nil, action: nil)
    var onIconStyleChanged: (() -> Void)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 140),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "FocusToggle 설정"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildUI()
        loadCurrentSettings()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let iconLabel = NSTextField(labelWithString: "메뉴바 아이콘")
        iconLabel.frame = NSRect(x: 20, y: 95, width: 100, height: 20)
        contentView.addSubview(iconLabel)

        iconPopUp.frame = NSRect(x: 120, y: 92, width: 180, height: 26)
        for style in MenuBarIconStyle.allCases {
            iconPopUp.addItem(withTitle: style.displayName)
        }
        iconPopUp.target = self
        iconPopUp.action = #selector(iconStyleChanged)
        contentView.addSubview(iconPopUp)

        dndOnlyCheckbox.frame = NSRect(x: 20, y: 50, width: 280, height: 24)
        dndOnlyCheckbox.target = self
        dndOnlyCheckbox.action = #selector(dndOnlyChanged)
        contentView.addSubview(dndOnlyCheckbox)

        let closeButton = NSButton(title: "닫기", target: self, action: #selector(closeSettings))
        closeButton.frame = NSRect(x: 220, y: 15, width: 80, height: 28)
        closeButton.bezelStyle = .rounded
        contentView.addSubview(closeButton)
    }

    private func loadCurrentSettings() {
        let settings = AppSettings.shared
        let index = MenuBarIconStyle.allCases.firstIndex(of: settings.iconStyle) ?? 0
        iconPopUp.selectItem(at: index)
        dndOnlyCheckbox.state = settings.dndOnlyMode ? .on : .off
    }

    @objc private func iconStyleChanged() {
        let index = iconPopUp.indexOfSelectedItem
        guard index >= 0, index < MenuBarIconStyle.allCases.count else { return }
        AppSettings.shared.iconStyle = MenuBarIconStyle.allCases[index]
        onIconStyleChanged?()
    }

    @objc private func dndOnlyChanged() {
        AppSettings.shared.dndOnlyMode = (dndOnlyCheckbox.state == .on)
    }

    @objc private func closeSettings() {
        window?.close()
    }
}
