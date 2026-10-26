import AppKit

/// Menu bar extra: the only UI of the app, since it has no Dock icon.
final class MenuBarController: NSObject, NSMenuDelegate {

    private var statusItem: NSStatusItem?
    private var mainMenu: NSMenu?
    private var displayMenu: NSMenu?
    private var characterMenu: NSMenu?

    private enum Tag: Int {
        case come = 1, dance, jump, swing, hang, pause, reset, zipUp, zipSide, restUpsideDown, villain, katana, pistol, batarang, combo, grapple, glide, batmobile, smash, clap, batSignal, settings
        case sizeSmall = 100, sizeMedium, sizeLarge
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = ""
            button.image = NSImage(systemSymbolName: "bolt.shield.fill", accessibilityDescription: "Super Buddy")
            button.image?.isTemplate = true
            button.toolTip = "Super Buddy"
            button.font = NSFont.systemFont(ofSize: 15)
        }

        let menu = NSMenu()

        menu.addItem(header("Super Buddy"))
        menu.addItem(.separator())

        menu.addItem(make("Come to my cursor", .come, "c"))
        menu.addItem(make("Dance!", .dance, "d"))
        menu.addItem(make("Jump", .jump, "j"))
        menu.addItem(make("Katana slash", .katana, "k"))
        menu.addItem(make("Fire pistol", .pistol, "f"))
        menu.addItem(make("Smash-Buddy smash!", .smash, "k"))
        menu.addItem(make("Thunderclap", .clap, "t"))
        menu.addItem(make("Bat-Beacon", .batSignal, "e"))
        menu.addItem(make("Throw Wingblade", .batarang, "b"))
        menu.addItem(make("Combat combo", .combo, "k"))
        menu.addItem(make("Grapple", .grapple, "g"))
        menu.addItem(make("Glide", .glide, "l"))
        menu.addItem(make("Buddy-Mobile", .batmobile, "m"))
        menu.addItem(make("Shoot a web & swing", .swing, "s"))
        menu.addItem(make("Go hang from the ceiling", .hang, "h"))
        menu.addItem(make("Web-zip to the ceiling", .zipUp, "u"))
        menu.addItem(make("Web-zip to a side wall", .zipSide, "w"))
        menu.addItem(make("Rest upside-down on the ceiling", .restUpsideDown, ""))
        menu.addItem(.separator())
        menu.addItem(make("Summon a villain!", .villain, "v"))
        menu.addItem(.separator())

