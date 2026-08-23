import Foundation

/// Rough trip CO₂ estimate for rider receipts (RFQ Module 2 / R05).
enum TripEmissions {
    /// Grams CO₂ per km by vehicle class (presentation factors).
    static func gramsPerKm(for vehicleClass: VehicleClass) -> Double {
        switch vehicleClass {
        case .bike: return 45
        case .standard: return 160
        case .large: return 220
        }
    }

    static func kilograms(distanceKm: Double, vehicleClass: VehicleClass) -> Double {
        let kg = (max(0, distanceKm) * gramsPerKm(for: vehicleClass)) / 1_000
        return (kg * 100).rounded() / 100
    }

    static func displayLabel(distanceKm: Double, vehicleClass: VehicleClass) -> String {
        let kg = kilograms(distanceKm: distanceKm, vehicleClass: vehicleClass)
        if kg < 0.1 {
            let grams = Int((kg * 1_000).rounded())
            return "~\(grams) g CO₂"
        }
        return String(format: "~%.2f kg CO₂", kg)
    }
}
