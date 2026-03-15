// Sources/ClearText/Persistence/PersistenceManager.swift
import Foundation

final class PersistenceManager {
    nonisolated(unsafe) static let shared = PersistenceManager()

    private let defaults: UserDefaults
    private var debounceTimers: [Int: Timer] = [:]
    private var pendingContent: [Int: String] = [:]

    private enum Keys {
        static func tabContent(_ tab: Int) -> String { "cleartext.tab\(tab).content" }
        static let alphaStep = "cleartext.appearance.alphaStep"
        static let fontSize = "cleartext.appearance.fontSize"
        static let alwaysOnTopOnLaunch = "cleartext.appearance.alwaysOnTopOnLaunch"
        static let hoverToOpaque = "cleartext.appearance.hoverToOpaque"
        static let launchAtLogin = "cleartext.appearance.launchAtLogin"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveTabContent(_ content: String, tab: Int) {
        defaults.set(content, forKey: Keys.tabContent(tab))
    }

    func saveTabContentDebounced(_ content: String, tab: Int, delay: TimeInterval = 0.5) {
        debounceTimers[tab]?.invalidate()
        pendingContent[tab] = content
        debounceTimers[tab] = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.pendingContent.removeValue(forKey: tab)
            self?.saveTabContent(content, tab: tab)
        }
    }

    func loadTabContent(tab: Int) -> String {
        defaults.string(forKey: Keys.tabContent(tab)) ?? ""
    }

    func saveAlphaStep(_ step: Int) {
        defaults.set(step, forKey: Keys.alphaStep)
    }

    func loadAlphaStep() -> Int {
        let stored = defaults.object(forKey: Keys.alphaStep)
        return stored != nil ? defaults.integer(forKey: Keys.alphaStep) : 2
    }

    func saveFontSize(_ size: Int) {
        defaults.set(size, forKey: Keys.fontSize)
    }

    func loadFontSize() -> Int {
        let stored = defaults.object(forKey: Keys.fontSize)
        return stored != nil ? defaults.integer(forKey: Keys.fontSize) : 13
    }

    func saveAlwaysOnTopOnLaunch(_ value: Bool) {
        defaults.set(value, forKey: Keys.alwaysOnTopOnLaunch)
    }

    func loadAlwaysOnTopOnLaunch() -> Bool {
        defaults.bool(forKey: Keys.alwaysOnTopOnLaunch)
    }

    func saveHoverToOpaque(_ value: Bool) {
        defaults.set(value, forKey: Keys.hoverToOpaque)
    }

    func loadHoverToOpaque() -> Bool {
        defaults.bool(forKey: Keys.hoverToOpaque)
    }

    func saveLaunchAtLogin(_ value: Bool) {
        defaults.set(value, forKey: Keys.launchAtLogin)
    }

    func loadLaunchAtLogin() -> Bool {
        defaults.bool(forKey: Keys.launchAtLogin)
    }

    func flushImmediately() {
        for (tab, content) in pendingContent {
            saveTabContent(content, tab: tab)
        }
        pendingContent.removeAll()
        debounceTimers.values.forEach { $0.invalidate() }
        debounceTimers.removeAll()
        defaults.synchronize()
    }
}
