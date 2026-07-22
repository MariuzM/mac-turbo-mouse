# Turbo Mouse

A macOS menu bar app for per-device pointer tuning, in the spirit of [LinearMouse](https://github.com/linearmouse/linearmouse): acceleration curve, pointer speed, and scroll acceleration — configured per mouse, with keyboards left alone.

## Features

- **Settings window** (opened from the menu bar icon) with a device sidebar — every pointer-capable device gets its own configuration.
- **Keyboard detection**: devices whose HID usage pairs go beyond mouse/pointer (e.g. keyboards with a pointer collection) are detected but excluded by default. A per-device *Manage* switch overrides this in either direction.
- **Pointer**
  - *Disable pointer acceleration* — raw linear 1:1 tracking (`-1`)
  - *Acceleration* — 0 to 20, fine-grained slider (quadratic scale for precision near 0) plus exact numeric entry; presets None / Low / Default / High
  - *Pointer speed* — ×0.1 to ×10 multiplier, implemented via `HIDPointerResolution`. macOS normalizes mice to a 400 CPI baseline, so ×(DPI ÷ 400) approximates Windows 1:1 (×2 for an 800 DPI mouse). Not applied in raw (−1) mode, where macOS skips the scaling stage entirely.
- **Scrolling**
  - *Disable scroll acceleration* — fixed distance per wheel step
  - *Scroll acceleration* — 0 to 10
- **Smooth scrolling** — turns discrete wheel steps into a trackpad-like glide. Implemented with a `CGEventTap` (requires Accessibility permission): discrete wheel events are suppressed and re-emitted as a 60 fps stream of continuous pixel-scroll events with exponential ease-out. Tunable distance per step (15–100 px) and glide duration (0.1–0.6 s). Trackpad scrolling (continuous events) passes through untouched; the tap applies to wheel events from all mice while enabled, since scroll events carry no device identity. Because the dev build is ad-hoc signed, re-building the app may require re-granting Accessibility (remove and re-add it in System Settings → Privacy & Security → Accessibility).
- **Windows mode** — reproduces the Windows pointer-speed slider with *Enhance Pointer Precision* off. Notch multipliers ([per the MarkC documentation](https://donewmouseaccel.blogspot.com/2010/03/markc-windows-7-mouse-acceleration-fix.html)): 1→0.03125, 2→0.0625, 3→0.25, 4→0.5, 5→0.75, **6→1.0 (1:1)**, 7→1.5, 8→2.0, 9→2.5, 10→3.0, 11→3.5. Mouse DPI cancels out (the same device sends identical counts to both OSes), so matching only requires the multiplier. Because macOS applies an extra constant gain in its linear path, a one-time **calibration** measures it: the app alternates the device between raw (−1) and linear (0) mode for ~6 seconds while you move the mouse, compares post-processing deltas from alternating time buckets, and takes the median ratio. Windows mode then sets acceleration 0 and pointer speed = multiplier ÷ measured gain, and turns scroll acceleration off (Windows scrolls fixed lines per notch).
- Live curve preview, quick per-device enable toggles in the menu bar dropdown.

## How it works

macOS stores these tunables as fixed-point 16.16 HID properties per pointer service. The effective keys are device-specific: each service declares them via `HIDPointerAccelerationType` and `HIDScrollAccelerationType` (for mice: `HIDMouseAcceleration` — the value behind the System Settings tracking slider — and `HIDMouseScrollAcceleration`, default `0.3125`). The generic `HIDPointerAcceleration` / `HIDScrollAcceleration` keys are only fallbacks that `IOHIDPointerScrollFilter` ignores when a type is declared — writing them accepts the value but changes nothing, a classic trap. Turbo Mouse resolves the declared keys per service and writes both resolved and generic keys, plus `HIDPointerResolution` (default 400) for pointer speed. It talks to the HID event system directly (`IOHIDEventSystemClientCreateWithType` with a passive client — the simple client type cannot write resolution) and:

- applies each managed device's config and re-checks every 2 seconds, so system resets (sleep/wake, Settings changes, device re-plug) don't stick
- captures each device's baseline values when first seen and restores them when a device is un-managed or the app quits
- identifies devices by vendor/product ID, so configs survive re-plugs and relaunches

A `-1` (disabled) write may be normalized to `0` by the system — both mean "no curve", and the enforcement loop accepts either.

Acceleration doubles as the overall speed multiplier (that's how macOS uses the parameter), so use *Pointer speed* to compensate after lowering it.

No root, no accessibility permission, no kernel extension.

## Requirements

- macOS 14+
- Swift toolchain (Xcode or Command Line Tools)

## Run

```sh
swift run
```

## Build the app bundle

```sh
./scripts/make-app.sh
open build/TurboMouse.app
```

Copy `build/TurboMouse.app` to `/Applications` if you want it around permanently.

## Notes

- Configs persist in `UserDefaults` keyed by `vendorID:productID`; the app must be running to keep settings enforced.
- Quitting restores every managed device to its captured baseline.
- The curve preview is illustrative, not a measurement of Apple's exact internal curve.
- Scroll direction, button remapping, and modifier-key scrolling (LinearMouse's event-tap features) are out of scope — they require an accessibility-permission event tap rather than HID properties.
