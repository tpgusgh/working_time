import Foundation

final class AutoScheduleController {
    var turnOnAction: (() -> Void)?
    var turnOffAction: (() -> Void)?

    private var onTimer: Timer?
    private var offTimer: Timer?

    func reschedule() {
        onTimer?.invalidate()
        offTimer?.invalidate()
        onTimer = nil
        offTimer = nil
        guard AppSettings.shared.autoScheduleEnabled else { return }
        scheduleOnTimer()
        scheduleOffTimer()
    }

    private func scheduleOnTimer() {
        let settings = AppSettings.shared
        onTimer = Self.dailyTimer(hour: settings.autoOnHour, minute: settings.autoOnMinute) { [weak self] in
            self?.turnOnAction?()
            self?.scheduleOnTimer()
        }
    }

    private func scheduleOffTimer() {
        let settings = AppSettings.shared
        offTimer = Self.dailyTimer(hour: settings.autoOffHour, minute: settings.autoOffMinute) { [weak self] in
            self?.turnOffAction?()
            self?.scheduleOffTimer()
        }
    }

    private static func dailyTimer(hour: Int, minute: Int, action: @escaping () -> Void) -> Timer? {
        let calendar = Calendar.current
        let now = Date()
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        guard let target = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else {
            return nil
        }
        return Timer.scheduledTimer(withTimeInterval: target.timeIntervalSince(now), repeats: false) { _ in
            action()
        }
    }
}
