import Foundation

/// In-memory LRU cache with a hard capacity and per-entry TTL.
/// Used for place details, reverse-geocode labels, and identical O/D routes — never unbounded.
final class BoundedTTLCache<Key: Hashable, Value>: @unchecked Sendable {
    private struct Entry {
        var value: Value
        var expiresAt: Date
    }

    private let lock = NSLock()
    private let capacity: Int
    private let ttl: TimeInterval
    private var storage: [Key: Entry] = [:]
    private var order: [Key] = []

    /// - Parameters:
    ///   - capacity: Maximum retained entries (oldest access evicted first).
    ///   - ttl: Seconds until an entry is treated as a miss.
    init(capacity: Int, ttl: TimeInterval) {
        self.capacity = max(1, capacity)
        self.ttl = max(1, ttl)
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    func value(for key: Key, now: Date = Date()) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = storage[key] else { return nil }
        guard entry.expiresAt > now else {
            storage.removeValue(forKey: key)
            order.removeAll { $0 == key }
            return nil
        }
        touchLocked(key)
        return entry.value
    }

    func set(_ value: Value, for key: Key, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = Entry(value: value, expiresAt: now.addingTimeInterval(ttl))
        touchLocked(key)
        while order.count > capacity {
            let evicted = order.removeFirst()
            storage.removeValue(forKey: evicted)
        }
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll(keepingCapacity: false)
        order.removeAll(keepingCapacity: false)
    }

    private func touchLocked(_ key: Key) {
        order.removeAll { $0 == key }
        order.append(key)
    }
}
