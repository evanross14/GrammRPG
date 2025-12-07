import Foundation
import SwiftUI
import Combine

/// An observable object that manages gold/coins with safe add and spend operations.
@MainActor
final class GoldModel: ObservableObject {
    /// The current amount of coins, always zero or positive.
    @Published private(set) var coins: Int

    /// Creates a new GoldModel with an optional initial number of coins.
    /// - Parameter initialCoins: The starting number of coins. Defaults to 0. Negative values are clamped to 0.
    init(initialCoins: Int = 0) {
        self.coins = max(0, initialCoins)
    }

    /// Sets the coin count to a specific value, clamping it to zero or more.
    /// - Parameter value: The new coin value.
    func set(_ value: Int) {
        coins = max(0, value)
    }

    /// Adds the specified amount of coins. Negative amounts reduce coins but never below zero.
    /// - Parameter amount: The number of coins to add (or remove if negative).
    func add(_ amount: Int) {
        guard amount != 0 else { return }
        let newValue = coins + amount
        coins = max(0, newValue)
    }

    /// Attempts to spend the specified amount of coins.
    /// - Parameter amount: The number of coins to spend.
    /// - Returns: True if the spend was successful, false if there were insufficient coins.
    @discardableResult
    func spend(_ amount: Int) -> Bool {
        guard amount > 0 else { return true }
        if coins >= amount {
            coins -= amount
            return true
        } else {
            return false
        }
    }
}

