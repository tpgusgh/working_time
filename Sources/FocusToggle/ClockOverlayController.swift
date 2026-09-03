import AppKit
import ApplicationServices

enum ClockOverlayGeometry {
    // `sourceScreenFrame` is the frame of whichever screen the clock was
    // actually read from (AX reports the clock on whichever display is
    // currently active, not always the system's primary display) — the
    // "distance from the right edge" offset is computed relative to that
    // screen, then reapplied to every other connected screen.
    static func overlayFrame(forScreen screenFrame: CGRect, sourceScreenFrame: CGRect, clockFrame: CGRect, padding: CGFloat) -> CGRect {
        let padded = clockFrame.insetBy(dx: -padding, dy: -padding)
        let distanceFromRightEdge = sourceScreenFrame.maxX - padded.maxX
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
        guard !NSScreen.screens.isEmpty else { return }
        // The clock's global X position tells us which screen it's actually
        // on — that's the reference for the "distance from right edge"
        // offset, regardless of which screen the system considers primary.
        // X-only check: clockFrame's Y is in AX's top-left-origin space,
        // NSScreen.frame's Y is AppKit's bottom-left-origin space, so they
        // aren't directly comparable — X ranges are enough to tell screens
        // apart in a horizontal arrangement, which is what matters here.
        let sourceScreen = NSScreen.screens.first { $0.frame.minX <= clockFrame.midX && clockFrame.midX < $0.frame.maxX }
            ?? NSScreen.screens[0]
        for screen in NSScreen.screens {
            let frame = ClockOverlayGeometry.overlayFrame(
                forScreen: screen.frame,
                sourceScreenFrame: sourceScreen.frame,
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
        let options: [String: Bool] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else { return nil }
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
        alert.messageText = "손쉬운 사용 권한 필요"
        alert.informativeText = "시계를 찾아서 가리려면 손쉬운 사용 권한이 필요합니다. 시스템 설정 \u{2192} 개인정보 보호 및 보안 \u{2192} 손쉬운 사용에서 허용해주세요."
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "닫기")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}
