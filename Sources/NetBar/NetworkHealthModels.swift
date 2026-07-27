enum NetworkHealthState: String, Equatable {
    case good
    case offline
}

enum NetworkHealthTone: Equatable {
    case normal
    case critical
}

struct NetworkHealthSnapshot: Equatable {
    var state: NetworkHealthState

    static func localInterface(isAvailable: Bool) -> NetworkHealthSnapshot {
        NetworkHealthSnapshot(state: isAvailable ? .good : .offline)
    }
}
