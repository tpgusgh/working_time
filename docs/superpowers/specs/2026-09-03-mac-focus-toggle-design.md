# Mac Focus Toggle — Design Spec

## Purpose

Menu bar utility for macOS. One click hides the menu bar clock and turns on
Focus/Do Not Disturb, so the user stops glancing at the time or getting
pulled by notifications while working. Click again to undo both. VPN-icon
style: the menu bar icon itself is the on/off switch.

Windows version (KakaoTalk/Discord notification blocking) is a separate,
later sub-project — out of scope here.

## Architecture

Single-target Swift Package (executable, AppKit), no Xcode project, no
Electron. The whole app is a menu bar status item with two states.

- `Sources/FocusToggle/main.swift` — app entry, `NSApplication` with
  `LSUIElement` (no Dock icon, no window).
- `Sources/FocusToggle/StatusItemController.swift` — owns the
  `NSStatusItem`, tracks `isOn: Bool`, renders icon per state, routes
  left-click to toggle and right-click to the context menu.
- `Sources/FocusToggle/FocusActions.swift` — shells out to `defaults`,
  `killall`, and `shortcuts run` for the two state transitions.

No persistence layer: state starts `false` on every launch. Not tracking OS
truth (e.g. reading whether DND is already on) — the icon reflects what
this app last set, not live system state. Acceptable for a personal tool;
if it ever needs to reconcile with system state, that's a real feature to
design later, not a today problem.

## Behavior

**Turn on** (`isOn: false → true`):
1. `defaults write com.apple.controlcenter Clock -bool false && killall SystemUIServer`
2. `shortcuts run "FocusOn"`
3. Icon switches to filled/highlighted state.

**Turn off** (`isOn: true → false`):
1. `defaults write com.apple.controlcenter Clock -bool true && killall SystemUIServer`
2. `shortcuts run "FocusOff"`
3. Icon switches to outline/default state.

Both actions run via `Process` (`/usr/bin/env`), synchronously from the
click handler — each command is near-instant, no need for async/spinner.

## First-run setup (manual, one-time)

The app cannot create Shortcuts programmatically. The user must open
Shortcuts.app once and create two shortcuts named exactly `FocusOn` and
`FocusOff`, each containing one "Set Focus" action (On / Off respectively).
Right-click menu item "Setup Instructions" opens a short in-app alert with
these steps, plus a button to open Shortcuts.app.

## Error handling

If `shortcuts run "FocusOn"` fails (e.g. shortcut not created yet), macOS
will show its own "Shortcut not found" system error — no need to duplicate
that. The app does not retry, does not roll back the clock-hide step (there
is no meaningful rollback for a `defaults write` — the user can just click
again). This is a personal automation trigger, not a system needing
transactional guarantees.

## Known limitation

`defaults write com.apple.controlcenter Clock -bool false` is an
undocumented Control Center preference. It can stop working after a macOS
update. No workaround planned — if it breaks, it breaks, fix when it
happens (ponytail: accepted ceiling, not solved now).

## Distribution

Personal use, unsigned:
- `swift build -c release` produces the binary.
- A short shell script wraps it into `FocusToggle.app` (Info.plist with
  `LSUIElement = true`, copies the binary in) so it can be double-clicked /
  added to Login Items.
- First launch requires right-click → Open once to pass Gatekeeper.

## Explicitly out of scope

- Reading live system DND/clock state.
- State persistence across relaunch.
- Auto-launch at login (user can add it via System Settings themselves).
- Global keyboard shortcut.
- Any Windows-side work.

## Testing

Nothing here is business logic worth a unit test — it's three shell
commands gated by one boolean. Verification is manual: click once, confirm
clock hides and Focus turns on; click again, confirm both revert. No
`demo()`/self-check script — there is no logic branch to assert against
that doesn't require a real macOS session with the two Shortcuts already
created.
