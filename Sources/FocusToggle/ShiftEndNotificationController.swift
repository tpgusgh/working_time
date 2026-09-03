import AppKit

final class ShiftEndNotificationController {
    private let displayDuration: TimeInterval = 5

    func show(message: String) {
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = true

            let label = NSTextField(labelWithString: message)
            label.font = .systemFont(ofSize: 64, weight: .bold)
            label.textColor = .white
            label.alignment = .center
            label.frame = NSRect(x: 0, y: screen.frame.height / 2 - 50, width: screen.frame.width, height: 100)
            label.autoresizingMask = [.width]
            window.contentView?.addSubview(label)

            window.orderFrontRegardless()

            DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
                window.orderOut(nil)
            }
        }
    }
}
