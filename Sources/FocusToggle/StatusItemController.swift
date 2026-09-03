import AppKit

final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let state = ToggleState()

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
            accessibilityDescription: "Focus Toggle"
        )
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let setupItem = NSMenuItem(title: "Setup Instructions", action: #selector(showSetupInstructions), keyEquivalent: "")
        setupItem.target = self
        menu.addItem(setupItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func showSetupInstructions() {
        let alert = NSAlert()
        alert.messageText = "One-time setup"
        alert.informativeText = """
        Open Shortcuts.app and create two shortcuts:

        1. "FocusOn" — one action: Set Focus \u{2192} On (Do Not Disturb)
        2. "FocusOff" — one action: Set Focus \u{2192} Off

        FocusToggle runs these by name when you click the menu bar icon.
        """
        alert.addButton(withTitle: "Open Shortcuts.app")
        alert.addButton(withTitle: "Close")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
