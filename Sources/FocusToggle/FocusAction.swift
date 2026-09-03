enum FocusAction {
    case turnOn
    case turnOff

    var commands: [[String]] {
        switch self {
        case .turnOn:
            return [
                ["/usr/bin/defaults", "write", "com.apple.controlcenter", "Clock", "-bool", "false"],
                ["/usr/bin/killall", "SystemUIServer"],
                ["/usr/bin/shortcuts", "run", "FocusOn"]
            ]
        case .turnOff:
            return [
                ["/usr/bin/defaults", "write", "com.apple.controlcenter", "Clock", "-bool", "true"],
                ["/usr/bin/killall", "SystemUIServer"],
                ["/usr/bin/shortcuts", "run", "FocusOff"]
            ]
        }
    }
}
