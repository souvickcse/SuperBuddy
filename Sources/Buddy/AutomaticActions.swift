import SpriteKit

/// A single owner selects Bat-Buddy's automatic action when the shared delay
/// expires. A shuffled bag prevents frame-loop order from starving other actions.
final class AutomaticActions {
    enum BatAction: CaseIterable { case leap, grapple, flourish, beacon, vehicle }
    private var remaining: [BatAction] = []
    private(set) var lastAction: BatAction?

    func update(world: World, scene: SKScene, buddy: Buddy, beacon: BatSignal, vehicle: Batmobile) {
        guard buddy.character == .batman, buddy.canPerformAutomaticAction,
              buddy.grounded, buddy.surface == .floor, !beacon.active, !vehicle.active,
              [.stand, .walk, .run].contains(buddy.currentState) else { return }
        if remaining.isEmpty {
            remaining = BatAction.allCases.shuffled()
            if remaining.last == lastAction { remaining.swapAt(0, remaining.count - 1) }
        }
        guard let action = remaining.last else { return }
        let started: Bool
        switch action {
        case .leap:
            buddy.jump(world); started = true
        case .grapple:
            buddy.webZip(world, scene, toCeiling: true); started = true
        case .flourish:
            buddy.dance(scene); started = true
        case .beacon:
            started = beacon.start(world: world, scene: scene, buddy: buddy)
        case .vehicle:
            started = vehicle.summon(world: world, scene: scene, buddy: buddy, drive: true)
        }
        if started {
            remaining.removeLast()
            lastAction = action
            buddy.didPerformAutomaticAction()
        }
    }
}
