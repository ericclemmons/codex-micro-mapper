import Foundation
import IOKit.hid

final class HIDListener {
    static let vendorID = 12346
    static let productID = 33632

    var onConnectionChanged: ((Bool) -> Void)?
    var onAction: ((HIDAction) -> Void)?

    private let manager: IOHIDManager
    private var reportBuffers: [IOHIDDevice: UnsafeMutablePointer<UInt8>] = [:]

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    deinit {
        stop()
    }

    func start() -> IOReturn {
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: Self.vendorID,
            kIOHIDProductIDKey as String: Self.productID,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<HIDListener>.fromOpaque(context).takeUnretainedValue().connected(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<HIDListener>.fromOpaque(context).takeUnretainedValue().disconnected(device)
        }, context)

        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue
        )
        return IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func stop() {
        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue
        )
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        for buffer in reportBuffers.values {
            buffer.deallocate()
        }
        reportBuffers.removeAll()
    }

    private func connected(_ device: IOHIDDevice) {
        guard reportBuffers[device] == nil else { return }
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        buffer.initialize(repeating: 0, count: 64)
        reportBuffers[device] = buffer

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            device,
            buffer,
            64,
            { context, _, _, _, reportID, report, reportLength in
                guard let context, reportID == 6 else { return }
                let listener = Unmanaged<HIDListener>.fromOpaque(context).takeUnretainedValue()
                let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
                guard let action = HIDPayloadParser.parse(report: bytes) else { return }
                DispatchQueue.main.async {
                    listener.onAction?(action)
                }
            },
            context
        )

        DispatchQueue.main.async { [weak self] in
            self?.onConnectionChanged?(true)
        }
    }

    private func disconnected(_ device: IOHIDDevice) {
        if let buffer = reportBuffers.removeValue(forKey: device) {
            buffer.deallocate()
        }
        let remainsConnected = !reportBuffers.isEmpty
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionChanged?(remainsConnected)
        }
    }
}