        let characterItem = NSMenuItem(title: "Choose Buddy", action: nil, keyEquivalent: "")
        let characters = NSMenu()
        for character in BuddyCharacter.allCases {
            let choice = NSMenuItem(title: character.title, action: #selector(chooseCharacter(_:)), keyEquivalent: "")
            choice.target = self
            choice.representedObject = character.rawValue
            characters.addItem(choice)
        }
        characterItem.submenu = characters
        characterMenu = characters
        menu.addItem(characterItem)

        let sizeItem = NSMenuItem(title: "Buddy size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        sizeMenu.addItem(make("Small", .sizeSmall, ""))
        sizeMenu.addItem(make("Medium", .sizeMedium, ""))
        sizeMenu.addItem(make("Large", .sizeLarge, ""))
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let screenItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        let screens = NSMenu()
        screenItem.submenu = screens
        displayMenu = screens
        menu.addItem(screenItem)

        menu.addItem(make("Settings…", .settings, ","))
        menu.addItem(make("Send back home", .reset, "r"))
        menu.addItem(make("Pause / Resume", .pause, "p"))
        menu.addItem(.separator())
        menu.addItem(make("Quit Super Buddy", nil, "q", selector: #selector(quit)))

        menu.delegate = self
        mainMenu = menu
        item.menu = menu
        statusItem = item
    }

    // MARK: Display list

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === mainMenu else { return }
        let isHulk = BuddyCenter.shared.scene?.buddy.character == .hulk
        let isBatman = BuddyCenter.shared.scene?.buddy.character == .batman
        let isDeadpool = BuddyCenter.shared.scene?.buddy.character == .deadpool
        for item in mainMenu?.items ?? [] {
            if [Tag.swing, .hang, .zipUp, .zipSide, .restUpsideDown].map({ $0.rawValue }).contains(item.tag) {
                item.isHidden = isDeadpool || isBatman || isHulk
            }
            if [Tag.batarang, .combo, .grapple, .glide, .batmobile, .batSignal].map({ $0.rawValue }).contains(item.tag) {
                item.isHidden = !isBatman
            }
            if [Tag.smash, .clap].map({ $0.rawValue }).contains(item.tag) { item.isHidden = !isHulk }
            if item.tag == Tag.jump.rawValue { item.title = isHulk ? "Super leap" : "Jump" }
            if item.tag == Tag.dance.rawValue { item.title = isHulk ? "Roar & flex" : (isBatman ? "Scan & flip Wingblade" : "Dance!") }
            if [Tag.katana, .pistol].map({ $0.rawValue }).contains(item.tag) {
                item.isHidden = !isDeadpool
            }
        }
        rebuildDisplayMenu()
        for item in characterMenu?.items ?? [] {
            item.state = (item.representedObject as? String) == BuddyCenter.shared.scene?.buddy.character.rawValue ? .on : .off
        }
    }

    private func rebuildDisplayMenu() {
        guard let sub = displayMenu else { return }
        sub.removeAllItems()
        let current = AppDelegate.targetScreen().localizedName
        for name in AppDelegate.displayNames() {
            let item = NSMenuItem(title: name, action: #selector(chooseDisplay(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            item.state = name == current ? .on : .off
            sub.addItem(item)
        }
    }

    @objc private func chooseCharacter(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let character = BuddyCharacter(rawValue: id) else { return }
        BuddyCenter.shared.scene?.selectCharacter(character)
    }

    @objc private func chooseDisplay(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        BuddyCenter.shared.moveToDisplay(named: name)
    }

    private func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func make(_ title: String, _ tag: Tag?, _ key: String,
                      selector: Selector = #selector(handle(_:))) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        if let tag = tag { item.tag = tag.rawValue }
        return item
    }

    @objc private func handle(_ sender: NSMenuItem) {
        guard let tag = Tag(rawValue: sender.tag) else { return }
        switch tag {
        case .settings: showTimingSettings()
        case .come: BuddyCenter.shared.come()
        case .dance: BuddyCenter.shared.dance()
        case .jump: BuddyCenter.shared.jump()
        case .swing: BuddyCenter.shared.swing()
        case .hang: BuddyCenter.shared.hang()
        case .zipUp: BuddyCenter.shared.zipUp()
        case .zipSide: BuddyCenter.shared.zipSide()
        case .restUpsideDown: BuddyCenter.shared.restUpsideDown()
        case .villain: BuddyCenter.shared.summonVillain()
        case .katana: BuddyCenter.shared.scene?.commandKatana()
        case .pistol: BuddyCenter.shared.scene?.commandPistol()
        case .smash: BuddyCenter.shared.scene?.commandSmash()
        case .clap: BuddyCenter.shared.scene?.commandClap()
        case .batSignal: BuddyCenter.shared.scene?.commandBatSignal()
        case .batarang: BuddyCenter.shared.scene?.commandBatarang()
        case .combo: BuddyCenter.shared.scene?.commandCombo()
        case .grapple: BuddyCenter.shared.scene?.commandGrapple()
        case .glide: BuddyCenter.shared.scene?.commandGlide()
        case .batmobile: BuddyCenter.shared.scene?.commandBatmobile()
        case .pause: BuddyCenter.shared.togglePause()
        case .reset: BuddyCenter.shared.reset()
        case .sizeSmall: BuddyCenter.shared.setScale(0.62)
        case .sizeMedium: BuddyCenter.shared.setScale(0.9)
        case .sizeLarge: BuddyCenter.shared.setScale(1.35)
        }
    }

    private func showTimingSettings() {
        guard let scene = BuddyCenter.shared.scene else { return }
        let alert = NSAlert()
        alert.messageText = "Timing settings"
        alert.informativeText = "Set the wait between automatic events. Walking continues normally. Use 0 to turn off that type of event. Menu actions still work immediately."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let form = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 105))
        let actionField = NSTextField(string: String(Int(scene.timing.actionInterval)))
        let villainField = NSTextField(string: String(Int(scene.timing.villainInterval)))
        for (label, field, y) in [("Random actions (seconds)", actionField, CGFloat(70)),
                                  ("Villains (seconds)", villainField, CGFloat(32))] {
            let title = NSTextField(labelWithString: label)
            title.frame = NSRect(x: 0, y: y + 3, width: 230, height: 20)
            field.frame = NSRect(x: 245, y: y, width: 90, height: 26)
            form.addSubview(title); form.addSubview(field)
        }
        alert.accessoryView = form
        NSApp.activate(ignoringOtherApps: true)
        while alert.runModal() == .alertFirstButtonReturn {
            guard let actions = Int(actionField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let villains = Int(villainField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
                  (0...3600).contains(actions), (0...7200).contains(villains) else {
                alert.informativeText = "Enter whole seconds: actions 0–3600 and villains 0–7200. Use 0 to disable automatic events."
                continue
            }
            scene.setTiming(TimingSettings(actionInterval: Double(actions), villainInterval: Double(villains)))
            break
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// Small indirection so the menu bar can talk to the live scene.
final class BuddyCenter {
    static let shared = BuddyCenter()
    weak var scene: BuddyScene?
    weak var appDelegate: AppDelegate?

    func come() { scene?.commandComeToCursor() }
    func dance() { scene?.commandDance() }
    func jump() { scene?.commandJump() }
    func swing() { scene?.commandSwing() }
    func hang() { scene?.commandHang() }
    func zipUp() { scene?.commandZipUp() }
    func zipSide() { scene?.commandZipSide() }
    func restUpsideDown() { scene?.commandHangUpsideDown() }
    func summonVillain() { scene?.commandSummonVillain() }
    func reset() { scene?.commandReset() }
    func setScale(_ s: CGFloat) { scene?.setBuddyScale(s) }
    func moveToDisplay(named name: String) { appDelegate?.moveToDisplay(named: name) }
    func togglePause() {
        guard let scene = scene else { return }
        scene.frozen.toggle()
    }
}
