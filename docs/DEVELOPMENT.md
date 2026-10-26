# Developer guide

Super Buddy is a native macOS AppKit/SpriteKit application. Characters are drawn
from vector shapes at runtime. There is no character asset pipeline, external
service or plugin loader: extending the app means editing Swift and rebuilding.

## Build and inspect

Start with [the fork setup](../CONTRIBUTING.md). Useful commands:

| Command | Result |
| --- | --- |
| `make run` | Generate the Xcode project, build Release, launch the app |
| `make build CONF=Debug` | Build a Debug app |
| `make check` | Compile and run the headless Spider-Buddy simulation |
| `make check-all` | Run the simulations for all four current buddies |
| `make preview` | Render `docs/preview.png` using the real rig and poses |
| `make icon` | Regenerate `Resources/AppIcon.icns` |
| `make dist` | Build and verify universal DMG/ZIP packages in `dist/` |

`build/Build/Products/Release/SuperBuddy.app` is the normal build output.
After `make preview`, render selected shots at a larger size with:

```sh
./.build/preview docs/my-preview.png 'Bat-Buddy,Bat-Beacon'
```

`make clean` removes generated projects, builds, distribution packages and the main
preview image. Regenerate the preview if you intend to commit it.

## Architecture and frame flow

| File | Responsibility |
| --- | --- |
| `Sources/App/AppDelegate.swift` | Overlay window, display changes, preferences migration, click-through timer |
| `Sources/App/MenuBar.swift` | Status icon, character/action menus and timing settings panel |
| `Sources/Scene/BuddyScene.swift` | Scene lifecycle, frame loop, input, commands and preferences |
| `Sources/Buddy/Skin.swift` | Character IDs, visible names, costumes, baddie rosters and archetypes |
| `Sources/Buddy/Rig.swift` | Vector artwork, joint hierarchy, gaze and costume details |
| `Sources/Buddy/Pose.swift` | Joint-angle snapshots, blending and keyframe timelines |
| `Sources/Buddy/Motions.swift` | Pure functions mapping time to a pose |
| `Sources/Buddy/Buddy.swift` | State machine, movement, physics, hit area and automatic action cooldown |
| `Sources/Scene/World.swift` | Screen rectangle, surfaces, contact positions and boundaries |
| `Sources/Scene/Battle.swift` | Fight scheduling, buddy attacks and baddie cleanup |
| `Sources/Buddy/Villain.swift` | Baddie movement, telegraphs, attacks and damage |
| `Sources/Buddy/Effects.swift` | Short-lived visual effects |
| `Sources/Buddy/BatSignal.swift` | Bat-Beacon and swarm lifecycle |
| `Sources/Buddy/Batmobile.swift` | Buddy-Mobile boarding, driving, wall route and exit lifecycle |
| `Sources/Support/TimingSettings.swift` | Persisted timing values, defaults and bounds |
| `Tools/simcheck.swift` | Simulation, interactions, timing, effect and vehicle checks |
| `Tools/preview.swift` | Software renderer and animation contact-sheet shots |

Each scene frame updates the vehicle, buddy, beacon and battle director. The buddy
advances its state and physics, selects a target pose, blends towards it, then
applies it to the rig. Independent effects should follow this explicit frame flow
when they need reliable pause/cancel behaviour.

### Coordinates and scale

SpriteKit uses a bottom-left origin and points, not screen pixels. The overlay
covers one selected display. In body space the hip is the origin; an unrotated limb
hangs down, and positive joint rotation swings it forwards. `Pose.head` is relative
to the torso, and elbow/knee rotations are relative to the upper limb.

The model owns position and velocity. The rig only draws them. `Buddy.scale` is the
user's size; its rig scale also includes `Skin.bodyScale`. Use `buddy.reach` for
contact geometry rather than hard-coded pixel offsets. Do not apply the body scale
a second time. A change in scale must update `world.reach` and keep the buddy inside
the world, as the existing scene methods do.

## Add a buddy

The following example uses a new `Robot-Buddy`. It is a recipe, not a complete
implementation to paste over the existing code.

