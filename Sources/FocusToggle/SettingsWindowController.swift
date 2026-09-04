import AppKit

final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private let iconPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let dndOnlyCheckbox = NSButton(checkboxWithTitle: "방해금지 모드만 사용 (시계는 안 가림)", target: nil, action: nil)
    private let autoScheduleCheckbox = NSButton(checkboxWithTitle: "자동 스케줄 사용 (매일 반복)", target: nil, action: nil)
    private let autoOnPicker = NSDatePicker(frame: .zero)
    private let autoOffPicker = NSDatePicker(frame: .zero)
    private let notificationMessageField = NSTextField(frame: .zero)
    var onIconStyleChanged: (() -> Void)?
    var onScheduleChanged: (() -> Void)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 280),
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
        iconLabel.frame = NSRect(x: 20, y: 240, width: 100, height: 20)
        contentView.addSubview(iconLabel)

        iconPopUp.frame = NSRect(x: 120, y: 237, width: 180, height: 26)
        for style in MenuBarIconStyle.allCases {
            iconPopUp.addItem(withTitle: style.displayName)
        }
        iconPopUp.target = self
        iconPopUp.action = #selector(iconStyleChanged)
        contentView.addSubview(iconPopUp)

        dndOnlyCheckbox.frame = NSRect(x: 20, y: 205, width: 280, height: 24)
        dndOnlyCheckbox.target = self
        dndOnlyCheckbox.action = #selector(dndOnlyChanged)
        contentView.addSubview(dndOnlyCheckbox)

        autoScheduleCheckbox.frame = NSRect(x: 20, y: 170, width: 280, height: 24)
        autoScheduleCheckbox.target = self
        autoScheduleCheckbox.action = #selector(scheduleChanged)
        contentView.addSubview(autoScheduleCheckbox)

        let onLabel = NSTextField(labelWithString: "켜지는 시각")
        onLabel.frame = NSRect(x: 40, y: 138, width: 90, height: 20)
        contentView.addSubview(onLabel)

        autoOnPicker.frame = NSRect(x: 140, y: 135, width: 90, height: 24)
        autoOnPicker.datePickerElements = .hourMinute
        autoOnPicker.datePickerMode = .single
        autoOnPicker.target = self
        autoOnPicker.action = #selector(scheduleChanged)
        contentView.addSubview(autoOnPicker)

        let offLabel = NSTextField(labelWithString: "꺼지는 시각")
        offLabel.frame = NSRect(x: 40, y: 106, width: 90, height: 20)
        contentView.addSubview(offLabel)

        autoOffPicker.frame = NSRect(x: 140, y: 103, width: 90, height: 24)
        autoOffPicker.datePickerElements = .hourMinute
        autoOffPicker.datePickerMode = .single
        autoOffPicker.target = self
        autoOffPicker.action = #selector(scheduleChanged)
        contentView.addSubview(autoOffPicker)

        let notificationLabel = NSTextField(labelWithString: "종료 알림 문구")
        notificationLabel.frame = NSRect(x: 20, y: 74, width: 280, height: 18)
        contentView.addSubview(notificationLabel)

        notificationMessageField.frame = NSRect(x: 20, y: 48, width: 280, height: 22)
        notificationMessageField.target = self
        notificationMessageField.action = #selector(notificationMessageChanged)
        notificationMessageField.delegate = self
        contentView.addSubview(notificationMessageField)

        let closeButton = NSButton(title: "닫기", target: self, action: #selector(closeSettings))
        closeButton.frame = NSRect(x: 220, y: 12, width: 80, height: 28)
        closeButton.bezelStyle = .rounded
        contentView.addSubview(closeButton)
    }

    private func loadCurrentSettings() {
        let settings = AppSettings.shared
        let index = MenuBarIconStyle.allCases.firstIndex(of: settings.iconStyle) ?? 0
        iconPopUp.selectItem(at: index)
        dndOnlyCheckbox.state = settings.dndOnlyMode ? .on : .off
        autoScheduleCheckbox.state = settings.autoScheduleEnabled ? .on : .off

        var onComponents = DateComponents()
        onComponents.hour = settings.autoOnHour
        onComponents.minute = settings.autoOnMinute
        autoOnPicker.dateValue = Calendar.current.date(from: onComponents) ?? Date()

        var offComponents = DateComponents()
        offComponents.hour = settings.autoOffHour
        offComponents.minute = settings.autoOffMinute
        autoOffPicker.dateValue = Calendar.current.date(from: offComponents) ?? Date()

        notificationMessageField.stringValue = settings.notificationMessage
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

    @objc private func scheduleChanged() {
        let settings = AppSettings.shared
        settings.autoScheduleEnabled = (autoScheduleCheckbox.state == .on)

        let calendar = Calendar.current
        let onComponents = calendar.dateComponents([.hour, .minute], from: autoOnPicker.dateValue)
        settings.autoOnHour = onComponents.hour ?? 9
        settings.autoOnMinute = onComponents.minute ?? 0

        let offComponents = calendar.dateComponents([.hour, .minute], from: autoOffPicker.dateValue)
        settings.autoOffHour = offComponents.hour ?? 18
        settings.autoOffMinute = offComponents.minute ?? 0

        onScheduleChanged?()
    }

    @objc private func notificationMessageChanged() {
        let text = notificationMessageField.stringValue
        AppSettings.shared.notificationMessage = text.isEmpty ? AppSettings.defaultNotificationMessage : text
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        notificationMessageChanged()
    }

    @objc private func closeSettings() {
        window?.close()
    }
}
