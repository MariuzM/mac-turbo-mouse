import CoreGraphics
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
    var pointerResolutionBaseline = basePointerResolution
    var smoothScrolling = false
    var scrollStep = 40.0
    var scrollDuration = 0.25
    var horizontalScrollModifier = "none"

    var horizontalModifierFlags: CGEventFlags? {
        switch horizontalScrollModifier {
        case "shift": return .maskShift
        case "control": return .maskControl
        case "option": return .maskAlternate
        case "command": return .maskCommand
        default: return nil
        }
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
        pointerResolutionBaseline = try c.decodeIfPresent(Double.self, forKey: .pointerResolutionBaseline) ?? basePointerResolution
        smoothScrolling = try c.decodeIfPresent(Bool.self, forKey: .smoothScrolling) ?? false
        scrollStep = try c.decodeIfPresent(Double.self, forKey: .scrollStep) ?? 40
        scrollDuration = try c.decodeIfPresent(Double.self, forKey: .scrollDuration) ?? 0.25
        horizontalScrollModifier = try c.decodeIfPresent(String.self, forKey: .horizontalScrollModifier) ?? "none"
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
        case pointerResolutionBaseline
        case smoothScrolling
        case scrollStep
        case scrollDuration
        case horizontalScrollModifier
    }
}
