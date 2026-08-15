//
//  TokenVerdictStore.swift
//
//
//  Created by Vineet Choudhary on 13/07/26.
//

import Vapor

/// Bounded, self-sweeping TTL cache for Dropbox token verdicts.
actor TokenVerdictStore {
	struct Verdict {
		let verified: Bool
		let accountID: String?
	}

	private struct Entry {
		let verdict: Verdict
		let expiresAt: Date
	}

	private let maxEntries: Int
	private let sweepInterval: TimeInterval
	private var entries: [String: Entry] = [:]
	private var lastSweep = Date()

	init(maxEntries: Int = 10_000, sweepInterval: TimeInterval = 60) {
		self.maxEntries = maxEntries
		self.sweepInterval = sweepInterval
	}

	func verdict(for key: String) -> Verdict? {
		guard let entry = entries[key] else { return nil }
		guard entry.expiresAt > Date() else {
			entries.removeValue(forKey: key)
			return nil
		}
		return entry.verdict
	}

	func store(_ verdict: Verdict, for key: String, ttl: TimeInterval) {
		sweepIfNeeded()
		if entries.count >= maxEntries, entries[key] == nil {
			if let victim = entries.min(by: { $0.value.expiresAt < $1.value.expiresAt }) {
				entries.removeValue(forKey: victim.key)
			}
		}
		entries[key] = Entry(verdict: verdict, expiresAt: Date().addingTimeInterval(ttl))
	}

	func entryCount() -> Int {
		entries.count
	}

	/// Drop expired entries periodically so keys that are never read again can't accumulate.
	private func sweepIfNeeded() {
		let now = Date()
		guard now.timeIntervalSince(lastSweep) >= sweepInterval else { return }
		lastSweep = now
		entries = entries.filter { $0.value.expiresAt > now }
	}
}

extension Application {
	private struct TokenVerdictStoreKey: StorageKey, LockKey {
		typealias Value = TokenVerdictStore
	}

	/// One verdict store per application, lazily created under a lock.
	var dropboxTokenVerdicts: TokenVerdictStore {
		let lock = locks.lock(for: TokenVerdictStoreKey.self)
		lock.lock()
		defer { lock.unlock() }
		if let existing = storage[TokenVerdictStoreKey.self] {
			return existing
		}
		let store = TokenVerdictStore()
		storage[TokenVerdictStoreKey.self] = store
		return store
	}
}
