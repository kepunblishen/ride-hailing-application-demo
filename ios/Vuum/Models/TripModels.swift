import CoreLocation
import Foundation

enum TripPhase: String, Equatable {
    case idle
    case selectingDestination
    case choosingRide
    case searching
    /// Driver assigned; brief beat before approach motion starts.
    case matched
    /// Driver moving toward pickup (“arriving”).
    case driverEnRoute
    case driverArrived
    case inTrip
    case completed
}

/// Pickup-fleet class used for ETA, map icons, and approach simulation.
enum VehicleClass: String, Equatable, Hashable, Codable {
    case bike
    case standard
    case large

    var systemImage: String {
        switch self {
        case .bike: return "bicycle"
        case .standard: return "car.fill"
        case .large: return "car.2.fill"
        }
    }

    /// Resolves product / fare tier IDs or display names to a fleet class.
    static func resolving(tierID: String) -> VehicleClass {
        let id = tierID.lowercased()
        if id.contains("two-wheel") || id.contains("bike") || id.contains("moto") {
            return .bike
        }
        if id.contains("xxl")
            || id == "xl"
            || id.contains("executive")
            || id.contains("hourly")
            || id.contains("airport")
            || id.contains("group") {
            return .large
        }
        return .standard
    }
}

struct GeoPoint: Equatable, Hashable, Codable {
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct Place: Identifiable, Equatable, Hashable, Codable {
    let id: String
    var name: String
    var subtitle: String
    var coordinate: GeoPoint
}

enum SavedPlaceKind: String, Codable, CaseIterable, Identifiable {
    case home
    case work
    case favorite
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        case .favorite: return "Favorite"
        case .recent: return "Recent"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .favorite: return "star.fill"
        case .recent: return "clock.fill"
        }
    }
}

struct RideTier: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var detail: String
    var capacity: Int
    /// Expected minutes until a matched driver reaches pickup (vehicle-class based).
    var etaMinutes: Int
    /// Local major units (KES or CDF depending on market). Legacy name kept for Codable call sites.
    var priceCDF: Int
    var priceUSD: Double
    var systemImage: String
    var vehicleClass: VehicleClass

    var priceLabel: String {
        priceLabel(for: .drc)
    }

    func priceLabel(for market: AppLocale.Market) -> String {
        moneyPair(for: market).formatted
    }

    func moneyPair(for market: AppLocale.Market) -> MoneyPair {
        MoneyPair.fare(local: priceCDF, usd: priceUSD, market: market)
    }

    /// Approximate KSh from USD fare (presentation display).
    var priceKSh: Int {
        ExchangeRateConfiguration.presentation.localFromUSD(priceUSD, currency: .kes)
    }
}

enum VehicleInspectionStatus: String, Codable, Equatable, Hashable {
    case current
    case dueSoon
    case overdue

    var title: String {
        switch self {
        case .current: return "Inspection current"
        case .dueSoon: return "Inspection due soon"
        case .overdue: return "Inspection overdue"
        }
    }
}

struct DriverProfile: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var rating: Double
    /// Display string `Make Model · Colour` (parsed by driver card helpers).
    var vehicle: String
    var plate: String
    var tripsCompleted: Int
    /// E.164-style number used for in-trip Call Driver (`tel:`).
    var phone: String
    /// Optional Assets.xcassets image name; initials avatar used when nil (photo placeholder).
    var photoAssetName: String? = nil
    var vehicleClass: VehicleClass = .standard
    var yearsDriving: Int = 3
    /// Languages the driver can use in chat (product profile, not app UI locale).
    var languages: [String] = ["French", "English"]
    /// First chat line after match — keeps in-trip messaging voice consistent.
    var chatOpeningLine: String = ""
    /// Preferred short replies when the rider messages mid-trip.
    var chatReplyLines: [String] = []
    /// Short bio shared with the rider before pickup (VIP / reserved).
    var bio: String = ""
    /// Corporate / safety: background check cleared for platform dispatch.
    var backgroundCheckPassed: Bool = true
    /// Latest vehicle inspection status shown on the rider card.
    var vehicleInspection: VehicleInspectionStatus = .current

    var resolvedChatOpening: String {
        let trimmed = chatOpeningLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return "Hi, I'm on my way in a \(vehicle)."
    }

    var resolvedBio: String {
        let trimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let langs = languages.prefix(2).joined(separator: " · ")
        return "\(yearsDriving)+ years driving · \(tripsCompleted) trips · \(langs)"
    }
}

