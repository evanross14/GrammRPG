import Foundation
import Combine
import SwiftUI

final class HealthModel: ObservableObject {
    @Published var current: Int
    @Published var total: Int

    init(current: Int = 100, total: Int = 100) {
        self.current = max(0, current)
        self.total = max(1, total)
        self.current = min(self.current, self.total)
    }

    func applyDamage(_ amount: Int) {
        guard amount > 0 else { return }
        current = max(0, current - amount)
    }

    func heal(_ amount: Int) {
        guard amount > 0 else { return }
        current = min(total, current + amount)
    }

    func setTotal(_ newTotal: Int, preservePercentage: Bool = false) {
        let clamped = max(1, newTotal)
        if preservePercentage, total > 0 {
            let percent = Double(current) / Double(total)
            total = clamped
            current = max(0, min(total, Int(round(percent * Double(total)))))
        } else {
            total = clamped
            current = min(current, total)
        }
    }
}
