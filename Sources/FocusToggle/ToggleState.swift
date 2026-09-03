final class ToggleState {
    private(set) var isOn = false

    @discardableResult
    func toggle() -> Bool {
        isOn.toggle()
        return isOn
    }
}
