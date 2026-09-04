import Foundation

enum MenuBarIconStyle: String, CaseIterable {
    case moon
    case checkmark
    case bolt
    case star

    var displayName: String {
        switch self {
        case .moon: return "달"
        case .checkmark: return "체크"
        case .bolt: return "번개"
        case .star: return "별"
        }
    }

    var offSymbol: String {
        switch self {
        case .moon: return "moon"
        case .checkmark: return "checkmark.circle"
        case .bolt: return "bolt"
        case .star: return "star"
        }
    }

    var onSymbol: String {
        switch self {
        case .moon: return "moon.fill"
        case .checkmark: return "checkmark.circle.fill"
        case .bolt: return "bolt.fill"
        case .star: return "star.fill"
        }
    }
}

final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private let iconStyleKey = "iconStyle"
    private let dndOnlyModeKey = "dndOnlyMode"
    private let autoScheduleEnabledKey = "autoScheduleEnabled"
    private let autoOnHourKey = "autoOnHour"
    private let autoOnMinuteKey = "autoOnMinute"
    private let autoOffHourKey = "autoOffHour"
    private let autoOffMinuteKey = "autoOffMinute"

    private init() {}

    var iconStyle: MenuBarIconStyle {
        get { MenuBarIconStyle(rawValue: defaults.string(forKey: iconStyleKey) ?? "") ?? .moon }
        set { defaults.set(newValue.rawValue, forKey: iconStyleKey) }
    }

    var dndOnlyMode: Bool {
        get { defaults.bool(forKey: dndOnlyModeKey) }
        set { defaults.set(newValue, forKey: dndOnlyModeKey) }
    }

    var autoScheduleEnabled: Bool {
        get { defaults.bool(forKey: autoScheduleEnabledKey) }
        set { defaults.set(newValue, forKey: autoScheduleEnabledKey) }
    }

    var autoOnHour: Int {
        get { defaults.object(forKey: autoOnHourKey) as? Int ?? 9 }
        set { defaults.set(newValue, forKey: autoOnHourKey) }
    }

    var autoOnMinute: Int {
        get { defaults.object(forKey: autoOnMinuteKey) as? Int ?? 0 }
        set { defaults.set(newValue, forKey: autoOnMinuteKey) }
    }

    var autoOffHour: Int {
        get { defaults.object(forKey: autoOffHourKey) as? Int ?? 18 }
        set { defaults.set(newValue, forKey: autoOffHourKey) }
    }

    var autoOffMinute: Int {
        get { defaults.object(forKey: autoOffMinuteKey) as? Int ?? 0 }
        set { defaults.set(newValue, forKey: autoOffMinuteKey) }
    }
}