struct MapVehicle: Identifiable, Equatable {
    let id: String
    var coordinate: GeoPoint
    var heading: Double
    var vehicleClass: VehicleClass
}

struct FareBreakdown: Equatable, Hashable, Codable {
    /// Local major units (KES or CDF). `*CDF` names retained for stored receipts.
    var baseFareCDF: Int
    var distanceFareCDF: Int
    var timeFareCDF: Int
    var bookingFeeCDF: Int
    /// Waiting / stop time charge when applicable.
    var waitingFareCDF: Int
    /// Peak multiplier (1.0 = none). Shown separately from the total.
    var surgeMultiplier: Double
    /// Extra charged due to surge (explicit line — not buried in the total).
    var surgeFareCDF: Int
    var tollCDF: Int
    var serviceFeeCDF: Int
    var discountCDF: Int
    /// Reserved for markets that configure tax; usually 0.
    var taxCDF: Int
    /// Sum of fare components before discount / minimum-fare clamp.
    var subtotalCDF: Int
    var totalCDF: Int
    var totalUSD: Double
    var distanceKm: Double
    var durationMinutes: Int
    var minimumFareApplied: Bool

    var isSurgeActive: Bool { surgeMultiplier > 1.001 && surgeFareCDF > 0 }

    func primaryMoney(market: AppLocale.Market) -> Money {
        Money.local(totalCDF, market: market)
    }

    func secondaryMoney(market: AppLocale.Market) -> Money? {
        CurrencyCode.secondary(for: market == .kenya ? .kenya : .drc).map { _ in Money.usd(totalUSD) }
    }

    func moneyPair(market: AppLocale.Market) -> MoneyPair {
        MoneyPair.fare(local: totalCDF, usd: totalUSD, market: market)
    }

    func lineMoney(_ local: Int, market: AppLocale.Market) -> Money {
        Money.local(local, market: market)
    }

    init(
        baseFareCDF: Int,
        distanceFareCDF: Int,
        timeFareCDF: Int,
        bookingFeeCDF: Int,
        waitingFareCDF: Int = 0,
        surgeMultiplier: Double = 1.0,
        surgeFareCDF: Int = 0,
        tollCDF: Int = 0,
        serviceFeeCDF: Int = 0,
        discountCDF: Int = 0,
        taxCDF: Int = 0,
        subtotalCDF: Int? = nil,
        totalCDF: Int,
        totalUSD: Double,
        distanceKm: Double,
        durationMinutes: Int,
        minimumFareApplied: Bool = false
    ) {
        self.baseFareCDF = baseFareCDF
        self.distanceFareCDF = distanceFareCDF
        self.timeFareCDF = timeFareCDF
        self.bookingFeeCDF = bookingFeeCDF
        self.waitingFareCDF = waitingFareCDF
        self.surgeMultiplier = surgeMultiplier
        self.surgeFareCDF = surgeFareCDF
        self.tollCDF = tollCDF
        self.serviceFeeCDF = serviceFeeCDF
        self.discountCDF = discountCDF
        self.taxCDF = taxCDF
        self.subtotalCDF = subtotalCDF ?? (
            baseFareCDF + distanceFareCDF + timeFareCDF + bookingFeeCDF
                + waitingFareCDF + surgeFareCDF + tollCDF + serviceFeeCDF + taxCDF
        )
        self.totalCDF = totalCDF
        self.totalUSD = totalUSD
        self.distanceKm = distanceKm
        self.durationMinutes = durationMinutes
        self.minimumFareApplied = minimumFareApplied
    }
}

/// Configurable peak / zone demand state for fare recalculation.
struct SurgeState: Equatable, Hashable {
    var multiplier: Double
    var label: String
    /// Stable zone / demand bucket id (catalog zone id, city id, or peak bucket).
    var zoneId: String

    var isActive: Bool { multiplier > 1.001 }

    static let inactive = SurgeState(multiplier: 1.0, label: "", zoneId: "")
}

/// Rider-facing matching / connectivity UI for the search sheet.
enum MatchingStatus: String, Equatable {
    case idle
    case searching
    case delayed
    case retrying
    case noDrivers
}

