import Foundation
import SystemConfiguration

protocol NetworkStatsReading {
    func readInterfaces() -> [InterfaceStats]
}

final class SystemNetworkStatsReader: NetworkStatsReading {
    func readInterfaces() -> [InterfaceStats] {
        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0, let firstAddress = addressList else {
            return []
        }
        defer { freeifaddrs(addressList) }

        let primaryInterface = Self.primaryInterfaceName()
        var statsByName: [String: InterfaceStats] = [:]

        for pointer in sequence(first: firstAddress, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)

            guard
                (flags & IFF_UP) != 0,
                (flags & IFF_LOOPBACK) == 0,
                interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
                let dataPointer = interface.ifa_data
            else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            guard !name.isEmpty else { continue }

            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            let receivedBytes = UInt64(data.ifi_ibytes)
            let sentBytes = UInt64(data.ifi_obytes)
            let receivedPackets = UInt64(data.ifi_ipackets)
            let sentPackets = UInt64(data.ifi_opackets)

            statsByName[name] = InterfaceStats(
                name: name,
                displayName: Self.displayName(for: name),
                receivedBytes: receivedBytes,
                sentBytes: sentBytes,
                receivedPackets: receivedPackets,
                sentPackets: sentPackets,
                isPrimary: name == primaryInterface
            )
        }

        return statsByName.values.sorted { lhs, rhs in
            if lhs.isPrimary != rhs.isPrimary {
                return lhs.isPrimary && !rhs.isPrimary
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private static var cachedPrimaryInterface: (name: String?, fetchedAt: Date)?
    private static let primaryInterfaceCacheTTL: TimeInterval = 30

    private static func primaryInterfaceName() -> String? {
        let now = Date()
        if let cached = cachedPrimaryInterface, now.timeIntervalSince(cached.fetchedAt) < primaryInterfaceCacheTTL {
            return cached.name
        }

        let name: String? = {
            guard
                let store = SCDynamicStoreCreate(nil, "NetBar" as CFString, nil, nil),
                let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
                let primary = value["PrimaryInterface"] as? String
            else {
                return nil
            }
            return primary
        }()

        cachedPrimaryInterface = (name: name, fetchedAt: now)
        return name
    }

    private static func displayName(for interfaceName: String) -> String {
        if interfaceName.hasPrefix("en") {
            return interfaceName == "en0" ? "Wi-Fi / en0" : "Ethernet / \(interfaceName)"
        }
        if interfaceName.hasPrefix("utun") {
            return "VPN / \(interfaceName)"
        }
        if interfaceName.hasPrefix("bridge") {
            return "Bridge / \(interfaceName)"
        }
        if interfaceName.hasPrefix("awdl") {
            return "AirDrop / \(interfaceName)"
        }
        if interfaceName.hasPrefix("llw") {
            return "Low Latency Wi-Fi / \(interfaceName)"
        }
        return interfaceName
    }
}
