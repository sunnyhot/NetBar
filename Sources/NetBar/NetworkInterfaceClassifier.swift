import Foundation

enum NetworkInterfaceClassifier {
    static func countsTowardExternalTrafficTotals(_ interfaceName: String) -> Bool {
        let name = interfaceName.lowercased()
        let virtualPrefixes = [
            "lo",
            "utun",
            "tun",
            "tap",
            "ipsec",
            "bridge",
            "awdl",
            "llw",
            "p2p",
            "gif",
            "stf",
            "vmnet",
            "vmenet"
        ]

        return !virtualPrefixes.contains { name.hasPrefix($0) }
    }
}