/// Saved after a rider cancels a request or assigned trip.
struct CancellationRecord: Equatable, Identifiable {
    let id: String
    var reason: String
    var feeLocal: Int
    var wasFree: Bool
    var phaseRaw: String
    var at: Date

    var summaryLine: String {
        if wasFree || feeLocal <= 0 {
            return "Cancelled · \(reason) · No fee"
        }
        return "Cancelled · \(reason)"
    }
}

/// Local cancellation policy (admin-configurable later).
enum CancellationPolicy {
    /// Free cancel for this many seconds after driver assignment.
    static let freeWindowSeconds: TimeInterval = 60
    /// Free driver wait at pickup before waiting charges begin.
    static let pickupWaitGraceSeconds: Int = 90

    static func feeLocal(market: AppLocale.Market) -> Int {
        switch market {
        case .kenya: return 50
        case .drc, .both: return 1_500
        }
    }
}

enum PaymentMethod: String, CaseIterable, Identifiable, Codable {
    case cash = "Cash"
    case wallet = "Vuum Wallet"
    case mpesa = "M-Pesa"
    case airtelMoney = "Airtel Money"
    case orangeMoney = "Orange Money"
    case card = "Card"
    case companyWallet = "Company"

    var id: String { rawValue }
    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .cash: return "banknote"
        case .wallet: return "wallet.pass.fill"
        case .mpesa, .airtelMoney, .orangeMoney: return "iphone"
        case .card: return "creditcard"
        case .companyWallet: return "briefcase.fill"
        }
    }

    var isMobileMoney: Bool {
        switch self {
        case .mpesa, .airtelMoney, .orangeMoney: return true
        case .cash, .wallet, .card, .companyWallet: return false
        }
    }
}

/// Lifecycle for a rider payment (adapter-ready; local providers fill these today).
enum PaymentTransactionStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case processing
    case successful
    case failed
    case cancelled
    case refunded
    case partiallyRefunded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .successful: return "Successful"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .refunded: return "Refunded"
        case .partiallyRefunded: return "Partially refunded"
        }
    }
}

enum PaymentCurrency: String, Codable, CaseIterable, Identifiable {
    case ksh = "KSh"
    case cdf = "CDF"
    case usd = "USD"

    var id: String { rawValue }
}

enum PaymentLedgerKind: String, Codable {
    case tripCharge
    case walletTopUp
    case refund
    case promoCredit
}

struct PaymentTransaction: Identifiable, Equatable, Codable, Hashable {
    let id: String
    var date: Date
    var kind: PaymentLedgerKind
    var tripId: String?
    var tripLabel: String
    var amountLocal: Int
    var amountUSD: Double
    var currency: PaymentCurrency
    var method: PaymentMethod
    var status: PaymentTransactionStatus
    var refundNote: String?
    var receiptId: String?

    var amountDisplay: String {
        switch currency {
        case .ksh: return Money.local(amountLocal, currency: .kes).formatted
        case .cdf: return Money.local(amountLocal, currency: .cdf).formatted
        case .usd: return Money.usd(amountUSD).formatted
        }
    }

    var signedAmountDisplay: String {
        let prefix: String
        switch kind {
        case .walletTopUp, .promoCredit, .refund:
            prefix = "+"
        case .tripCharge:
            prefix = "−"
        }
        return prefix + amountDisplay
    }
}

struct CorporateAccount: Equatable {
    var companyName: String
    var department: String
    var employeeRole: String
    var employeeId: String
    var costCentre: String
    var monthlySpendLimitCDF: Int
    var spentThisMonthCDF: Int
    var companyWalletBalanceCDF: Int
    var transportAllowanceCDF: Int
    var sosContactName: String
    var sosContactPhone: String
    var corporateSupportPhone: String
    var vipTransferEnabled: Bool
    var meetAndGreetDefault: Bool

    var remainingSpendCDF: Int {
        max(monthlySpendLimitCDF - spentThisMonthCDF, 0)
    }

    var remainingAllowanceCDF: Int {
        min(remainingSpendCDF, max(transportAllowanceCDF - spentThisMonthCDF, 0))
    }

    func canCoverFare(cdf: Int) -> Bool {
        cdf > 0 && cdf <= remainingSpendCDF && cdf <= companyWalletBalanceCDF
    }
}

