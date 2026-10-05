import AppKit

let application = NSApplication.shared
let delegate = MDAnyWhereAppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
