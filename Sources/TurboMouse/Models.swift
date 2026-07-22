import Foundation

let macDefaultPointerAcceleration = 0.6875
let macDefaultScrollAcceleration = 0.3125
let basePointerResolution = 400.0

struct PointerDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let isMouse: Bool
}

struct DeviceConfig: Codable, Equatable {
    var managed = false
    var pointerDisabled = false
    var pointerAcceleration = macDefaultPointerAcceleration
    var pointerSpeed = 1.0
    var scrollDisabled = false
    var scrollAcceleration = macDefaultScrollAcceleration
    var pointerBaseline = macDefaultPointerAcceleration
    var scrollBaseline = macDefaultScrollAcceleration
    var windowsMode = false
    var windowsNotch = 6
    var calibratedGain: Double?
    var smoothScrolling = false
    var scrollStep = 40.0
    var scrollDuration = 0.25

    static let windowsMultipliers = [0.03125, 0.0625, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]

    var windowsMultiplier: Double {
        Self.windowsMultipliers[max(1, min(11, windowsNotch)) - 1]
    }

    struct Effective {
        var pointerDisabled: Bool
        var pointerAcceleration: Double
        var pointerSpeed: Double
        var scrollDisabled: Bool
        var scrollAcceleration: Double
    }

    var effective: Effective {
        if windowsMode {
            return Effective(
                pointerDisabled: false,
                pointerAcceleration: 0,
                pointerSpeed: windowsMultiplier / (calibratedGain ?? 1),
                scrollDisabled: true,
                scrollAcceleration: scrollBaseline
            )
        }
        return Effective(
            pointerDisabled: pointerDisabled,
            pointerAcceleration: pointerAcceleration,
            pointerSpeed: pointerSpeed,
            scrollDisabled: scrollDisabled,
            scrollAcceleration: scrollAcceleration
        )
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        managed = try c.decodeIfPresent(Bool.self, forKey: .managed) ?? false
        pointerDisabled = try c.decodeIfPresent(Bool.self, forKey: .pointerDisabled) ?? false
        pointerAcceleration = try c.decodeIfPresent(Double.self, forKey: .pointerAcceleration) ?? macDefaultPointerAcceleration
        pointerSpeed = try c.decodeIfPresent(Double.self, forKey: .pointerSpeed) ?? 1
        scrollDisabled = try c.decodeIfPresent(Bool.self, forKey: .scrollDisabled) ?? false
        scrollAcceleration = try c.decodeIfPresent(Double.self, forKey: .scrollAcceleration) ?? macDefaultScrollAcceleration
        pointerBaseline = try c.decodeIfPresent(Double.self, forKey: .pointerBaseline) ?? macDefaultPointerAcceleration
        scrollBaseline = try c.decodeIfPresent(Double.self, forKey: .scrollBaseline) ?? macDefaultScrollAcceleration
        windowsMode = try c.decodeIfPresent(Bool.self, forKey: .windowsMode) ?? false
        windowsNotch = try c.decodeIfPresent(Int.self, forKey: .windowsNotch) ?? 6
        calibratedGain = try c.decodeIfPresent(Double.self, forKey: .calibratedGain)
        smoothScrolling = try c.decodeIfPresent(Bool.self, forKey: .smoothScrolling) ?? false
        scrollStep = try c.decodeIfPresent(Double.self, forKey: .scrollStep) ?? 40
        scrollDuration = try c.decodeIfPresent(Double.self, forKey: .scrollDuration) ?? 0.25
    }

    private enum CodingKeys: String, CodingKey {
        case managed
        case pointerDisabled
        case pointerAcceleration
        case pointerSpeed
        case scrollDisabled
        case scrollAcceleration
        case pointerBaseline
        case scrollBaseline
        case windowsMode
        case windowsNotch
        case calibratedGain
        case smoothScrolling
        case scrollStep
        case scrollDuration
    }
}
