import AppKit
import CoreGraphics
import QuartzCore

final class ScrollSmoother {
    static let shared = ScrollSmoother()

    var step: Double = 40
    var duration: Double = 0.25
    var smoothingEnabled = false
    var horizontalModifier: CGEventFlags?

    private static let marker: Int64 = 0x54424D53

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var pendingX: Double = 0
    private var pendingY: Double = 0
    private var lastTick: CFTimeInterval = 0

    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func setEnabled(_ enabled: Bool) {
        if enabled { start() } else { stop() }
    }

    private func start() {
        guard tap == nil, Self.hasAccessibility else { return }
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                let smoother = Unmanaged<ScrollSmoother>.fromOpaque(info).takeUnretainedValue()
                return smoother.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        tap = nil
        timer?.invalidate()
        timer = nil
        pendingX = 0
        pendingY = 0
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel,
              event.getIntegerValueField(.eventSourceUserData) != Self.marker,
              event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0
        else { return Unmanaged.passUnretained(event) }

        let rotate = horizontalModifier.map { event.flags.contains($0) } ?? false
        guard smoothingEnabled || rotate else { return Unmanaged.passUnretained(event) }

        var dy = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        var dx = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        guard dx != 0 || dy != 0 else { return Unmanaged.passUnretained(event) }

        if rotate {
            dx = dy
            dy = 0
        }

        if smoothingEnabled {
            pendingY += dy * step
            pendingX += dx * step
            startTimerIfNeeded()
            return nil
        }

        let points = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let fixed = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(dx))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: points)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: fixed)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0)
        if let horizontalModifier {
            event.flags.remove(horizontalModifier)
        }
        return Unmanaged.passUnretained(event)
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        lastTick = CACurrentMediaTime()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.emitFrame()
        }
        t.tolerance = 0.002
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func emitFrame() {
        let now = CACurrentMediaTime()
        let dt = now - lastTick
        lastTick = now
        let tau = max(duration, 0.05) / 4
        let decay = exp(-dt / tau)
        var outY = pendingY * (1 - decay)
        var outX = pendingX * (1 - decay)
        pendingY -= outY
        pendingX -= outX
        if abs(pendingY) < 0.5, abs(pendingX) < 0.5 {
            outY += pendingY
            outX += pendingX
            pendingY = 0
            pendingX = 0
            timer?.invalidate()
            timer = nil
        }
        post(y: outY, x: outX)
    }

    private func post(y: Double, x: Double) {
        let iy = Int32(y.rounded())
        let ix = Int32(x.rounded())
        pendingY += y - Double(iy)
        pendingX += x - Double(ix)
        guard iy != 0 || ix != 0 else { return }
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: iy,
            wheel2: ix,
            wheel3: 0
        ) else { return }
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        event.post(tap: .cgSessionEventTap)
    }
}
