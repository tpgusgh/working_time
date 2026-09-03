enum FocusAction {
    case turnOn
    case turnOff

    var commands: [[String]] {
        switch self {
        case .turnOn:
            return [
                ["/usr/bin/shortcuts", "run", "FocusOn"]
            ]
        case .turnOff:
            return [
                ["/usr/bin/shortcuts", "run", "FocusOff"]
            ]
        }
    }
}