1. **Define a skin** in `Skin.swift`. Reuse the rig before adding new artwork:

   ```swift
   static let robot = Skin(
       name: "Robot-Buddy",
       suit: SKColor(white: 0.65, alpha: 1),
       suitDark: SKColor(white: 0.35, alpha: 1),
       limb: SKColor(white: 0.45, alpha: 1),
       limbDark: SKColor(white: 0.25, alpha: 1),
       webbing: false,
       emblem: false
   )
   ```

2. **Register a stable ID**: add `.robot` to `BuddyCharacter`, then return its title
   and skin in `title` and `skin`. The Choose Buddy menu uses `allCases`, so a
   registered case appears automatically. Raw IDs are saved in `buddyCharacter`;
   avoid renaming them when changing visible names. Current internal legacy IDs
   (`spider`, `deadpool`, `batman`, `hulk`) intentionally preserve saved choices.
3. **Register opponents** in `Skin.villains(for:)`. Create a roster or explicitly
   reuse an appropriate one. The compiler will require a branch for the new case.
4. **Choose its capabilities** in `Buddy.swift`. Audit `decide`, `targetPose`,
   `jump`, `updateTilt`, `tryLand` and the action guards. Several existing paths use
   character-specific conditions. A new case must not silently fall through into
   Spider-Buddy's web behaviour. Start with floor walking, idle and jumping.
5. **Add artwork only as needed**. A new `Costume` or `Headgear` case can activate a
   builder in `Rig.swift`. Attach accessories to the joint that should move them.
   Use darker far limbs, readable silhouettes and a hit area that matches the body.
   Update exhaustive switches when adding enum cases.
6. **Add poses** in `Motions.swift`, and select them for the new character in
   `Buddy.targetPose()`. Reuse physics while giving the character its own stance.
7. **Wire character-specific actions** using the next recipe. Keep unsuitable
   commands hidden in `menuWillOpen`; check capability guards in scene/model code
   as well. Hiding a menu item alone does not prevent automatic use of an action.
8. **Add verification and previews**. Extend CLI selection in `Tools/simcheck.swift`
   and `make check-all` for the new ID. Add `Shot` entries in `Tools/preview.swift`.
   Use the new skin in a pose before implementing a whole animation set.

New Swift files under `Sources/Buddy/` and `Sources/Support/` are included in the
headless tools automatically. Add new scene helpers to `CORE_SOURCES` in the
Makefile if those tools need them. XcodeGen discovers app sources under `Sources/`
when it regenerates the project.

## Add an animation or action

### Start with a pure pose function

A pose contains shoulder, elbow, thigh, knee, torso and head angles plus hip offset
and squash. Keep animation functions deterministic for a given time:

```swift
static func robotWave(_ t: CGFloat) -> Pose {
    var pose = Pose.stand
    pose.armNear = 2.5
    pose.foreNear = 0.8 + 0.35 * sin(t * 8)
    pose.head = -0.1
    return pose
}
```

For an initial wave, reuse `.dance` and route that character's dance pose to
`Motion.robotWave`. This avoids adding a state just for a cosmetic variant.
For staged actions use `Pose.timeline([prepare, strike, recover], progress)`, where
`progress` goes from zero to one. `Pose.loop` is useful for repeating motion.

### For a new state

1. Add the state to `Buddy.State`. Mark it airborne only if its physics needs that.
2. Give it a duration in `enter`, advance/finish it in `step`, and return its pose
   in `targetPose`. Do not scale the frame delta to make the animation last longer;
   normalise `stateTime` by the desired duration.
3. Trigger effects once at a cue time, rather than every frame. The weapon actions
   use `weaponEffectIndex` for this. Short `FX` nodes remove themselves after their
   actions; longer sequences should have explicit `start/update/cancel` ownership.
4. Add a guarded scene command and menu `Tag`, item and handler. Check character,
   grabbed/vehicle state, grounded requirements and pause as appropriate.
5. If the state is exclusive to one buddy, cancel or reset it on character change.
   Never leave a replacement buddy in another character's exclusive action.
