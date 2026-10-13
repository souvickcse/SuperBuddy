import AppKit
import SpriteKit

/// Extra bits a character can wear on their head.
enum Headgear {
    case none
    case hat        // Green Goblin's purple bonnet
    case horns      // Rhino
    case bowl       // Mysterio's dome
    case crest      // Electro
    case beak       // Vulture
    case mane       // Kraven
    case helmet
    case skull
}

/// What is strapped to their back.
enum BackGear {
    case none
    case tentacles  // Doctor Octopus
    case wings      // Vulture
    case swords     // Deadpool’s crossed katana scabbards
}

/// How a villain actually fights.
enum VillainArchetype {
    case brawler    // walks in and trades punches
    case charger    // backs off, winds up, then barrels at you
    case flyer      // hovers overhead and dives
    case shooter    // keeps its distance and fires
}

/// Everything that makes one character look different from another. The buddy uses the
/// default skin, so his appearance is unchanged; villains are just other skins.
struct Skin {
    var name = "Spider Buddy"

    var suit = Palette.red
    var suitDark = Palette.redDark
    var limb = Palette.blue
    var limbDark = Palette.blueDark
    var eye = Palette.eye
    var eyeFar = Palette.eyeFar
    var pattern = Palette.webLine
    var ink = Palette.ink

    var webbing = true          // the web pattern on the chest
    var emblem = true           // the little spider badge
    var headgear: Headgear = .none
    var eyeScale: CGFloat = 1
    var backGear: BackGear = .none
    var bodyScale: CGFloat = 1
    var fightSpeed: CGFloat = 1
    var archetype: VillainArchetype = .brawler

    var deadpoolDetails = false

    static let buddy = Skin()
    static let deadpool = Skin(name: "Deadpool",
        suit: SKColor(srgbRed: 0.72, green: 0.08, blue: 0.12, alpha: 1),
        suitDark: SKColor(srgbRed: 0.45, green: 0.04, blue: 0.07, alpha: 1),
        limb: SKColor(srgbRed: 0.65, green: 0.07, blue: 0.10, alpha: 1),
        limbDark: SKColor(srgbRed: 0.36, green: 0.03, blue: 0.05, alpha: 1),
        webbing: false, emblem: false, eyeScale: 0.78,
        backGear: .swords, deadpoolDetails: true)

    // MARK: The rogues gallery

    static let villains: [Skin] = [
        Skin(name: "Green Goblin",
             suit: SKColor(srgbRed: 0.26, green: 0.62, blue: 0.28, alpha: 1),
             suitDark: SKColor(srgbRed: 0.16, green: 0.42, blue: 0.19, alpha: 1),
             limb: SKColor(srgbRed: 0.40, green: 0.20, blue: 0.58, alpha: 1),
             limbDark: SKColor(srgbRed: 0.27, green: 0.13, blue: 0.40, alpha: 1),
             eye: SKColor(srgbRed: 1.0, green: 0.94, blue: 0.55, alpha: 1),
             eyeFar: SKColor(srgbRed: 0.82, green: 0.74, blue: 0.40, alpha: 1),
             webbing: false, emblem: false, headgear: .hat, archetype: .flyer),

        Skin(name: "Venom",
             suit: SKColor(srgbRed: 0.09, green: 0.09, blue: 0.12, alpha: 1),
             suitDark: SKColor(srgbRed: 0.05, green: 0.05, blue: 0.07, alpha: 1),
             limb: SKColor(srgbRed: 0.13, green: 0.13, blue: 0.18, alpha: 1),
             limbDark: SKColor(srgbRed: 0.07, green: 0.07, blue: 0.10, alpha: 1),
             eye: SKColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1),
             eyeFar: SKColor(srgbRed: 0.85, green: 0.88, blue: 0.95, alpha: 1),
             webbing: false, emblem: false, eyeScale: 1.45, archetype: .charger),

        Skin(name: "Doctor Octopus",
             suit: SKColor(srgbRed: 0.34, green: 0.52, blue: 0.30, alpha: 1),
             suitDark: SKColor(srgbRed: 0.22, green: 0.36, blue: 0.20, alpha: 1),
             limb: SKColor(srgbRed: 0.72, green: 0.55, blue: 0.16, alpha: 1),
             limbDark: SKColor(srgbRed: 0.52, green: 0.39, blue: 0.10, alpha: 1),
             eye: SKColor(srgbRed: 0.95, green: 0.97, blue: 1.0, alpha: 1),
             eyeFar: SKColor(srgbRed: 0.72, green: 0.78, blue: 0.86, alpha: 1),
             webbing: false, emblem: false, backGear: .tentacles, fightSpeed: 0.9, archetype: .shooter),

