enum FocusAction {
    case turnOn
    case turnOff

    var commands: [[String]] {
        switch self {
        case .turnOn:
            return [
                ["/usr/bin/defaults", "write", "com.apple.controlcenter", "NSStatusItem VisibleCC Clock", "-int", "0"],
                ["/usr/bin/killall", "ControlCenter"],
                ["/usr/bin/shortcuts", "run", "FocusOn"]
            ]
        case .turnOff:
            return [
                ["/usr/bin/defaults", "write", "com.apple.controlcenter", "NSStatusItem VisibleCC Clock", "-int", "1"],
                ["/usr/bin/killall", "ControlCenter"],
                ["/usr/bin/shortcuts", "run", "FocusOff"]
            ]
        }
    }
}
