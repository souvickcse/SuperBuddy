import Foundation

struct TimingSettings: Equatable {
    static let defaults = TimingSettings(actionInterval: 30, villainInterval: 300)
    let actionInterval: TimeInterval
    let villainInterval: TimeInterval

    init(actionInterval: TimeInterval, villainInterval: TimeInterval) {
        self.actionInterval = actionInterval.isFinite ? min(3600, max(0, actionInterval)) : 30
        self.villainInterval = villainInterval.isFinite ? min(7200, max(0, villainInterval)) : 300
    }

    static func load(from defaults: UserDefaults = .standard) -> TimingSettings {
        TimingSettings(actionInterval: (defaults.object(forKey: "randomActionInterval") as? NSNumber)?.doubleValue ?? 30,
                       villainInterval: (defaults.object(forKey: "villainInterval") as? NSNumber)?.doubleValue ?? 300)
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(actionInterval, forKey: "randomActionInterval")
        defaults.set(villainInterval, forKey: "villainInterval")
    }
}
