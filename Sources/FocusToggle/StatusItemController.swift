import AppKit

final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let state = ToggleState()
    private let clockOverlay = ClockOverlayController()

    override init() {
        super.init()
        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        updateIcon(isOn: false)
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggle()
        }
    }

    private func toggle() {
        let isOn = state.toggle()
        updateIcon(isOn: isOn)
        if isOn {
            clockOverlay.show()
        } else {
            clockOverlay.hide()
        }
        let action: FocusAction = isOn ? .turnOn : .turnOff
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let succeeded = FocusActionRunner.run(action)
            if !succeeded {
                DispatchQueue.main.async {
                    self?.showSetupInstructions()
                }
            }
        }
    }

    private func updateIcon(isOn: Bool) {
        statusItem.button?.image = NSImage(
            systemSymbolName: isOn ? "moon.fill" : "moon",
            accessibilityDescription: "포커스 토글"
        )
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let setupItem = NSMenuItem(title: "설정 방법", action: #selector(showSetupInstructions), keyEquivalent: "")
        setupItem.target = self
        menu.addItem(setupItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func showSetupInstructions() {
        let alert = NSAlert()
        alert.messageText = "최초 설정"
        alert.informativeText = """
        Shortcuts 앱을 열어서 샷컷 2개를 만들어야 합니다:

        1. "FocusOn" — 액션 하나: Set Focus \u{2192} On (방해금지모드)
        2. "FocusOff" — 액션 하나: Set Focus \u{2192} Off

        FocusToggle이 메뉴바 아이콘을 클릭할 때 이 이름으로 샷컷을 실행합니다.
        """
        alert.addButton(withTitle: "Shortcuts 앱 열기")
        alert.addButton(withTitle: "닫기")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