        Skin(name: "Rhino",
             suit: SKColor(srgbRed: 0.56, green: 0.53, blue: 0.50, alpha: 1),
             suitDark: SKColor(srgbRed: 0.40, green: 0.38, blue: 0.36, alpha: 1),
             limb: SKColor(srgbRed: 0.45, green: 0.42, blue: 0.40, alpha: 1),
             limbDark: SKColor(srgbRed: 0.31, green: 0.29, blue: 0.28, alpha: 1),
             eye: SKColor(srgbRed: 0.98, green: 0.90, blue: 0.78, alpha: 1),
             eyeFar: SKColor(srgbRed: 0.78, green: 0.70, blue: 0.60, alpha: 1),
             webbing: false, emblem: false, headgear: .horns,
             bodyScale: 1.16, fightSpeed: 1.15, archetype: .charger),

        Skin(name: "Sandman",
             suit: SKColor(srgbRed: 0.74, green: 0.62, blue: 0.36, alpha: 1),
             suitDark: SKColor(srgbRed: 0.56, green: 0.46, blue: 0.26, alpha: 1),
             limb: SKColor(srgbRed: 0.64, green: 0.53, blue: 0.30, alpha: 1),
             limbDark: SKColor(srgbRed: 0.47, green: 0.39, blue: 0.21, alpha: 1),
             eye: SKColor(srgbRed: 0.30, green: 0.22, blue: 0.10, alpha: 1),
             eyeFar: SKColor(srgbRed: 0.24, green: 0.18, blue: 0.08, alpha: 1),
             webbing: false, emblem: false, eyeScale: 0.85),

        Skin(name: "Mysterio",
             suit: SKColor(srgbRed: 0.20, green: 0.55, blue: 0.34, alpha: 1),
             suitDark: SKColor(srgbRed: 0.13, green: 0.37, blue: 0.22, alpha: 1),
             limb: SKColor(srgbRed: 0.85, green: 0.78, blue: 0.25, alpha: 1),
             limbDark: SKColor(srgbRed: 0.62, green: 0.56, blue: 0.16, alpha: 1),
             eye: SKColor(srgbRed: 0.90, green: 0.95, blue: 1.0, alpha: 1),
             eyeFar: SKColor(srgbRed: 0.70, green: 0.76, blue: 0.86, alpha: 1),
             webbing: false, emblem: false, headgear: .bowl),

        Skin(name: "Electro",
             suit: SKColor(srgbRed: 0.18, green: 0.62, blue: 0.46, alpha: 1),
             suitDark: SKColor(srgbRed: 0.11, green: 0.42, blue: 0.31, alpha: 1),
             limb: SKColor(srgbRed: 0.93, green: 0.86, blue: 0.20, alpha: 1),
             limbDark: SKColor(srgbRed: 0.68, green: 0.62, blue: 0.13, alpha: 1),
             eye: SKColor(srgbRed: 1.0, green: 1.0, blue: 0.85, alpha: 1),
             eyeFar: SKColor(srgbRed: 0.82, green: 0.84, blue: 0.62, alpha: 1),
             webbing: false, emblem: false, headgear: .crest, fightSpeed: 1.05, archetype: .shooter),

        Skin(name: "Vulture",
             suit: SKColor(srgbRed: 0.36, green: 0.48, blue: 0.30, alpha: 1),
             suitDark: SKColor(srgbRed: 0.24, green: 0.34, blue: 0.20, alpha: 1),
             limb: SKColor(srgbRed: 0.30, green: 0.30, blue: 0.28, alpha: 1),
             limbDark: SKColor(srgbRed: 0.20, green: 0.20, blue: 0.19, alpha: 1),
             eye: SKColor(srgbRed: 0.98, green: 0.86, blue: 0.55, alpha: 1),
             eyeFar: SKColor(srgbRed: 0.76, green: 0.66, blue: 0.40, alpha: 1),
             webbing: false, emblem: false, headgear: .beak,
             backGear: .wings, fightSpeed: 1.1, archetype: .flyer),

