import AppKit

// 進入點：建立 NSApplication，設 .accessory 隱藏 Dock 圖示、不搶焦點，交給 AppDelegate 組裝。
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
