import AppKit

final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let state = ToggleState()
    private let clockOverlay = ClockOverlayController()
    private var scheduledOffTimer: Timer?
    private let settingsWindowController = SettingsWindowController()
    private let autoScheduleController = AutoScheduleController()
    private let nowPlaying = NowPlayingController()
    private let nowPlayingPopover = NSPopover()
    private lazy var nowPlayingViewController = NowPlayingPopoverViewController(nowPlaying: nowPlaying)
    private var nowPlayingRefreshTimer: Timer?

    override init() {
        super.init()
        configureButton()
        settingsWindowController.onIconStyleChanged = { [weak self] in
            self?.updateIcon(isOn: self?.state.isOn ?? false)
        }
        settingsWindowController.onScheduleChanged = { [weak self] in
            self?.autoScheduleController.reschedule()
        }
        autoScheduleController.turnOnAction = { [weak self] in self?.applyOn() }
        autoScheduleController.turnOffAction = { [weak self] in self?.applyOff() }
        autoScheduleController.reschedule()

        nowPlayingViewController.onFocusToggle = { [weak self] in
            guard let self else { return }
            self.toggle()
            self.nowPlayingViewController.refresh(isFocusOn: self.state.isOn)
        }
        nowPlayingPopover.behavior = .transient
        nowPlayingPopover.contentViewController = nowPlayingViewController
        nowPlayingPopover.delegate = self
    }

    func popoverDidClose(_ notification: Notification) {
        nowPlayingRefreshTimer?.invalidate()
        nowPlayingRefreshTimer = nil
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
            showNowPlayingPopover()
        }
    }

    private func showNowPlayingPopover() {
        guard let button = statusItem.button else { return }
        if nowPlayingPopover.isShown {
            nowPlayingPopover.performClose(nil)
            return
        }
        nowPlayingViewController.refresh(isFocusOn: state.isOn)
        nowPlayingPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        nowPlayingRefreshTimer?.invalidate()
        nowPlayingRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.nowPlayingViewController.refresh(isFocusOn: self.state.isOn)
        }
    }

    private func toggle() {
        if state.isOn {
            applyOff()
        } else {
            applyOn()
            promptForScheduledOff()
        }
    }

    private func applyOn() {
        guard !state.isOn else { return }
        _ = state.toggle()
        updateIcon(isOn: true)
        if !AppSettings.shared.dndOnlyMode {
            clockOverlay.show()
        }
        runFocusAction(.turnOn)
    }

    private func applyOff() {
        guard state.isOn else { return }
        _ = state.toggle()
        updateIcon(isOn: false)
        if !AppSettings.shared.dndOnlyMode {
            clockOverlay.hide()
        }
        scheduledOffTimer?.invalidate()
        scheduledOffTimer = nil
        runFocusAction(.turnOff)
    }

    private func runFocusAction(_ action: FocusAction) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let succeeded = FocusActionRunner.run(action)
            if !succeeded {
                DispatchQueue.main.async {
                    self?.showSetupInstructions()
                }
            }
        }
    }

    private func promptForScheduledOff() {
        let alert = NSAlert()
        alert.messageText = "종료 시간 설정 (선택)"
        alert.informativeText = "이 시간이 되면 자동으로 꺼지고 화면에 알림이 뜹니다. 필요 없으면 \"설정 안 함\"을 누르세요."
        let picker = NSDatePicker(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        picker.datePickerElements = .hourMinute
        picker.datePickerMode = .single
        picker.dateValue = Date()
        alert.accessoryView = picker
        alert.addButton(withTitle: "설정")
        alert.addButton(withTitle: "설정 안 함")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: picker.dateValue)
        guard let target = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else { return }

        scheduledOffTimer = Timer.scheduledTimer(withTimeInterval: target.timeIntervalSince(now), repeats: false) { [weak self] _ in
            self?.fireScheduledOff()
        }
    }

    private func fireScheduledOff() {
        scheduledOffTimer = nil
        guard state.isOn else { return }
        applyOff()
        ShiftEndNotificationController().show(message: AppSettings.shared.notificationMessage)
    }

    private func updateIcon(isOn: Bool) {
        let style = AppSettings.shared.iconStyle
        statusItem.button?.image = NSImage(
            systemSymbolName: isOn ? style.onSymbol : style.offSymbol,
            accessibilityDescription: "포커스 토글"
        )
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "설정...", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
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

    @objc private func openSettings() {
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController.window?.makeKeyAndOrderFront(nil)
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
