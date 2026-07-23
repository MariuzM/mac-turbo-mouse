import CHID
import Foundation

struct HIDService {
    let ref: OpaquePointer
    let key: String
    let name: String
    let isMouse: Bool
    let pointerKey: String
    let scrollKey: String
}

final class HIDClient {
    private(set) var services: [HIDService] = []

    private var client: OpaquePointer?
    private var retainedArray: CFArray?
    private let fixedOne = 65536.0

    deinit {
        if let client { CHIDReleaseClient(client) }
    }

    func refresh() {
        let newClient = IOHIDEventSystemClientCreateWithType(kCFAllocatorDefault, 2, nil)
        guard let newClient, let array = IOHIDEventSystemClientCopyServices(newClient) else {
            if let newClient { CHIDReleaseClient(newClient) }
            return
        }
        var found: [HIDService] = []
        for i in 0..<CFArrayGetCount(array) {
            guard let raw = CFArrayGetValueAtIndex(array, i) else { continue }
            let ref = OpaquePointer(raw)
            guard IOHIDServiceClientConformsTo(ref, 1, 2) != 0, isMouse(ref) else { continue }
            let pointerKey = readString(ref, "HIDPointerAccelerationType") ?? "HIDMouseAcceleration"
            let scrollKey = readString(ref, "HIDScrollAccelerationType") ?? "HIDMouseScrollAcceleration"
            guard readFixed(ref, pointerKey) != nil,
                  let vendor = readInt(ref, "VendorID"),
                  let product = readInt(ref, "ProductID")
            else { continue }
            found.append(
                HIDService(
                    ref: ref,
                    key: "\(vendor):\(product)",
                    name: readString(ref, "Product") ?? "Pointer Device",
                    isMouse: true,
                    pointerKey: pointerKey,
                    scrollKey: scrollKey
                )
            )
        }
        let oldClient = client
        client = newClient
        retainedArray = array
        services = found
        if let oldClient { CHIDReleaseClient(oldClient) }
    }

    func forEach(key: String? = nil, _ body: (HIDService) -> Void) {
        for s in services where key == nil || s.key == key {
            body(s)
        }
    }

    func readFixed(_ ref: OpaquePointer, _ key: String) -> Double? {
        guard let raw = readInt(ref, key) else { return nil }
        return Double(raw) / fixedOne
    }

    func writeFixed(_ ref: OpaquePointer, _ key: String, _ value: Double) {
        let fixed = Int64((value * fixedOne).rounded())
        IOHIDServiceClientSetProperty(ref, key as CFString, fixed as CFNumber)
    }

    private func readInt(_ ref: OpaquePointer, _ key: String) -> Int64? {
        guard let value = IOHIDServiceClientCopyProperty(ref, key as CFString),
              CFGetTypeID(value) == CFNumberGetTypeID()
        else { return nil }
        var raw: Int64 = 0
        CFNumberGetValue((value as! CFNumber), .sInt64Type, &raw)
        return raw
    }

    private func readString(_ ref: OpaquePointer, _ key: String) -> String? {
        guard let value = IOHIDServiceClientCopyProperty(ref, key as CFString),
              CFGetTypeID(value) == CFStringGetTypeID()
        else { return nil }
        return (value as! CFString) as String
    }

    private func isMouse(_ ref: OpaquePointer) -> Bool {
        guard let value = IOHIDServiceClientCopyProperty(ref, "DeviceUsagePairs" as CFString),
              CFGetTypeID(value) == CFArrayGetTypeID(),
              let pairs = (value as! CFArray) as? [[String: Int]]
        else { return true }
        for pair in pairs {
            let page = pair["DeviceUsagePage"] ?? 0
            let usage = pair["DeviceUsage"] ?? 0
            if !(page == 1 && (usage == 1 || usage == 2)) { return false }
        }
        return true
    }
}