struct CorporateTripRecord: Identifiable, Equatable {
    let id: String
    var date: Date
    var pickupName: String
    var dropoffName: String
    var tierName: String
    var purpose: String
    var costCentre: String
    var totalCDF: Int
    var billedToCompany: Bool
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    var sender: String
    var text: String
    var isRider: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        sender: String,
        text: String,
        isRider: Bool,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.isRider = isRider
        self.createdAt = createdAt
    }
}

/// Rider extras applied at booking (quiet cabin, accessibility notes for the driver).
struct RidePreferences: Equatable, Hashable, Codable {
    var quietRide: Bool = false
    var accessibilityNotes: String = ""

    var hasContent: Bool {
        quietRide || !accessibilityNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var summaryLine: String? {
        var parts: [String] = []
        if quietRide { parts.append("Quiet ride") }
        let notes = accessibilityNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { parts.append(notes) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

enum ReservedTripStatus: String, Codable, Equatable {
    case confirmed
    case reminderSet
    case driverAssigned

    var title: String {
        switch self {
        case .confirmed: return "Confirmed"
        case .reminderSet: return "Reminder on"
        case .driverAssigned: return "Driver assigned"
        }
    }
}

struct ActiveTrip: Equatable {
    /// Stable trip identifier for share links, SOS, and incident reports.
    var id: String
    var pickup: Place
    var dropoff: Place
    /// Intermediate stops between pickup and dropoff (max 2 on the rider client).
    var stops: [Place]
    var tier: RideTier
    var driver: DriverProfile
    var fare: FareBreakdown
    var driverCoordinate: GeoPoint
    var driverHeading: Double
    var pickupRoute: [GeoPoint]
    var tripRoute: [GeoPoint]
    /// Booked trip-route duration from `RouteEngine` (traffic-aware when live). Used for in-trip ETA.
    /// Zero means fall back to class speed for remaining distance.
    var routeDurationSeconds: TimeInterval = 0
    var etaMinutes: Int
    var distanceRemainingMeters: Double
    var statusHeadline: String
    var statusDetail: String
    var tripPIN: String
    var paymentMethod: PaymentMethod
    var passengerName: String?
    var promoCode: String?
    var preferences: RidePreferences
    /// When non-nil, the vehicle is paused at `stops[index]` (waiting charge applies).
    var waitingAtStopIndex: Int? = nil
}

struct ReservedTrip: Identifiable, Equatable, Codable, Hashable {
    let id: String
    var pickupName: String
    var dropoffName: String
    var stopNames: [String]
    var tierName: String
    var when: Date
    var priceCDF: Int
    var priceUSD: Double
    var paymentMethod: PaymentMethod
    var status: ReservedTripStatus
    var confirmationCode: String
    var reminderEnabled: Bool
    var preferences: RidePreferences
    var promoCode: String?
    var passengerName: String?
    var assignedDriverName: String?
    var assignedVehicle: String?
    var assignedPlate: String?

    init(
        id: String,
        pickupName: String,
        dropoffName: String,
        stopNames: [String] = [],
        tierName: String,
        when: Date,
        priceCDF: Int,
        priceUSD: Double,
        paymentMethod: PaymentMethod = .cash,
        status: ReservedTripStatus = .confirmed,
        confirmationCode: String = "",
        reminderEnabled: Bool = true,
        preferences: RidePreferences = RidePreferences(),
        promoCode: String? = nil,
        passengerName: String? = nil,
        assignedDriverName: String? = nil,
        assignedVehicle: String? = nil,
        assignedPlate: String? = nil
    ) {
        self.id = id
        self.pickupName = pickupName
        self.dropoffName = dropoffName
        self.stopNames = stopNames
        self.tierName = tierName
        self.when = when
        self.priceCDF = priceCDF
        self.priceUSD = priceUSD
        self.paymentMethod = paymentMethod
        self.status = status
        self.confirmationCode = confirmationCode.isEmpty
            ? String(UUID().uuidString.prefix(8)).uppercased()
            : confirmationCode
        self.reminderEnabled = reminderEnabled
        self.preferences = preferences
        self.promoCode = promoCode
        self.passengerName = passengerName
        self.assignedDriverName = assignedDriverName
        self.assignedVehicle = assignedVehicle
        self.assignedPlate = assignedPlate
    }

    var statusDetailLine: String {
        if status == .driverAssigned, let name = assignedDriverName {
            let vehicle = [assignedVehicle, assignedPlate].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            return vehicle.isEmpty ? "\(name) assigned" : "\(name) · \(vehicle)"
        }
        if reminderEnabled {
            return "We'll remind you before pickup"
        }
        return status.title
    }
}

enum TripReceiptStatus: String, Codable, Hashable, CaseIterable {
    case completed
    case cancelled

    var title: String {
        switch self {
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

struct TripReceipt: Identifiable, Equatable, Hashable, Codable {
    let id: String
    var date: Date
    var pickupName: String
    var dropoffName: String
    var stopNames: [String]
    var driverName: String
    var vehicle: String
    var plate: String
    var tierName: String
    var paymentMethod: PaymentMethod
    var status: TripReceiptStatus
    var fare: FareBreakdown
    /// Tip added after the trip (not part of the booked fare).
    var tipCDF: Int
    var rating: Int?
    /// Optional post-trip feedback note from the rider.
    var feedbackNote: String?
    /// Optional quick-feedback tags selected with the star rating.
    var feedbackTags: [String]
    var cancelReason: String?

    /// Fare total plus tip — what Activity / share copy should show as charged.
    var chargedTotalCDF: Int { fare.totalCDF + max(tipCDF, 0) }

    var chargedTotalUSD: Double {
        let tip = max(tipCDF, 0)
        guard tip > 0 else { return fare.totalUSD }
        guard fare.totalCDF > 0 else { return fare.totalUSD }
        return fare.totalUSD * (Double(fare.totalCDF + tip) / Double(fare.totalCDF))
    }

    var vehicleLabel: String {
        let name = vehicle.trimmingCharacters(in: .whitespacesAndNewlines)
        let plateText = plate.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty, plateText.isEmpty { return "" }
        if name.isEmpty { return plateText }
        if plateText.isEmpty { return name }
        return "\(name) · \(plateText)"
    }

    init(
        id: String,
        date: Date,
        pickupName: String,
        dropoffName: String,
        stopNames: [String] = [],
        driverName: String,
        vehicle: String = "",
        plate: String = "",
        tierName: String,
        paymentMethod: PaymentMethod = .cash,
        status: TripReceiptStatus = .completed,
        fare: FareBreakdown,
        tipCDF: Int = 0,
        rating: Int? = nil,
        feedbackNote: String? = nil,
        feedbackTags: [String] = [],
        cancelReason: String? = nil
    ) {
        self.id = id
        self.date = date
        self.pickupName = pickupName
        self.dropoffName = dropoffName
        self.stopNames = stopNames
        self.driverName = driverName
        self.vehicle = vehicle
        self.plate = plate
        self.tierName = tierName
        self.paymentMethod = paymentMethod
        self.status = status
        self.fare = fare
        self.tipCDF = tipCDF
        self.rating = rating
        self.feedbackNote = feedbackNote
        self.feedbackTags = feedbackTags
        self.cancelReason = cancelReason
    }
}

/// Shared tip presets and feedback chips for the post-trip screen.
enum PostTripFeedback {
    static func tipPresets(market: AppLocale.Market) -> [Int] {
        switch market {
        case .kenya:
            return [0, 50, 100, 200]
        case .drc, .both:
            return [0, 500, 1_000, 2_000]
        }
    }

    static func tags(for rating: Int) -> [String] {
        if rating >= 4 {
            return ["Clean car", "Safe driving", "Friendly", "On time", "Great route"]
        }
        if rating <= 2 {
            return ["Late arrival", "Rough driving", "Dirty car", "Wrong route", "Unprofessional"]
        }
        return ["Okay ride", "Could improve", "Fine overall"]
    }
}

enum MapPinKind: Equatable {
    case pickup
    case dropoff
    /// Intermediate waypoint between pickup and dropoff.
    case stop
    case driver
    case nearby
}

struct MapPin: Identifiable, Equatable {
    let id: String
    var coordinate: GeoPoint
    var kind: MapPinKind
    var heading: Double
    /// Optional fleet class so Maps can pick car vs bike glyphs without reading trip state.
    var vehicleClass: VehicleClass?

    init(
        id: String,
        coordinate: GeoPoint,
        kind: MapPinKind,
        heading: Double,
        vehicleClass: VehicleClass? = nil
    ) {
        self.id = id
        self.coordinate = coordinate
        self.kind = kind
        self.heading = heading
        self.vehicleClass = vehicleClass
    }
}
