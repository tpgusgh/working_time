# Mac Focus Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menu bar app that toggles, with one click, both the menu bar clock's visibility and macOS Focus/DND, VPN-icon style.

**Architecture:** Single Swift Package executable target using AppKit (`NSStatusItem`). Pure logic (which shell commands to run, on/off state transition) lives in plain Swift types with no AppKit dependency, so it's unit-testable; the AppKit wiring (status item, menu, alerts) is thin and verified manually.

**Tech Stack:** Swift 5.9+, AppKit, Swift Package Manager (no Xcode project, no Electron).

**Spec:** `docs/superpowers/specs/2026-09-03-mac-focus-toggle-design.md`

## Global Constraints

- No Xcode project, no Electron — plain SwiftPM executable target.
- macOS 12 (Monterey) minimum — the `shortcuts` CLI tool (required for `shortcuts run`) ships starting macOS 12.
- No persistence across relaunch; state always starts `false`.
- Do not read live system DND/clock state — only track what this app last set.
- Personal use, unsigned — no notarization/signing step in the build.

---

## File Structure

- `Package.swift` — SwiftPM manifest, one executable target + one test target.
- `Sources/FocusToggle/main.swift` — app entry point, sets `.accessory` activation policy, installs `AppDelegate`.
- `Sources/FocusToggle/AppDelegate.swift` — `NSApplicationDelegate`, owns the one `StatusItemController` instance.
- `Sources/FocusToggle/ToggleState.swift` — pure on/off state holder, no AppKit import.
- `Sources/FocusToggle/FocusAction.swift` — pure enum mapping `.turnOn`/`.turnOff` to the ordered shell commands to run, no AppKit import, no `Process` execution (that's `FocusActionRunner`).
- `Sources/FocusToggle/FocusActionRunner.swift` — runs a `FocusAction`'s commands via `Process`. Thin, not unit tested (would require mutating real system state).
- `Sources/FocusToggle/StatusItemController.swift` — owns `NSStatusItem`, wires click handling to `ToggleState` + `FocusActionRunner`, builds the right-click menu and setup alert.
- `Tests/FocusToggleTests/ToggleStateTests.swift` — tests state flips correctly.
- `Tests/FocusToggleTests/FocusActionTests.swift` — tests the exact command arrays for each action.
- `Scripts/build-app.sh` — wraps the release binary into `FocusToggle.app` with an `LSUIElement` Info.plist.

---

### Task 1: Package scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/FocusToggle/main.swift` (placeholder entry, replaced further in Task 5)

**Interfaces:**
- Produces: an SwiftPM package named `FocusToggle` buildable with `swift build`, with a test target `FocusToggleTests` that can `@testable import FocusToggle`.

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FocusToggle",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "FocusToggle",
            path: "Sources/FocusToggle"
        ),
        .testTarget(
            name: "FocusToggleTests",
            dependencies: ["FocusToggle"],
            path: "Tests/FocusToggleTests"
        )
    ]
)
```

- [ ] **Step 2: Write a placeholder `main.swift`**

```swift
print("FocusToggle scaffold OK")
```

- [ ] **Step 3: Verify the package builds**

Run: `swift build`
Expected: build succeeds, no errors.

- [ ] **Step 4: Commit**

```bash
git add Package.swift Sources/FocusToggle/main.swift
git commit -m "chore: scaffold FocusToggle Swift package"
```

---

### Task 2: `ToggleState` — pure on/off logic

**Files:**
- Create: `Sources/FocusToggle/ToggleState.swift`
- Test: `Tests/FocusToggleTests/ToggleStateTests.swift`

**Interfaces:**
- Produces: `final class ToggleState { var isOn: Bool { get }; func toggle() -> Bool }` — `toggle()` flips `isOn` and returns the new value. Consumed by `StatusItemController` in Task 6.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FocusToggle

final class ToggleStateTests: XCTestCase {
    func test_startsOff() {
        let state = ToggleState()
        XCTAssertFalse(state.isOn)
    }

    func test_toggleFlipsOnThenOff() {
        let state = ToggleState()
        XCTAssertTrue(state.toggle())
        XCTAssertTrue(state.isOn)
        XCTAssertFalse(state.toggle())
        XCTAssertFalse(state.isOn)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ToggleStateTests`
Expected: FAIL — `ToggleState` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
final class ToggleState {
    private(set) var isOn = false

