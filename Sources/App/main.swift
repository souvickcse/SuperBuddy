import AppKit

// Spider Buddy - a tiny web-slinging desktop companion.
// Lives in the menu bar only (no Dock icon) and draws itself on a transparent
// always-on-top overlay so it can walk on the edges of the screen.

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()
