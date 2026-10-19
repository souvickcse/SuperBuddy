import AppKit
import SpriteKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var window: BuddyWindow?
    private var scene: BuddyScene?
    private var menuBar: MenuBarController?
    private var passThroughTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        migratePreferences()
        let screen = Self.targetScreen()
        buildWindow(frame: screen.frame)
        startPassThroughWatcher()
        BuddyCenter.shared.scene = scene
        BuddyCenter.shared.appDelegate = self

        menuBar = MenuBarController()
        menuBar?.install()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    /// Import existing settings once after the app's bundle-identifier rename.
    private func migratePreferences() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "didMigratePreviousBuddyPreferences") else { return }
        let previous = defaults.persistentDomain(forName: "com.souvickghosh.spiderbuddy") ?? [:]
        for key in ["buddyCharacter", "buddyScale", "buddyDisplay"] {
            if defaults.object(forKey: key) == nil, let value = previous[key] {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: "didMigratePreviousBuddyPreferences")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Displays

    /// The buddy lives on one real display, never on a bounding box of several.
    /// Displays are rarely aligned, so their union contains dead zones that belong to
    /// no screen at all — walk into one of those and he simply vanishes.
    static func targetScreen() -> NSScreen {
        let stored = UserDefaults.standard.string(forKey: "buddyDisplay")
        if let name = stored, let match = NSScreen.screens.first(where: { $0.localizedName == name }) {
            return match
        }
        // first screen in the array is the one with the menu bar
        return NSScreen.screens.first ?? NSScreen.main ?? NSScreen.screens[0]
    }

    static func displayNames() -> [String] {
        NSScreen.screens.map { $0.localizedName }
    }

    func moveToDisplay(named name: String) {
        guard let screen = NSScreen.screens.first(where: { $0.localizedName == name }) else { return }
        UserDefaults.standard.set(name, forKey: "buddyDisplay")
        apply(screen: screen)
    }

    private func apply(screen: NSScreen) {
        guard let window = window, let scene = scene else { return }
        window.setFrame(screen.frame, display: true)
        scene.resizeWorld(to: screen.frame.size)
        BuddyDebug.log("moved to display \(screen.localizedName) \(screen.frame)")
    }

    /// The overlay is a full-screen window, so it has to hand every click that is *not*
    /// aimed at the buddy straight back to whatever is underneath. AppKit only lets you
    /// do that per window (`ignoresMouseEvents`), so we flip it as the pointer moves.
    /// A poll of `NSEvent.mouseLocation` needs no extra permissions and keeps working
    /// while the pointer is over another app.
    private func startPassThroughWatcher() {
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.scene?.syncMousePassthrough()
        }
        // .common keeps it ticking during drags and menu tracking
        RunLoop.main.add(timer, forMode: .common)
        passThroughTimer = timer
    }

    // MARK: Window

    private func buildWindow(frame: CGRect) {
        let view = BuddyView(frame: CGRect(origin: .zero, size: frame.size))
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        view.shouldCullNonVisibleNodes = false

        let scene = BuddyScene(size: frame.size)
        scene.scaleMode = .resizeFill
        scene.anchorPoint = .zero
        scene.backgroundColor = .clear
        view.presentScene(scene)
        view.hitTester = { [weak scene] point in
            scene?.hitTestBuddy(point) ?? false
        }

        let window = BuddyWindow(contentRect: frame,
                                 styleMask: .borderless,
                                 backing: .buffered,
                                 defer: false)
        window.contentView = view
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        // above the Dock and the menu bar, otherwise he disappears exactly where he
        // likes to walk: along the bottom and top edges of the screen
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.isMovable = false
        window.isReleasedWhenClosed = false
        window.acceptsMouseMovedEvents = true
        window.animationBehavior = .none
        // start fully click-through; the watcher opens it up only over the buddy
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()

        self.window = window
        self.scene = scene

        scene.loadPreferences()
        BuddyDebug.log("launched window=\(Int(frame.width))x\(Int(frame.height)) scale=\(scene.userScale)")
    }

    @objc private func screensChanged() {
        // the remembered display may have been unplugged
        apply(screen: Self.targetScreen())
    }
}

extension BuddyScene {
    /// Re-fit the world after the window moved to another display.
    func resizeWorld(to size: CGSize) {
        self.size = size
        view?.frame = CGRect(origin: .zero, size: size)
        world.bounds = CGRect(origin: .zero, size: size)
        world.reach = buddy.reach
        buddy.keepInside(world)
    }
}
