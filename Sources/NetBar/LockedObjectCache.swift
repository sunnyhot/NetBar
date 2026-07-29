import Foundation

/// A small synchronous wrapper around `NSCache` that makes the cache's
/// cross-thread access explicit to Swift's strict concurrency checker.
final class LockedObjectCache<Key: AnyObject, Value: AnyObject>: @unchecked Sendable {
    private let lock = NSLock()
    private let cache = NSCache<Key, Value>()

    func object(forKey key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return cache.object(forKey: key)
    }

    func setObject(_ object: Value, forKey key: Key) {
        lock.lock()
        defer { lock.unlock() }
        cache.setObject(object, forKey: key)
    }

    func removeAllObjects() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAllObjects()
    }
}

/// Lock-isolated storage for small synchronous values used from detached
/// sampling tasks.
final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withValue<Result>(_ body: (Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(value)
    }

    func set(_ newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }

    func mutate<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