    @discardableResult
    func toggle() -> Bool {
        isOn.toggle()
        return isOn
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ToggleStateTests`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/FocusToggle/ToggleState.swift Tests/FocusToggleTests/ToggleStateTests.swift
git commit -m "feat: add ToggleState on/off logic"
```

---

### Task 3: `FocusAction` — pure command mapping

**Files:**
- Create: `Sources/FocusToggle/FocusAction.swift`
- Test: `Tests/FocusToggleTests/FocusActionTests.swift`

**Interfaces:**
- Produces: `enum FocusAction { case turnOn, turnOff; var commands: [[String]] { get } }` — each inner array is `[executablePath, arg1, arg2, ...]`, in the exact order to run. Consumed by `FocusActionRunner` in Task 4.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FocusToggle

final class FocusActionTests: XCTestCase {
    func test_turnOnCommands() {
        let commands = FocusAction.turnOn.commands
        XCTAssertEqual(commands, [
            ["/usr/bin/defaults", "write", "com.apple.controlcenter", "NSStatusItem VisibleCC Clock", "-int", "0"],
            ["/usr/bin/killall", "ControlCenter"],
            ["/usr/bin/shortcuts", "run", "FocusOn"]
        ])
    }

    func test_turnOffCommands() {
        let commands = FocusAction.turnOff.commands
        XCTAssertEqual(commands, [
            ["/usr/bin/defaults", "write", "com.apple.controlcenter", "NSStatusItem VisibleCC Clock", "-int", "1"],
            ["/usr/bin/killall", "ControlCenter"],
            ["/usr/bin/shortcuts", "run", "FocusOff"]
        ])
    }
}
```

> **Revised by final-review fix wave (2026-09-03):** the key/value/process name below were corrected — see `final-review-fix-report.md` for the empirical verification that motivated this.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FocusActionTests`
Expected: FAIL — `FocusAction` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
enum FocusAction {
    case turnOn
    case turnOff

    var commands: [[String]] {
        switch self {
        case .turnOn:
            return [
                ["/usr/bin/defaults", "write", "com.apple.controlcenter", "NSStatusItem VisibleCC Clock", "-int", "0"],
                ["/usr/bin/killall", "ControlCenter"],
                ["/usr/bin/shortcuts", "run", "FocusOn"]
            ]
        case .turnOff:
            return [
                ["/usr/bin/defaults", "write", "com.apple.controlcenter", "NSStatusItem VisibleCC Clock", "-int", "1"],
                ["/usr/bin/killall", "ControlCenter"],
                ["/usr/bin/shortcuts", "run", "FocusOff"]
            ]
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FocusActionTests`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/FocusToggle/FocusAction.swift Tests/FocusToggleTests/FocusActionTests.swift
git commit -m "feat: add FocusAction command mapping"
```

---

### Task 4: `FocusActionRunner` — executes the commands

**Files:**
- Create: `Sources/FocusToggle/FocusActionRunner.swift`

**Interfaces:**
- Consumes: `FocusAction.commands` from Task 3.
- Produces: `struct FocusActionRunner { static func run(_ action: FocusAction) }`. Consumed by `StatusItemController` in Task 6.

No automated test here — running the real commands mutates real system state (Control Center prefs, kills `ControlCenter`, fires a Shortcut). Per the spec's Testing section, this is verified manually together with Task 6.

> **Revised by final-review fix wave (2026-09-03):** `run` was changed to return `@discardableResult -> Bool` (true only if every command exits status 0), so `StatusItemController` can detect a silent `shortcuts run` failure (e.g. the Shortcuts aren't set up yet) and show the setup alert instead of failing silently. Current implementation:

- [ ] **Step 1: Write the implementation**

```swift
import Foundation

struct FocusActionRunner {
    @discardableResult
    static func run(_ action: FocusAction) -> Bool {
        var allSucceeded = true
        for command in action.commands {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command[0])
            process.arguments = Array(command.dropFirst())
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    allSucceeded = false
                }
            } catch {
                allSucceeded = false
            }
        }
        return allSucceeded
    }
}
```

- [ ] **Step 2: Verify the package still builds**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/FocusToggle/FocusActionRunner.swift
git commit -m "feat: add FocusActionRunner to execute focus action commands"
```

---

### Task 5: `AppDelegate` + real `main.swift`

**Files:**
- Modify: `Sources/FocusToggle/main.swift` (replace Task 1 placeholder)
- Create: `Sources/FocusToggle/AppDelegate.swift`
- Create: `Sources/FocusToggle/StatusItemController.swift` (stub — Task 6 replaces it)

**Interfaces:**
- Consumes: `StatusItemController()` — this task only needs it to have a parameterless initializer; Task 6 fills in the real behavior behind that same initializer.
- Produces: a running `NSApplication` with `.accessory` activation policy (no Dock icon).

- [ ] **Step 1: Write `AppDelegate.swift`**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusItemController()
    }
}
```

- [ ] **Step 2: Replace `main.swift`**

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 3: Stub `StatusItemController` so the build succeeds**

```swift
import AppKit

final class StatusItemController: NSObject {
    override init() {
        super.init()
    }
}
```

- [ ] **Step 4: Verify build**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/FocusToggle/main.swift Sources/FocusToggle/AppDelegate.swift Sources/FocusToggle/StatusItemController.swift
git commit -m "feat: wire NSApplication entry point with accessory activation policy"
```

---

### Task 6: `StatusItemController` — real implementation

**Files:**
- Modify: `Sources/FocusToggle/StatusItemController.swift` (replace Task 5 stub)

**Interfaces:**
- Consumes: `ToggleState` (Task 2), `FocusAction` + `FocusActionRunner` (Tasks 3–4).
- Produces: the full menu bar UI. Nothing else depends on this — it's the top of the call graph.

> **Revised by final-review fix wave (2026-09-03):** `toggle()` now dispatches `FocusActionRunner.run` to a background queue (`DispatchQueue.global(qos: .userInitiated)`) instead of running it synchronously on the main thread — `shortcuts run` can take 0.5-2s (XPC round trip) and was blocking the UI/freezing the already-updated icon's redraw. On failure it hops back to the main thread and calls `showSetupInstructions()` automatically. Current implementation:

- [ ] **Step 1: Write the full implementation**

```swift
import AppKit

final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let state = ToggleState()

    override init() {
        super.init()
        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        updateIcon(isOn: false)
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggle()
        }
    }

    private func toggle() {
        let isOn = state.toggle()
        updateIcon(isOn: isOn)
        let action: FocusAction = isOn ? .turnOn : .turnOff
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let succeeded = FocusActionRunner.run(action)
            if !succeeded {
                DispatchQueue.main.async {
                    self?.showSetupInstructions()
                }
            }
        }
    }

    private func updateIcon(isOn: Bool) {
        statusItem.button?.image = NSImage(
            systemSymbolName: isOn ? "moon.fill" : "moon",
            accessibilityDescription: "Focus Toggle"
        )
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let setupItem = NSMenuItem(title: "Setup Instructions", action: #selector(showSetupInstructions), keyEquivalent: "")
        setupItem.target = self
        menu.addItem(setupItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func showSetupInstructions() {
        let alert = NSAlert()
        alert.messageText = "One-time setup"
        alert.informativeText = """
        Open Shortcuts.app and create two shortcuts:

        1. "FocusOn" — one action: Set Focus \u{2192} On (Do Not Disturb)
        2. "FocusOff" — one action: Set Focus \u{2192} Off

        FocusToggle runs these by name when you click the menu bar icon.
        """
        alert.addButton(withTitle: "Open Shortcuts.app")
        alert.addButton(withTitle: "Close")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Run the automated test suite (regression check)**

Run: `swift test`
Expected: all `ToggleStateTests` and `FocusActionTests` still PASS (this task touched no pure-logic files, so this just confirms nothing broke).

- [ ] **Step 4: Manual verification — one-time Shortcuts setup**

In Shortcuts.app, create `FocusOn` (one "Set Focus" action, On) and `FocusOff` (one "Set Focus" action, Off). Required once, on the machine actually running the app — the plan cannot do this step for you.

- [ ] **Step 5: Manual verification — run and click**

Run: `swift run FocusToggle`
Then:
1. Confirm a moon icon appears in the menu bar, no Dock icon.
2. Left-click it: confirm the menu bar clock disappears and Focus turns on (check Control Center), and the icon switches to the filled moon.
3. Left-click again: confirm the clock reappears, Focus turns off, icon reverts to outline moon.
4. Right-click: confirm a menu with "Setup Instructions" and "Quit" appears.
5. Click "Setup Instructions": confirm the alert text is readable and "Open Shortcuts.app" opens Shortcuts.

- [ ] **Step 6: Commit**

```bash
git add Sources/FocusToggle/StatusItemController.swift
git commit -m "feat: implement StatusItemController menu bar toggle UI"
```

---

### Task 7: Packaging script

**Files:**
- Create: `Scripts/build-app.sh`

**Interfaces:**
- Consumes: the release binary produced by `swift build -c release` (target name `FocusToggle` from Task 1's `Package.swift`).
- Produces: `FocusToggle.app` at the repo root, double-clickable, no Dock icon (via `LSUIElement`).

- [ ] **Step 1: Write the script**

```bash
#!/bin/bash
set -euo pipefail

APP_NAME="FocusToggle"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.mirkim.focustoggle</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "Built ${APP_BUNDLE}"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x Scripts/build-app.sh`

- [ ] **Step 3: Run it and verify the bundle**

Run: `./Scripts/build-app.sh`
Expected: prints `Built FocusToggle.app`; `FocusToggle.app/Contents/MacOS/FocusToggle` and `FocusToggle.app/Contents/Info.plist` both exist.

- [ ] **Step 4: Manual verification — double-click launch**

In Finder, right-click `FocusToggle.app` → Open (first run only, to pass Gatekeeper). Confirm it launches with no Dock icon and the menu bar icon appears, same behavior as Task 6 Step 5.

- [ ] **Step 5: Commit**

```bash
git add Scripts/build-app.sh
git commit -m "chore: add build-app.sh to package FocusToggle.app"
```
