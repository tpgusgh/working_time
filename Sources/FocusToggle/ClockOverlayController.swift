import AppKit
import ApplicationServices

enum ClockOverlayGeometry {
    static func overlayFrame(forScreen screenFrame: CGRect, primaryScreenFrame: CGRect, clockFrame: CGRect, padding: CGFloat) -> CGRect {
        let padded = clockFrame.insetBy(dx: -padding, dy: -padding)
        let distanceFromRightEdge = primaryScreenFrame.maxX - padded.maxX
        let x = screenFrame.maxX - distanceFromRightEdge - padded.width
        let y = screenFrame.maxY - padded.minY - padded.height
        return CGRect(x: x, y: y, width: padded.width, height: padded.height)
    }
}

final class ClockOverlayController {
    private let overlayPadding: CGFloat = 6
    private var overlayWindows: [NSWindow] = []

    func show() {
        guard overlayWindows.isEmpty else { return }
        guard let clockFrame = findClockFrame() else {
            presentAccessibilityAlert()
            return
        }
        guard let primaryScreen = NSScreen.screens.first else { return }
        for screen in NSScreen.screens {
            let frame = ClockOverlayGeometry.overlayFrame(
                forScreen: screen.frame,
                primaryScreenFrame: primaryScreen.frame,
                clockFrame: clockFrame,
                padding: overlayPadding
            )
            let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = true
            window.orderFrontRegardless()
            overlayWindows.append(window)
        }
    }

    func hide() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
    }

    private func findClockFrame() -> CGRect? {
        guard AXIsProcessTrusted() else { return nil }
        guard let controlCenter = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.controlcenter" }) else {
            return nil
        }
        let appElement = AXUIElementCreateApplication(controlCenter.processIdentifier)

        // ControlCenter is a menu-extras host, not a normal app with a File/Edit
        // menu bar: kAXMenuBarAttribute returns kAXErrorNoValue for it (verified
        // empirically on this machine). kAXExtrasMenuBarAttribute is the correct,
        // documented attribute for the status/menu-extra area the clock lives in.
        var menuBarValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXExtrasMenuBarAttribute as CFString, &menuBarValue) == .success,
              let menuBar = menuBarValue else { return nil }

        var itemsValue: AnyObject?
        guard AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &itemsValue) == .success,
              let items = itemsValue as? [AXUIElement] else { return nil }

        for item in items {
            var identifierValue: AnyObject?
            AXUIElementCopyAttributeValue(item, "AXIdentifier" as CFString, &identifierValue)
            guard (identifierValue as? String) == "com.apple.menuextra.clock" else { continue }

            var positionValue: AnyObject?
            var sizeValue: AnyObject?
            guard AXUIElementCopyAttributeValue(item, kAXPositionAttribute as CFString, &positionValue) == .success,
                  AXUIElementCopyAttributeValue(item, kAXSizeAttribute as CFString, &sizeValue) == .success else { return nil }

            var position = CGPoint.zero
            var size = CGSize.zero
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
            return CGRect(origin: position, size: size)
        }
        return nil
    }

    private func presentAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility permission needed"
        alert.informativeText = "FocusToggle needs Accessibility access to find and cover the menu bar clock. Grant it in System Settings \u{2192} Privacy & Security \u{2192} Accessibility."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Close")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}
