# Contributing to Super Buddy

Thanks for helping build more desktop companions. Start with a small change: a new
pose or costume is easier to review than a new physics system.

## Set up a fork

1. Fork this repository on GitHub.
2. Clone your fork and create a branch:

   ```sh
   git clone https://github.com/YOUR-USERNAME/SuperBuddy.git
   cd SuperBuddy
   git remote add upstream https://github.com/souvickcse/SuperBuddy.git
   git switch -c add-my-buddy
   ```

3. On macOS, install and open Xcode. In **Xcode → Settings → Locations**, select
   the installed Xcode under **Command Line Tools**. Install XcodeGen with
   `brew install xcodegen` if it is missing.
4. Run `make run`. The shield icon in the menu bar is the app's interface.

See [the developer guide](docs/DEVELOPMENT.md) for the architecture and complete
recipes for buddies, animations, actions and baddies.

## Before opening a pull request

```sh
make check-all
make preview
make build
```

- Include a screenshot or contact-sheet preview of visual changes.
- Describe the buddy/action, how to trigger it, and what you verified.
- Check manual commands, automatic timing, pause, dragging, switching buddies,
  resizing and display changes. Check that temporary nodes disappear afterwards.
- Keep manual commands usable when automatic actions are disabled.
- Use original Buddy/Baddie names and artwork for new additions.
- Commit source and relevant documentation/preview images. Generated `.xcodeproj`,
  caches, binaries and `dist/` archives are ignored; do not force-add them.
- Do not edit the generated Xcode project. Change `project.yml` and regenerate it.

If a hardware-dependent check could not be performed (for example, two displays),
say so in the pull request. Keep unrelated refactors in a separate contribution.