        Skin(name: "Kraven",
             suit: SKColor(srgbRed: 0.72, green: 0.52, blue: 0.26, alpha: 1),
             suitDark: SKColor(srgbRed: 0.52, green: 0.37, blue: 0.18, alpha: 1),
             limb: SKColor(srgbRed: 0.42, green: 0.30, blue: 0.16, alpha: 1),
             limbDark: SKColor(srgbRed: 0.30, green: 0.21, blue: 0.11, alpha: 1),
             eye: SKColor(srgbRed: 0.96, green: 0.94, blue: 0.82, alpha: 1),
             eyeFar: SKColor(srgbRed: 0.74, green: 0.72, blue: 0.62, alpha: 1),
             webbing: false, emblem: false, headgear: .mane,
             bodyScale: 1.05, fightSpeed: 1.2, archetype: .brawler),

        Skin(name: "Kingpin",
             suit: SKColor(srgbRed: 0.92, green: 0.92, blue: 0.94, alpha: 1),
             suitDark: SKColor(srgbRed: 0.70, green: 0.70, blue: 0.74, alpha: 1),
             limb: SKColor(srgbRed: 0.22, green: 0.16, blue: 0.32, alpha: 1),
             limbDark: SKColor(srgbRed: 0.15, green: 0.11, blue: 0.22, alpha: 1),
             eye: SKColor(srgbRed: 0.95, green: 0.95, blue: 1.0, alpha: 1),
             eyeFar: SKColor(srgbRed: 0.72, green: 0.72, blue: 0.78, alpha: 1),
             webbing: false, emblem: false,
             bodyScale: 1.32, fightSpeed: 0.85, archetype: .charger)
    ]

    static let deadpoolVillains: [Skin] = [
        Skin(name: "Ajax", suit: SKColor(white: 0.65, alpha: 1),
             suitDark: SKColor(white: 0.4, alpha: 1),
             limb: SKColor(white: 0.22, alpha: 1), limbDark: SKColor(white: 0.12, alpha: 1),
             webbing: false, emblem: false, backGear: .swords, fightSpeed: 1.15),
        Skin(name: "Juggernaut", suit: SKColor(srgbRed: 0.48, green: 0.25, blue: 0.14, alpha: 1),
             suitDark: SKColor(srgbRed: 0.3, green: 0.13, blue: 0.07, alpha: 1),
             limb: SKColor(srgbRed: 0.67, green: 0.45, blue: 0.29, alpha: 1),
             limbDark: SKColor(srgbRed: 0.43, green: 0.27, blue: 0.16, alpha: 1),
             webbing: false, emblem: false, headgear: .helmet,
             bodyScale: 1.35, fightSpeed: 0.9, archetype: .charger),
        Skin(name: "Taskmaster", suit: SKColor(white: 0.88, alpha: 1),
             suitDark: SKColor(white: 0.6, alpha: 1),
             limb: SKColor(srgbRed: 0.13, green: 0.22, blue: 0.39, alpha: 1),
             limbDark: SKColor(srgbRed: 0.08, green: 0.13, blue: 0.25, alpha: 1),
             eye: SKColor(white: 0.12, alpha: 1), eyeFar: SKColor(white: 0.16, alpha: 1),
             webbing: false, emblem: false, headgear: .skull, backGear: .swords,
             fightSpeed: 1.1, archetype: .shooter),
        { () -> Skin in
            var skin = Skin.deadpool
            skin.name = "Evil Deadpool"
            skin.suitDark = SKColor(srgbRed: 0.23, green: 0.04, blue: 0.05, alpha: 1)
            skin.eyeFar = SKColor(srgbRed: 1, green: 0.67, blue: 0.2, alpha: 1)
            skin.fightSpeed = 1.2
            skin.archetype = .charger
            return skin
        }()
    ]

    static func villains(for character: BuddyCharacter) -> [Skin] {
        character == .deadpool ? deadpoolVillains : villains
    }

    static func randomVillain(for character: BuddyCharacter = .spider) -> Skin {
        let roster = villains(for: character)
        return roster.randomElement() ?? roster[0]
    }
}

/// Stable preference IDs are independent of the names shown in the menu.
enum BuddyCharacter: String, CaseIterable {
    case spider, deadpool
    var title: String { self == .spider ? "Spider Buddy" : "Deadpool" }
    var skin: Skin { self == .spider ? .buddy : .deadpool }
}
