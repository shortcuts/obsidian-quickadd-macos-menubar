import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// No Dock icon and no app menu: the app lives in the menu bar.
app.setActivationPolicy(.accessory)
app.run()