6. If combat should use it, update `Battle` intentionally: an animation alone does
   not deal damage. Match attack classification and range to the new action.

### Make an action automatic

`Buddy.canPerformAutomaticAction` is the shared eligibility/cooldown gate.
`Buddy.decide` already records non-locomotion choices using its `defer` block.
External directors such as the beacon and car must check that gate and call
`buddy.didPerformAutomaticAction()` only after a successful automatic start.

Manual menu commands bypass the automatic cooldown. An interval of zero must stop
automatic actions without disabling manual commands. Do not change animation
speed or fight mechanics when adjusting the automatic interval. Use the persisted
`TimingSettings` values instead of adding another unrelated user setting.

### Cancellation and desktop behaviour

Restore opacity, visibility and model ownership on completion or cancellation.
Check character switch, drag, reset, scale/display change, pause and entering or
leaving a vehicle. The beacon and car demonstrate these paths. Never clear all
scene children to stop one action: other directors own nodes in the same scene.

Decorative effects should not intercept desktop clicks. Keep the overlay's
`ignoresMouseEvents` and buddy-shaped hit testing intact. Fullscreen and display
behaviour need manual checks on real hardware; headless tests do not prove them.

## Add a baddie

Add a `Skin` to the relevant roster using an original `-Baddie` name. Choose an
existing archetype:

- `brawler`: closes the distance and trades melee attacks.
- `charger`: telegraphs, rushes forward, then recovers.
- `shooter`: keeps range and fires bolts.
- `flyer`: hovers, dives and climbs back into the air.

A skin changes appearance; an archetype changes behaviour. Unique attacks require
changes in `Villain` and possibly `Battle`, not just a name or colour change. Ensure
telegraphs reach the attack state, the buddy can respond, and defeated baddies are
removed. The simulation runs an uninterrupted attack check and full fights.

## Validation and debugging

`make check-all` covers the four current buddies. Their CLI switches use the stable
internal IDs: `--deadpool`, `--batman`, `--hulk`; the default is Spider-Buddy. Extend
this selection and the relevant assertions when adding another buddy.

The broad smoke simulation uses a short action cooldown to cover many behaviours
in 600 simulated seconds. Separate timing checks verify actual defaults, saved
preferences, pause, disabling and manual overrides. Do not weaken those timing
checks just to make a new automatic action fire sooner in a smoke test.

Add focused assertions for a new action's state transitions, finite positions,
boundaries, completion, cleanup and manual/automatic guards. The preview renderer
uses the real node tree but is a software approximation: it does not execute live
SpriteKit actions or prove GPU effects look correct. Verify moving effects in the
running app as well. To enable the existing debug trace, create
`/tmp/superbuddy.debug` before launching; remove that flag afterwards.

## Package a fork or release

For a separately installed fork, change the bundle ID in `project.yml`, the product
name and any related packaging paths. Review the legacy preference import in
`AppDelegate.swift` so your fork does not unintentionally import another app's
settings. Avoid changing shared user preferences during tests; use an isolated
`UserDefaults` suite as the timing checks do.

For a release:

1. Update the marketing version, generated Info properties and build number in
   `project.yml`. The distribution script takes its version from the built app.
2. Run `make check-all`, `make preview`, then `make dist`. Packaging requires full
   Xcode and permission to attach/detach a temporary disk image.
3. Verify both `arm64` and `x86_64`, the app's signature, and the app inside the DMG.
4. Commit and push the source; create a new GitHub tag/release at that commit and
   upload the DMG/ZIP. Do not replace files under an already released version.
5. Update the Homebrew cask's version and SHA-256 to match the published DMG:

   ```sh
   shasum -a 256 dist/SuperBuddy-VERSION-universal.dmg
   ```

6. Run Homebrew style checks and test installation before publishing the tap change.
   In a fork, point URLs at your repository and maintain your own tap if needed.

Current builds are ad-hoc signed, not notarized. Do not add automatic quarantine
removal to make installations appear notarized. Developer ID signing and
notarization can be supplied through the distribution script's `SIGN_IDENTITY`
and `NOTARY_PROFILE` options when available.
