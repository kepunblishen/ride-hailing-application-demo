import Combine
import CoreLocation
import Foundation
import SwiftUI

@MainActor
final class TripSession: ObservableObject {
    static let maxStops = 2
    /// Included wait minutes charged per intermediate stop (matches MockFares / RFQ waiting).
    static let waitMinutesPerStop = 3
    /// Compressed wall-clock pause at each stop during in-trip simulation.
    static let waitSimulationSeconds: TimeInterval = 5

    @Published private(set) var phase: TripPhase = .idle
    @Published private(set) var pickup: Place = MockPlaces.defaultCenter(for: AppLocale.current)
    @Published private(set) var dropoff: Place?
    /// Intermediate stops between pickup and dropoff (max `maxStops`).
    @Published private(set) var stops: [Place] = []
    @Published private(set) var isAddingStop = false
    @Published private(set) var selectedTier: RideTier?
    @Published private(set) var availableTiers: [RideTier] = MockFares.tiers
    /// Bumped by Home “recenter” so `VuumMapView` re-animates to pickup / GPS.
    @Published private(set) var mapCameraFocusNonce: Int = 0
    /// True while an in-trip destination change is fetching / applying a new route.
    @Published private(set) var isRecalculatingTripRoute = false
    /// Short rider-facing note after a mid-trip destination update (fare / ETA).
    @Published private(set) var destinationChangeNotice: String?
    /// Subtle safety notice when the vehicle stays outside the planned route corridor.
    @Published private(set) var routeDeviationNotice: String?
    /// Latest distance from the vehicle to the expected trip polyline (meters).
    @Published private(set) var routeDeviationDistanceMeters: Double = 0
    /// Optional tier preference from Home / Services product shortcuts (applied after destination).
    private var preferredTierID: String?
    /// Product-sheet inject (2-Wheels, Courier, Hourly, Airport) retained across fare refreshes.
    private var stickyInjectTierID: String?
    @Published private(set) var activeTrip: ActiveTrip?
    @Published private(set) var nearbyVehicles: [MapVehicle] = []
    @Published private(set) var searchMessage = "Finding you a driver…"
    /// Estimated seconds remaining in the matching wait (UI countdown).
    @Published private(set) var estimatedMatchingSeconds = 8
    /// When the current search began (for matching ETA UI).
    @Published private(set) var searchStartedAt: Date?
    /// When the driver was assigned (free-cancel window).
    @Published private(set) var driverAssignedAt: Date?
    /// Matching / connectivity presentation for the search sheet.
    @Published private(set) var matchingStatus: MatchingStatus = .idle
    /// Elapsed seconds while the driver waits at pickup.
    @Published private(set) var pickupWaitSeconds = 0
    /// Running waiting charge in local currency (after free grace).
    @Published private(set) var pickupWaitChargeLocal = 0
    /// Last rider cancellation (reason + fee) for status UI.
    @Published private(set) var lastCancellation: CancellationRecord?
    /// 0…1 along the active approach / in-trip polyline — Maps agents may observe without owning motion.
    @Published private(set) var routeProgress: Double = 0
    /// Which leg the simulation is currently driving (`nil` when idle).
    @Published private(set) var motionSimulationKind: TripMotionSimulationKind?
    @Published private(set) var lastReceipt: TripReceipt?
    @Published private(set) var tripHistory: [TripReceipt] = TripHistoryStore.load()
    @Published private(set) var chatMessages: [ChatMessage] = []
    @Published private(set) var unreadChatCount = 0
    @Published private(set) var driverIsTyping = false
    @Published private(set) var reservedTrips: [ReservedTrip] = ReservedTripStore.load()
    @Published var draftRating = 5
    @Published var draftRatingComment = ""
    @Published var draftRatingTags: Set<String> = []
    @Published var draftTipCDF = 0
    @Published var paymentMethod: PaymentMethod = .cash
    @Published var promoCode = ""
    @Published var appliedPromoDiscountCDF = 0
    @Published private(set) var promoStatus: PromoValidationStatus = .idle
    @Published private(set) var surgeState: SurgeState = .inactive
    /// Pickup zone context (airport / downtown / demand) for availability + surcharge copy.
    @Published private(set) var zoneContext: ZoneResolution = .empty
    @Published private(set) var farePreview: FareBreakdown?
    /// Optional shared promo catalog (bound from `VuumApp`).
    private weak var promoStore: PromoCodesStore?
    @Published var bookForSomeoneElse = false
    @Published var passengerName = ""
    @Published var passengerPhone = ""
    @Published var scheduleForLater: Date?
    @Published var scheduleReminderEnabled = true
    @Published var preferQuietRide = false
    @Published var accessibilityNotes = ""
    /// Optional rider-proposed fare (R27); `nil` uses the engine estimate.
    @Published var negotiateFareEnabled = false
    @Published var negotiatedTargetCDF: Int?
    @Published var reservationConfirmationMessage: String?
    @Published var sosRequested = false
    @Published private(set) var sosRequestedAt: Date?
    @Published private(set) var safetyTeamNotified = false
    /// Shown when share-by-default is on and trusted contacts exist.
    @Published var showTripShareReminder = false
    /// Live driver speed (km/h) while approach / trip motion is playing (S08).
    @Published private(set) var driverSpeedKmh: Int = 0
    /// Last automatic safety activation reason for in-trip banner.
    @Published private(set) var automaticSafetyNotice: String?
    @Published var bookOnCompanyWallet = false
    @Published var vipExecutiveTransfer = false
    /// Executive meet-and-greet: driver greets traveller with name board / door instructions.
    @Published var meetAndGreetEnabled = false
    /// Text shown on the driver's name board (usually the traveller).
    @Published var meetAndGreetSignName = ""
    /// Where to meet (arrivals, lobby, curb, custom gate).
    @Published var meetAndGreetDoorInstruction = ""
    /// Corporate / VIP trip purpose shown to the driver.
    @Published var tripPurpose = ""
    /// Courier delivery instructions (package size, fragile, recipient, etc.).
    @Published var packageNotes = ""
    /// Hourly rental length; `0` means not an hourly booking.
    @Published var hourlyDurationHours = 0
    /// When true, in-trip audio is retained after the trip for Safety review.
    @Published private(set) var incidentFlagged = false
    @Published var boardingPINEntry = ""
    @Published var boardingPINRejected = false

    let audioRecorder = TripAudioRecorder()

    /// Bound from `VuumApp`; when nil, falls back to `AppLocale.current`.
    private weak var appLocale: AppLocale?
    private weak var notifications: NotificationStore?
    private weak var fieldSales: FieldSalesStore?
    private weak var paymentStore: PaymentMethodStore?
    private var localeCancellable: AnyCancellable?
    private var sosNotifyTask: Task<Void, Never>?

    private var fareMarket: AppLocale.Market {
        appLocale?.fareMarket ?? AppLocale.current
    }

    private var lifecycleTask: Task<Void, Never>?
    /// Optional traffic-aware ETA re-query (off unless rider opts in + Maps key present).
    private var etaRefreshTask: Task<Void, Never>?
    /// Separate from trip `lifecycleTask` so idle/search crawls never cancel driver motion.
    private var nearbyMotionTask: Task<Void, Never>?
    private var audioObservation: AnyCancellable?
    /// Bumped on every lifecycle cancel so in-flight Task hops cannot resurrect trip state.
    private var lifecycleGeneration = 0
    private var motionStart: Date?
    private var motionDuration: TimeInterval = 1
    private var motionFromFraction: Double = 0
    private var motionToFraction: Double = 1
    private var motionPath: [GeoPoint] = []
    private var motionKind: MotionKind = .toPickup
    /// Displayed ETA at the start of the current motion segment (counts down with progress).
    private var motionBaselineETAMinutes = 0
    private var chatPresented = false
    private var chatReplyTask: Task<Void, Never>?
    private var chatTripID: String?
    /// Preview polyline for choose-ride (Directions when keyed, else synthetic).
    @Published private(set) var previewRoute: [GeoPoint] = []
    private var previewRouteTask: Task<Void, Never>?
    private var routeAssignTask: Task<Void, Never>?
    /// Live in-trip leg refine (Routes/Directions); cancelled with trip / superseded by next leg.
    private var legRefineTask: Task<Void, Never>?
    /// Waypoints last requested for choose-ride preview — skips duplicate Google fetches on resume/redraw.
    private var previewRouteWaypoints: [GeoPoint]?
    /// Invalidates in-flight mid-trip destination RouteEngine fetches (independent of motion `lifecycleGeneration`).
    private var destinationRouteGeneration = 0
    /// Next waypoint index along pickup → stops → dropoff during in-trip legs.
    private var inTripWaypointIndex = 0
    /// Debounce reverse-geocode while GPS crawls.
    private var reverseGeocodeTask: Task<Void, Never>?
    private var lastReverseGeocodedLocation: CLLocation?
    private var lastReverseGeocodeAt: Date?
    private let reverseGeocodeMinDistanceMeters: CLLocationDistance = 45
    private let reverseGeocodeMinInterval: TimeInterval = 18
    /// Separate from lifecycle so arrival wait keeps ticking after approach motion ends.
    private var waitTickerTask: Task<Void, Never>?
    private var searchAttemptCount = 0
    /// Alternates so presenters can show no-drivers + retry without every request failing.
    private var simulateNoDriversOnNextSearch = true
    /// XCTest seam: compress search ticks + approach motion so lifecycle suites finish quickly.
    var testingAcceleratedLifecycle = false
    /// Corridor persistence for in-trip route-deviation (logic in `RouteDeviationMonitor`).
    private var routeDeviationMonitor = RouteDeviationMonitor()
    /// One inbox ping per notice activation (cleared when the notice clears).
    private var didPostRouteDeviationNotification = false
    /// Rider tapped dismiss; suppress banner until the monitor recovers on-route.
    private var routeDeviationNoticeDismissed = false

    /// XCTest seam: skip the alternating first-search “no drivers” outcome.
    func testingPreferImmediateDriverMatch() {
        simulateNoDriversOnNextSearch = false
    }

    /// XCTest seam: outstanding Routes/Directions Tasks (preview, assign, leg refine).
    var testingHasOutstandingGoogleRouteWork: Bool {
        previewRouteTask != nil || routeAssignTask != nil || legRefineTask != nil
    }

    // MARK: - App lifecycle (background / resume)

    /// Foreground resume: keep authoritative trip state; do **not** re-issue Routes/Directions/Places.
    /// Location refresh remains owned by `VuumApp` → `RiderLocationManager` (throttled reverse geocode).
    func handleAppWillEnterForeground() {
        // Intentionally no refreshPreviewRoute / assignDriver / Places — audit §54.
    }

    /// Background: cancel idle/choose-ride Google preview + reverse-geocode; leave active-trip
    /// route Tasks alone (generation guards still apply on apply).
    func handleAppDidEnterBackground() {
        switch phase {
        case .idle, .selectingDestination, .choosingRide:
            previewRouteTask?.cancel()
            previewRouteTask = nil
            reverseGeocodeTask?.cancel()
            reverseGeocodeTask = nil
        case .searching, .matched, .driverEnRoute, .driverArrived, .inTrip, .completed:
            reverseGeocodeTask?.cancel()
            reverseGeocodeTask = nil
        }
    }

    /// Cancels in-flight Google route / geocode work. Safe on trip cancel — not from `beginMotion`
    /// / `cancelLifecycle` (those must not abort mid-trip destination RouteEngine applies).
    private func cancelInFlightGoogleWork() {
        previewRouteTask?.cancel()
        previewRouteTask = nil
        previewRouteWaypoints = nil
        routeAssignTask?.cancel()
        routeAssignTask = nil
        legRefineTask?.cancel()
        legRefineTask = nil
        destinationRouteGeneration &+= 1
        isRecalculatingTripRoute = false
        reverseGeocodeTask?.cancel()
        reverseGeocodeTask = nil
    }

    private enum MotionKind {
        case toPickup
        /// Heading to intermediate stop at `stops[index]`.
        case toStop(Int)
        case toDropoff
    }

    /// Public mirror of internal motion for Maps / overlays (stable API surface).
    enum TripMotionSimulationKind: Equatable {
        case approachingPickup
        case waitingAtStop
        case enRouteToDropoff
    }

    /// Waypoints for the booked trip: pickup → stops → dropoff.
    var tripWaypoints: [GeoPoint] {
        var points = [pickup.coordinate]
        points.append(contentsOf: stops.map(\.coordinate))
        if let dropoff {
            points.append(dropoff.coordinate)
        }
        return points
    }

    /// Route distance used for fares and ETA — prefers live preview length when available.
    var tripRouteDistanceMeters: Double {
        if previewRoute.count >= 2 {
            return TripGeo.pathLengthMeters(previewRoute)
        }
        let waypoints = tripWaypoints
        guard waypoints.count >= 2 else { return 0 }
        return TripGeo.pathLengthMeters(TripGeo.routePolyline(through: waypoints, samplesPerLeg: 24))
    }

    /// Free cancel while searching, or within the post-assignment window.
    var isCancellationFree: Bool {
        switch phase {
        case .searching, .matched, .choosingRide, .idle, .selectingDestination, .completed:
            return true
        case .driverEnRoute, .driverArrived:
            guard let assigned = driverAssignedAt else { return true }
            return Date().timeIntervalSince(assigned) < CancellationPolicy.freeWindowSeconds
        case .inTrip:
            return false
        }
    }

    /// Local-currency cancel fee when outside the free window (0 while free).
    var cancellationFeeLocal: Int {
        guard !isCancellationFree else { return 0 }
        return CancellationPolicy.feeLocal(market: fareMarket)
    }

    /// Seconds of free wait remaining at pickup (0 once billable wait starts).
    var pickupWaitGraceRemaining: Int {
        max(CancellationPolicy.pickupWaitGraceSeconds - pickupWaitSeconds, 0)
    }

    /// Billable wait minutes beyond the free grace window.
    var billablePickupWaitMinutes: Int {
        let excess = max(pickupWaitSeconds - CancellationPolicy.pickupWaitGraceSeconds, 0)
        guard excess > 0 else { return 0 }
        return Int(ceil(Double(excess) / 60.0))
    }

    /// Alias for in-trip progress UI (`routeProgress` is the source of truth from motion).
    var tripProgressFraction: Double {
        routeProgress
    }

    var mapCamera: GeoPoint {
        activeTrip?.driverCoordinate ?? dropoff?.coordinate ?? pickup.coordinate
    }

    var mapPins: [MapPin] {
        var pins: [MapPin] = []

        switch phase {
        case .idle:
            appendNearbyVehiclePins(to: &pins)
        case .selectingDestination:
            // Same ride anchors as later phases — pickup (+ stops / dropoff) while choosing a destination.
            pins.append(MapPin(id: "pickup", coordinate: pickup.coordinate, kind: .pickup, heading: 0))
            for stop in stops {
                pins.append(MapPin(id: "stop-\(stop.id)", coordinate: stop.coordinate, kind: .stop, heading: 0))
            }
            if let dropoff {
                pins.append(MapPin(id: "dropoff", coordinate: dropoff.coordinate, kind: .dropoff, heading: 0))
            }
            appendNearbyVehiclePins(to: &pins)
        case .choosingRide, .searching:
            pins.append(MapPin(id: "pickup", coordinate: pickup.coordinate, kind: .pickup, heading: 0))
            for stop in stops {
                pins.append(MapPin(id: "stop-\(stop.id)", coordinate: stop.coordinate, kind: .stop, heading: 0))
            }
            if let dropoff {
                pins.append(MapPin(id: "dropoff", coordinate: dropoff.coordinate, kind: .dropoff, heading: 0))
            }
            appendNearbyVehiclePins(to: &pins)
        case .matched, .driverEnRoute, .driverArrived, .inTrip:
            guard let trip = activeTrip else { break }
            pins.append(MapPin(id: "pickup", coordinate: trip.pickup.coordinate, kind: .pickup, heading: 0))
            for stop in trip.stops {
                pins.append(MapPin(id: "stop-\(stop.id)", coordinate: stop.coordinate, kind: .stop, heading: 0))
            }
            pins.append(MapPin(id: "dropoff", coordinate: trip.dropoff.coordinate, kind: .dropoff, heading: 0))
            pins.append(
                MapPin(
                    id: "driver",
                    coordinate: trip.driverCoordinate,
                    kind: .driver,
                    heading: trip.driverHeading,
                    vehicleClass: trip.tier.vehicleClass
                )
            )
        case .completed:
            if let trip = activeTrip {
                pins.append(MapPin(id: "dropoff", coordinate: trip.dropoff.coordinate, kind: .dropoff, heading: 0))
            }
        }

        return pins
    }

    /// Preview / remaining polyline for the single live ride — Maps must not invent a second path.
    var mapRoute: [GeoPoint] {
        guard let trip = activeTrip else {
            switch phase {
            case .choosingRide, .searching:
                guard dropoff != nil else { return [] }
                return previewRoute.isEmpty
                    ? TripGeo.routePolyline(through: tripWaypoints)
                    : previewRoute
            default:
                return []
            }
        }
        switch phase {
        case .matched, .driverEnRoute:
            return TripGeo.remainingPath(along: trip.pickupRoute, from: trip.driverCoordinate)
        case .driverArrived:
            // Driver at curb — clear approach polyline so the map matches arrival.
            return []
        case .inTrip:
            return TripGeo.remainingPath(along: trip.tripRoute, from: trip.driverCoordinate)
        default:
            return []
        }
    }

    /// Static fit targets only — live driver position is followed via `shouldFollowDriverOnMap`, not refit every frame.
    var mapFitCoordinates: [GeoPoint] {
        switch phase {
        case .choosingRide, .searching:
            return tripWaypoints
        case .selectingDestination:
            let points = tripWaypoints
            return points.count >= 2 ? points : []
        case .matched, .driverEnRoute, .driverArrived:
            guard let trip = activeTrip else { return [] }
            if let start = trip.pickupRoute.first {
                return [start, trip.pickup.coordinate]
            }
            return [trip.pickup.coordinate]
        case .inTrip:
            guard let trip = activeTrip else { return [] }
            var coords = [trip.pickup.coordinate]
            coords.append(contentsOf: trip.stops.map(\.coordinate))
            coords.append(trip.dropoff.coordinate)
            return coords
        default:
            return []
        }
    }

    /// Maps / UI: whether TripSession owns a live driver marker along a route.
    var isSimulatingDriverMotion: Bool {
        motionSimulationKind != nil && activeTrip != nil
    }

    /// Single camera-follow flag for `TripMapLayer` — derived only from this ride's phase.
    var shouldFollowDriverOnMap: Bool {
        guard activeTrip != nil else { return false }
        switch phase {
        case .matched, .driverEnRoute, .driverArrived, .inTrip:
            return true
        default:
            return false
        }
    }

    private func appendNearbyVehiclePins(to pins: inout [MapPin]) {
        for vehicle in nearbyVehicles {
            pins.append(
                MapPin(
                    id: vehicle.id,
                    coordinate: vehicle.coordinate,
                    kind: .nearby,
                    heading: vehicle.heading,
                    vehicleClass: vehicle.vehicleClass
                )
            )
        }
    }

    /// Fleet class for the selected / active ride (defaults to standard cars on the home map).
    var activeVehicleClass: VehicleClass {
        activeTrip?.tier.vehicleClass
            ?? selectedTier?.vehicleClass
            ?? .standard
    }

    /// Chat / call are live once a driver is assigned (matched → in-trip).
    var isChatAvailable: Bool {
        guard activeTrip != nil else { return false }
        switch phase {
        case .matched, .driverEnRoute, .driverArrived, .inTrip:
            return true
        default:
            return false
        }
    }

    /// Driver card sheet content is shown whenever an active trip exists post-match.
    var showsDriverCard: Bool {
        isChatAvailable || phase == .completed
    }

    init() {
        refreshZoneContext()
        seedNearbyVehicles()
        refreshReservationStatuses()
        audioObservation = audioRecorder.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    /// Wire location-aware market. Safe to call once from `VuumApp`.
    func bind(locale: AppLocale) {
        appLocale = locale
        applyMarketDefaults(forcePickupReset: true)
        localeCancellable = locale.$market
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.applyMarketDefaults(forcePickupReset: false)
            }
    }

    /// Optional inbox for scheduled-ride confirmations and reminders.
    func bind(notifications: NotificationStore) {
        self.notifications = notifications
    }

    var currentRidePreferences: RidePreferences {
        RidePreferences(
            quietRide: preferQuietRide,
            accessibilityNotes: accessibilityNotes
        )
    }

    /// Wire promo catalog. Safe to call once from `VuumApp`.
    func bind(promos: PromoCodesStore) {
        promoStore = promos
    }

    func bind(payments: PaymentMethodStore) {
        paymentStore = payments
        if !bookOnCompanyWallet {
            paymentMethod = payments.selectedMethod
        }
    }

    func bind(fieldSales: FieldSalesStore) {
        self.fieldSales = fieldSales
    }

    /// Applies catalog / fare market when idle so an active trip is never interrupted.
    private func applyMarketDefaults(forcePickupReset: Bool) {
        guard phase == .idle else { return }
        let center = MockPlaces.defaultCenter(for: fareMarket)
        let autoPickupIDs: Set<String> = ["current", MockPlaces.lubumbashiCenter.id, MockPlaces.nairobiCenter.id]
        if forcePickupReset || autoPickupIDs.contains(pickup.id) {
            if pickup.id != "current" || forcePickupReset {
                pickup = center
                seedNearbyVehicles()
            }
        }
        refreshZoneContext()
        refreshAvailableTiers(distanceMeters: 4_500)
    }

    /// Corporate / VIP booking path unlocks premium products in zone gating.
    private var riderAccountType: RiderAccountType {
        (bookOnCompanyWallet || vipExecutiveTransfer) ? .corporate : .personal
    }

    /// Whether a home / services product is offered at the current pickup.
    func isServiceAvailable(_ serviceID: String) -> Bool {
        if zoneContext.availableServiceIDs.isEmpty {
            return ServiceProductID.matches(serviceID, allowed: ServiceZoneCatalog.cityWideServices)
        }
        return zoneContext.allows(serviceID: serviceID)
    }

    var canRecordTripAudio: Bool {
        phase == .matched || phase == .driverEnRoute || phase == .driverArrived || phase == .inTrip
    }

    var isRecordingTripAudio: Bool {
        audioRecorder.isRecording
    }

    func setIncidentFlagged(_ flagged: Bool) {
        incidentFlagged = flagged
    }

    func toggleTripAudioRecording(using permissions: PermissionCenter? = nil) {
        Task { await toggleTripAudioRecordingAsync(using: permissions) }
    }

    func toggleTripAudioRecordingAsync(using permissions: PermissionCenter? = nil) async {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
            notifications?.postRecordingStopped()
            return
        }
        guard canRecordTripAudio else { return }
        if await audioRecorder.startRecording(using: permissions) {
            notifications?.postRecordingStarted()
        }
    }

    func updatePickup(from location: CLLocation?) {
        guard phase == .idle || phase == .selectingDestination else { return }
        // Keep a rider-chosen alternate pin until they reset or request a new trip.
        let autoPickupIDs: Set<String> = [
            "current",
            MockPlaces.lubumbashiCenter.id,
            MockPlaces.nairobiCenter.id,
        ]
        guard autoPickupIDs.contains(pickup.id) else { return }
        guard let location else { return }
        // Ignore stale / invalid fixes so pickup does not jump to an old coordinate.
        let age = -location.timestamp.timeIntervalSinceNow
        guard age >= 0, age <= 60 else { return }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 500 else { return }

        let coordinate = GeoPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        // Market centers keep honest place names; only live GPS (`id == current`) may show
        // "Current location", and only until reverse geocode supplies a street/place label.
        let fromMarketCenter = pickup.id != "current"
        let awaitingFirstLabel = ReverseGeocodingService.isUnresolvedPickupName(pickup.name)
        let keptName: String
        let keptSubtitle: String
        if fromMarketCenter || awaitingFirstLabel {
            let fallback = ReverseGeocodingService.coordinateFallback(location)
            keptName = fallback.name
            keptSubtitle = fallback.subtitle
        } else {
            keptName = pickup.name
            keptSubtitle = pickup.subtitle
        }
        pickup = Place(
            id: "current",
            name: keptName,
            subtitle: keptSubtitle,
            coordinate: coordinate
        )
        seedNearbyVehicles()
        refreshZoneContext()
        scheduleReverseGeocode(for: location)
    }

    private func scheduleReverseGeocode(for location: CLLocation) {
        if let last = lastReverseGeocodedLocation,
           let at = lastReverseGeocodeAt,
           location.distance(from: last) < reverseGeocodeMinDistanceMeters,
           Date().timeIntervalSince(at) < reverseGeocodeMinInterval {
            return
        }

        reverseGeocodeTask?.cancel()
        let snapshot = location
        reverseGeocodeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            guard phase == .idle || phase == .selectingDestination else { return }
            guard pickup.id == "current" else { return }

            let label = await ReverseGeocodingService.reverseGeocode(snapshot)
            guard !Task.isCancelled else { return }
            guard pickup.id == "current" else { return }

            let current = CLLocation(
                latitude: pickup.coordinate.latitude,
                longitude: pickup.coordinate.longitude
            )
            // Drop stale results if GPS moved far while geocoding.
            if current.distance(from: snapshot) > 120 { return }

            // Prefer keeping a prior street label over regressing to the unresolved placeholder.
            let nextName: String
            let nextSubtitle: String
            if ReverseGeocodingService.isUnresolvedPickupName(label.name),
               !ReverseGeocodingService.isUnresolvedPickupName(pickup.name) {
                nextName = pickup.name
                nextSubtitle = pickup.subtitle.isEmpty
                    ? ReverseGeocodingService.coordinateSubtitle(snapshot)
                    : pickup.subtitle
            } else {
                nextName = label.name
                nextSubtitle = label.subtitle
            }

            pickup = Place(
                id: "current",
                name: nextName,
                subtitle: nextSubtitle,
                coordinate: pickup.coordinate
            )
            lastReverseGeocodedLocation = snapshot
            lastReverseGeocodeAt = Date()
        }
    }

    /// Local mock alternatives offset from the current pickup (no Places API).
    func nearbyPickupSuggestions() -> [Place] {
        let base = pickup.coordinate
        let options: [(name: String, subtitle: String, north: Double, east: Double)] = [
            ("Corner entrance", "Closer to the street", 40, 25),
            ("Building lobby", "Main entrance", -30, 45),
            ("Across the street", "Safer pickup side", 60, -35),
            ("Side gate", "Quiet access", -50, -40),
            ("Parking bay", "Near the curb", 25, -60),
        ]
        return options.enumerated().map { index, item in
            Place(
                id: "pickup-alt-\(index)",
                name: item.name,
                subtitle: item.subtitle,
                coordinate: TripGeo.offset(base, northMeters: item.north, eastMeters: item.east)
            )
        }
    }

    func selectPickup(_ place: Place) {
        guard phase == .idle || phase == .selectingDestination || phase == .choosingRide else { return }
        pickup = place
        seedNearbyVehicles()
        refreshZoneContext()
        if phase == .choosingRide {
            // Pickup pin + high-demand zone changed — rebuild preview (live or synthetic)
            // so map polyline and surge-aware fares use the same geography.
            refreshPreviewRoute()
            refreshTierPricing()
        }
    }

    func beginDestinationSelection(preferredTierID: String? = nil) {
        cancelInFlightGoogleWork()
        cancelLifecycle()
        self.preferredTierID = preferredTierID
        stickyInjectTierID = nil
        phase = .selectingDestination
        dropoff = nil
        stops = []
        isAddingStop = false
        selectedTier = nil
        activeTrip = nil
        packageNotes = ""
        hourlyDurationHours = 0
        clearPreviewRoute()
        seedNearbyVehicles()
    }

    /// Re-centers the home map on the current pickup (GPS or chosen pin).
    func requestMapRecenter() {
        mapCameraFocusNonce &+= 1
        seedNearbyVehicles()
    }

    /// Reopens destination search from choose-ride without wiping intermediate stops.
    func changeDestination() {
        guard phase == .choosingRide || phase == .selectingDestination else { return }
        cancelLifecycle()
        isAddingStop = false
        dropoff = nil
        selectedTier = nil
        activeTrip = nil
        phase = .selectingDestination
        clearPreviewRoute()
        seedNearbyVehicles()
    }

    /// Rider may change dropoff after a driver is assigned and before the trip completes.
    var canChangeInTripDestination: Bool {
        guard activeTrip != nil else { return false }
        switch phase {
        case .driverEnRoute, .driverArrived, .inTrip:
            return true
        default:
            return false
        }
    }

    /// Updates dropoff mid-trip: refreshes route (RouteEngine), ETA, fare, and map fit.
    func updateInTripDestination(_ place: Place) {
        guard canChangeInTripDestination, var trip = activeTrip else { return }
        guard place.id != trip.dropoff.id else { return }
        guard place.id != trip.pickup.id else { return }
        guard !trip.stops.contains(where: { $0.id == place.id }) else { return }

        let previousFareTotal = trip.fare.totalCDF
        let previousName = trip.dropoff.name
        destinationChangeNotice = nil
        clearRouteDeviationState()
        isRecalculatingTripRoute = true

        let remainingStopStart = remainingStopStartIndex(for: trip)
        let routeWaypoints = remainingRouteWaypoints(
            for: trip,
            dropoff: place,
            remainingStopStart: remainingStopStart
        )
        let farePoints = fareWaypoints(for: trip, dropoff: place)

        // Immediate synthetic path so the map + fare update before Routes/Directions returns.
        let syntheticRemaining = RouteEngine.synthetic(through: routeWaypoints)
        let syntheticFare = RouteEngine.synthetic(through: farePoints)
        applyInTripDestinationRoute(
            place: place,
            previousName: previousName,
            previousFareTotal: previousFareTotal,
            remainingPath: syntheticRemaining,
            fareRoute: syntheticFare,
            remainingStopStart: remainingStopStart,
            trip: &trip,
            announce: true,
            finalizeRecalc: false
        )

        // Own generation: `beginMotion` bumps `lifecycleGeneration`, which must not drop the live apply.
        destinationRouteGeneration &+= 1
        let generation = destinationRouteGeneration
        let placeID = place.id
        routeAssignTask?.cancel()
        routeAssignTask = Task { [weak self] in
            let liveRemaining = await RouteEngine.route(through: routeWaypoints)
            let liveFare = await RouteEngine.route(through: farePoints)
            await MainActor.run {
                guard let self else { return }
                guard !Task.isCancelled,
                      self.destinationRouteGeneration == generation,
                      self.canChangeInTripDestination,
                      var current = self.activeTrip,
                      current.dropoff.id == placeID
                else {
                    // Only the latest in-flight change may clear the spinner.
                    if self.destinationRouteGeneration == generation {
                        self.isRecalculatingTripRoute = false
                    }
                    return
                }
                self.applyInTripDestinationRoute(
                    place: place,
                    previousName: previousName,
                    previousFareTotal: previousFareTotal,
                    remainingPath: liveRemaining,
                    fareRoute: liveFare,
                    remainingStopStart: remainingStopStart,
                    trip: &current,
                    announce: false,
                    finalizeRecalc: true
                )
            }
        }
    }

    private func fareWaypoints(for trip: ActiveTrip, dropoff: Place) -> [GeoPoint] {
        var points = [trip.pickup.coordinate]
        points.append(contentsOf: trip.stops.map(\.coordinate))
        points.append(dropoff.coordinate)
        return points
    }

    /// First stop index still ahead (or `stops.count` when only dropoff remains).
    private func remainingStopStartIndex(for trip: ActiveTrip) -> Int {
        if let waiting = trip.waitingAtStopIndex {
            return waiting
        }
        switch motionKind {
        case .toStop(let index):
            return index
        case .toDropoff:
            return trip.stops.count
        case .toPickup:
            return 0
        }
    }

    private func remainingRouteWaypoints(
        for trip: ActiveTrip,
        dropoff: Place,
        remainingStopStart: Int
    ) -> [GeoPoint] {
        if phase == .inTrip {
            var points = [trip.driverCoordinate]
            if remainingStopStart < trip.stops.count {
                points.append(contentsOf: trip.stops[remainingStopStart...].map(\.coordinate))
            }
            points.append(dropoff.coordinate)
            return points
        }
        return fareWaypoints(for: trip, dropoff: dropoff)
    }

    private func applyInTripDestinationRoute(
        place: Place,
        previousName: String,
        previousFareTotal: Int,
        remainingPath: RouteEngine.Route,
        fareRoute: RouteEngine.Route,
        remainingStopStart: Int,
        trip: inout ActiveTrip,
        announce: Bool,
        finalizeRecalc: Bool
    ) {
        let waiting = trip.stops.isEmpty ? 0 : trip.stops.count * Self.waitMinutesPerStop
        let airport = MockSurge.isAirportTrip(pickup: trip.pickup, dropoff: place)
        surgeState = MockSurge.state(pickup: trip.pickup, dropoff: place)
        let fareDistanceMeters = max(fareRoute.distanceMeters, 1)
        let fare = MockFares.breakdown(
            distanceMeters: fareDistanceMeters,
            tier: trip.tier,
            discountCDF: appliedPromoDiscountCDF,
            surgeMultiplier: surgeState.multiplier,
            tollCDF: MockSurge.tollLocal(for: fareMarket, isAirport: airport),
            waitingMinutes: waiting,
            market: fareMarket
        )

        trip.dropoff = place
        trip.fare = fare
        dropoff = place

        // Prefer live fare polyline (Routes/Directions) so the map / corridor match the new fare path.
        let fullWaypoints = fareWaypoints(for: trip, dropoff: place)
        trip.tripRoute = fareRoute.coordinates.count >= 2
            ? fareRoute.coordinates
            : RouteEngine.synthetic(through: fullWaypoints).coordinates
        if fareRoute.durationSeconds > 0 {
            trip.routeDurationSeconds = fareRoute.durationSeconds
        }

        let pathCoords = remainingPath.coordinates.count >= 2
            ? remainingPath.coordinates
            : RouteEngine.synthetic(
                through: remainingRouteWaypoints(
                    for: trip,
                    dropoff: place,
                    remainingStopStart: remainingStopStart
                )
            ).coordinates
        let remainingMeters = remainingPath.distanceMeters > 0
            ? remainingPath.distanceMeters
            : TripGeo.pathLengthMeters(pathCoords)
        let eta = max(1, remainingPath.durationSeconds > 0
            ? remainingPath.durationMinutes
            : TripGeo.etaMinutes(distanceMeters: remainingMeters, speedKmh: VehiclePickupETA.tripSpeedKmh(for: trip.tier.vehicleClass)))

        if phase == .inTrip {
            trip.waitingAtStopIndex = nil
            trip.distanceRemainingMeters = remainingMeters
            trip.etaMinutes = eta
            mapCameraFocusNonce &+= 1

            if remainingStopStart < trip.stops.count {
                let stop = trip.stops[remainingStopStart]
                let leg = Self.firstLeg(of: pathCoords, to: stop.coordinate, from: trip.driverCoordinate)
                let legDistance = TripGeo.pathLengthMeters(leg)
                let legETA: Int
                if let first = remainingPath.legs.first, first.durationSeconds > 0 {
                    legETA = first.durationMinutes
                } else if remainingPath.durationSeconds > 0 {
                    legETA = remainingPath.etaMinutes(forRemainingMeters: legDistance)
                } else {
                    legETA = TripGeo.etaMinutes(
                        distanceMeters: legDistance,
                        speedKmh: VehiclePickupETA.tripSpeedKmh(for: trip.tier.vehicleClass)
                    )
                }
                trip.distanceRemainingMeters = remainingMeters
                trip.etaMinutes = eta
                trip.statusHeadline = "Next stop · \(stop.name)"
                trip.statusDetail = "Then \(place.name) · \(TripGeo.formatDuration(minutes: eta))"
                activeTrip = trip
                beginMotion(
                    path: leg,
                    duration: TripMotionTiming.tripSimulationDurationSeconds(displayedETAMinutes: legETA),
                    kind: .toStop(remainingStopStart),
                    baselineETA: legETA
                )
            } else {
                trip.statusHeadline = L10n.format("trip.on_the_way", place.name)
                trip.statusDetail = "\(TripGeo.formatDuration(minutes: eta)) · \(TripGeo.formatDistance(remainingMeters))"
                activeTrip = trip
                inTripWaypointIndex = trip.stops.count
                beginMotion(
                    path: pathCoords,
                    duration: TripMotionTiming.tripSimulationDurationSeconds(displayedETAMinutes: eta),
                    kind: .toDropoff,
                    baselineETA: eta
                )
            }
        } else {
            // Driver still approaching / at pickup — keep pickup motion; refresh planned dropoff.
            activeTrip = trip
            mapCameraFocusNonce &+= 1
        }

        let fareLine = AppLocale.formatFareTotal(
            cdf: fare.totalCDF,
            usd: fare.totalUSD,
            market: fareMarket
        )
        if fare.totalCDF != previousFareTotal {
            destinationChangeNotice = "Destination updated · new fare \(fareLine)"
        } else {
            destinationChangeNotice = "Destination updated · \(place.name)"
        }

        if announce {
            scheduleProactiveDriverMessage(
                "Got it — new destination is \(place.name). Updating the route.",
                after: 600_000_000
            )
            notifications?.post(
                .trip,
                title: "Destination updated",
                body: "Now heading to \(place.name) · \(fareLine). Was \(previousName)."
            )
        }

        if finalizeRecalc {
            isRecalculatingTripRoute = false
        }
    }

    /// Prefix of a multi-leg remaining polyline up to the next stop (falls back to a synthetic leg).
    private static func firstLeg(of path: [GeoPoint], to waypoint: GeoPoint, from origin: GeoPoint) -> [GeoPoint] {
        guard path.count >= 2 else {
            return RouteEngine.synthetic(from: origin, to: waypoint).coordinates
        }
        var bestIdx = path.count - 1
        var bestDist = Double.greatestFiniteMagnitude
        for (index, point) in path.enumerated() {
            let distance = TripGeo.distanceMeters(from: point, to: waypoint)
            if distance < bestDist {
                bestDist = distance
                bestIdx = index
            }
        }
        let leg = Array(path.prefix(max(bestIdx + 1, 2)))
        return leg.count >= 2 ? leg : RouteEngine.synthetic(from: origin, to: waypoint).coordinates
    }

    /// Hands a Services-hub product form into the standard choose-ride → request path.
    func startLocalProductBooking(
        pickup: Place,
        dropoff: Place,
        preferredTierID: String? = nil,
        packageNotes: String = "",
        hourlyHours: Int = 0,
        injectTier: RideTier? = nil
    ) {
        cancelLifecycle()
        self.pickup = pickup
        self.packageNotes = packageNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hourlyDurationHours = max(0, hourlyHours)
        self.preferredTierID = preferredTierID.map(ServiceProductID.canonical)
        stickyInjectTierID = injectTier?.id
        stops = []
        isAddingStop = false
        selectedTier = nil
        activeTrip = nil
        scheduleForLater = nil
        seedNearbyVehicles(preferring: injectTier?.vehicleClass ?? .standard)
        self.dropoff = dropoff
        refreshTierPricing()
        if let injectID = stickyInjectTierID,
           let match = availableTiers.first(where: { $0.id == injectID }) {
            selectedTier = match
        } else if let preferred = self.preferredTierID,
                  let match = availableTiers.first(where: { $0.id == preferred }) {
            selectedTier = match
        } else if selectedTier == nil {
            selectedTierDefault()
        }
        phase = .choosingRide
        refreshPreviewRoute()
    }

    /// Executive / VIP meet-and-greet booking from Services or Business profile.
    func startExecutiveMeetAndGreetBooking(
        pickup: Place,
        dropoff: Place,
        travellerName: String,
        tripPurpose: String,
        meetAndGreet: Bool,
        nameBoard: Bool,
        doorInstruction: String,
        scheduleAt: Date?,
        packageNotes: String,
        injectTier: RideTier
    ) {
        let trimmedName = travellerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPurpose = tripPurpose.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDoor = doorInstruction.trimmingCharacters(in: .whitespacesAndNewlines)

        vipExecutiveTransfer = true
        meetAndGreetEnabled = meetAndGreet
        meetAndGreetSignName = (meetAndGreet && nameBoard) ? trimmedName : ""
        meetAndGreetDoorInstruction = meetAndGreet ? trimmedDoor : ""
        self.tripPurpose = trimmedPurpose

        if !trimmedName.isEmpty {
            passengerName = trimmedName
        }

        startLocalProductBooking(
            pickup: pickup,
            dropoff: dropoff,
            preferredTierID: "executive",
            packageNotes: packageNotes,
            injectTier: injectTier
        )

        if let scheduleAt, scheduleAt > Date() {
            scheduleForLater = scheduleAt
        }
    }

    func beginAddingStop() {
        guard stops.count < Self.maxStops, dropoff != nil else { return }
        isAddingStop = true
        phase = .selectingDestination
    }

    func cancelAddingStop() {
        isAddingStop = false
        if dropoff != nil {
            phase = .choosingRide
        } else {
            phase = .idle
        }
    }

    func selectDestination(_ place: Place) {
        if isAddingStop {
            addStop(place)
            return
        }
        dropoff = place
        phase = .choosingRide
        // Synthetic preview first so fare distance matches the map immediately;
        // live Routes/Directions replace the polyline and reprice when ready.
        refreshPreviewRoute()
        applyPreferredTierIfNeeded()
        refreshTierPricing()
    }

    func addStop(_ place: Place) {
        guard stops.count < Self.maxStops else { return }
        guard place.id != pickup.id, place.id != dropoff?.id else { return }
        guard !stops.contains(where: { $0.id == place.id }) else {
            isAddingStop = false
            phase = .choosingRide
            return
        }
        stops.append(place)
        isAddingStop = false
        phase = .choosingRide
        refreshPreviewRoute()
        refreshTierPricing()
    }

    func removeStop(_ place: Place) {
        stops.removeAll { $0.id == place.id }
        refreshPreviewRoute()
        refreshTierPricing()
    }

    /// Reorders an intermediate stop (booking only). Triggers fare + route recalculation.
    func moveStop(from fromIndex: Int, to toIndex: Int) {
        guard stops.indices.contains(fromIndex),
              stops.indices.contains(toIndex),
              fromIndex != toIndex
        else { return }
        let item = stops.remove(at: fromIndex)
        stops.insert(item, at: toIndex)
        refreshTierPricing()
        refreshPreviewRoute()
    }

    func moveStopUp(_ place: Place) {
        guard let index = stops.firstIndex(where: { $0.id == place.id }), index > 0 else { return }
        moveStop(from: index, to: index - 1)
    }

    func moveStopDown(_ place: Place) {
        guard let index = stops.firstIndex(where: { $0.id == place.id }),
              index < stops.count - 1
        else { return }
        moveStop(from: index, to: index + 1)
    }

    /// Reopens ride selection for a past trip’s route (Home tab picks up via phase change).
    func rebookFromReceipt(_ receipt: TripReceipt) {
        cancelLifecycle()
        resetBookingDraft(keepHistory: true)
        lastReceipt = nil
        if let matchedPickup = placeMatching(name: receipt.pickupName) {
            pickup = matchedPickup
        }
        let dropoffPlace = placeMatching(name: receipt.dropoffName)
            ?? Place(
                id: "rebook-\(receipt.id)",
                name: receipt.dropoffName,
                subtitle: "Previous trip",
                coordinate: MockPlaces.defaultCenter(for: fareMarket).coordinate
            )
        if let tier = availableTiers.first(where: { $0.name == receipt.tierName })
            ?? MockFares.tiers(for: 4_500, market: fareMarket).first(where: { $0.name == receipt.tierName }) {
            selectedTier = tier
        }
        selectDestination(dropoffPlace)
    }

    func cancelReservation(_ trip: ReservedTrip) {
        reservedTrips.removeAll { $0.id == trip.id }
        ReservedTripStore.save(reservedTrips)
        notifications?.postCancellation(
            reason: "Your pickup to \(trip.dropoffName) on \(trip.when.formatted(date: .abbreviated, time: .shortened)) was cancelled."
        )
    }

    func updateReservationTime(_ trip: ReservedTrip, to newDate: Date) {
        guard newDate > Date() else { return }
        guard let index = reservedTrips.firstIndex(where: { $0.id == trip.id }) else { return }
        reservedTrips[index].when = newDate
        reservedTrips[index].status = reservedTrips[index].reminderEnabled ? .reminderSet : .confirmed
        reservedTrips[index].assignedDriverName = nil
        reservedTrips[index].assignedVehicle = nil
        reservedTrips[index].assignedPlate = nil
        ReservedTripStore.save(reservedTrips)
        refreshReservationStatuses()
    }

    func setReservationReminder(_ trip: ReservedTrip, enabled: Bool) {
        guard let index = reservedTrips.firstIndex(where: { $0.id == trip.id }) else { return }
        reservedTrips[index].reminderEnabled = enabled
        if reservedTrips[index].status != .driverAssigned {
            reservedTrips[index].status = enabled ? .reminderSet : .confirmed
        }
        ReservedTripStore.save(reservedTrips)
    }

    /// Advances reserved trips toward driver assignment when pickup is soon.
    func refreshReservationStatuses() {
        let now = Date()
        var changed = false
        for index in reservedTrips.indices {
            let trip = reservedTrips[index]
            let hoursUntil = trip.when.timeIntervalSince(now) / 3600
            if hoursUntil <= 2, hoursUntil > -0.5, trip.status != .driverAssigned {
                let fleet = VehicleClass.resolving(tierID: trip.tierName)
                let driver = MockDrivers.random(for: fleet, market: fareMarket)
                reservedTrips[index].status = .driverAssigned
                reservedTrips[index].assignedDriverName = driver.name
                reservedTrips[index].assignedVehicle = driver.vehicle
                reservedTrips[index].assignedPlate = driver.plate
                changed = true
            } else if trip.reminderEnabled, trip.status == .confirmed {
                reservedTrips[index].status = .reminderSet
                changed = true
            }
        }
        if changed {
            ReservedTripStore.save(reservedTrips)
        }
    }

    func clearReservationConfirmation() {
        reservationConfirmationMessage = nil
    }

    private func placeMatching(name: String) -> Place? {
        let center = MockPlaces.defaultCenter(for: fareMarket)
        if name.localizedCaseInsensitiveContains("current")
            || name.localizedCaseInsensitiveContains("location") {
            return pickup.id == "current" || pickup.id == center.id
                ? pickup
                : center
        }
        return MockPlaces.destinations(for: fareMarket).first {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    func chooseTier(_ tier: RideTier) {
        selectedTier = tier
        updateFarePreview()
        if phase == .choosingRide || phase == .idle || phase == .selectingDestination {
            seedNearbyVehicles(preferring: tier.vehicleClass)
        }
    }

    func applyPromo() {
        let store = promoStore ?? PromoCodesStore()
        let airport = MockSurge.isAirportTrip(pickup: pickup, dropoff: dropoff)
        let estimate = selectedTier?.priceCDF
            ?? availableTiers.first?.priceCDF
            ?? AppLocale.minimumFareLocal(for: fareMarket) * 4
        let status = store.validate(
            code: promoCode,
            market: fareMarket,
            estimatedFareLocal: estimate,
            isAirportTrip: airport
        )
        promoStatus = status
        switch status {
        case .applied(_, let discount, _):
            appliedPromoDiscountCDF = discount
        case .idle, .invalid, .expired, .notEligible:
            appliedPromoDiscountCDF = 0
        }
        refreshTierPricing()
    }

    func clearPromo() {
        promoCode = ""
        appliedPromoDiscountCDF = 0
        promoStatus = .idle
        promoStore?.clearStatus()
        refreshTierPricing()
    }

    /// Full itemized estimate for the selected (or given) tier.
    func estimatedBreakdown(for tier: RideTier? = nil) -> FareBreakdown? {
        estimatedQuote(for: tier)?.breakdown
    }

    /// Typed pricing quote (Money primary/secondary + breakdown).
    func estimatedQuote(for tier: RideTier? = nil) -> PricingResult? {
        let resolved = tier ?? selectedTier
        guard let resolved, dropoff != nil else { return nil }
        let waiting = stops.isEmpty ? 0 : stops.count * Self.waitMinutesPerStop
        let airport = MockSurge.isAirportTrip(pickup: pickup, dropoff: dropoff)
        let meetAndGreetFee = meetAndGreetServiceFeeCDF
        let booking: PricingInput.BookingType = {
            if scheduleForLater != nil { return .scheduled }
            if bookOnCompanyWallet { return .corporate }
            if resolved.id == "executive" || vipExecutiveTransfer || meetAndGreetEnabled {
                return .executive
            }
            return .onDemand
        }()
        var negotiationDiscount = 0
        var negotiationSurcharge = 0
        if negotiateFareEnabled, let target = negotiatedTargetCDF, target > 0 {
            let baseline = MockFares.quote(
                distanceMeters: tripRouteDistanceMeters,
                tier: resolved,
                discountCDF: appliedPromoDiscountCDF,
                surgeMultiplier: surgeState.multiplier,
                tollCDF: MockSurge.tollLocal(for: fareMarket, isAirport: airport) + meetAndGreetFee,
                waitingMinutes: waiting,
                market: fareMarket,
                isAirportZone: airport,
                bookingType: booking
            )
            let baseTotal = baseline.breakdown.totalCDF
            if target < baseTotal {
                negotiationDiscount = baseTotal - target
            } else if target > baseTotal {
                negotiationSurcharge = target - baseTotal
            }
        }
        return MockFares.quote(
            distanceMeters: tripRouteDistanceMeters,
            tier: resolved,
            discountCDF: appliedPromoDiscountCDF + negotiationDiscount,
            surgeMultiplier: surgeState.multiplier,
            tollCDF: MockSurge.tollLocal(for: fareMarket, isAirport: airport) + meetAndGreetFee + negotiationSurcharge,
            waitingMinutes: waiting,
            market: fareMarket,
            isAirportZone: airport,
            bookingType: booking
        )
    }

    func setNegotiateFareEnabled(_ enabled: Bool) {
        negotiateFareEnabled = enabled
        if enabled {
            if negotiatedTargetCDF == nil, let total = estimatedBreakdown()?.totalCDF {
                negotiatedTargetCDF = total
            }
        } else {
            negotiatedTargetCDF = nil
        }
        farePreview = estimatedBreakdown()
    }

    func setNegotiatedTargetCDF(_ value: Int) {
        let baseline = baselineFareTotalCDF() ?? value
        let lower = Int(Double(baseline) * 0.85)
        let upper = Int(Double(baseline) * 1.15)
        negotiatedTargetCDF = min(max(value, lower), upper)
        farePreview = estimatedBreakdown()
    }

    private func baselineFareTotalCDF() -> Int? {
        let resolved = selectedTier
        guard let resolved, dropoff != nil else { return nil }
        let waiting = stops.isEmpty ? 0 : stops.count * Self.waitMinutesPerStop
        let airport = MockSurge.isAirportTrip(pickup: pickup, dropoff: dropoff)
        let booking: PricingInput.BookingType = {
            if scheduleForLater != nil { return .scheduled }
            if bookOnCompanyWallet { return .corporate }
            if resolved.id == "executive" || vipExecutiveTransfer || meetAndGreetEnabled {
                return .executive
            }
            return .onDemand
        }()
        return MockFares.quote(
            distanceMeters: tripRouteDistanceMeters,
            tier: resolved,
            discountCDF: appliedPromoDiscountCDF,
            surgeMultiplier: surgeState.multiplier,
            tollCDF: MockSurge.tollLocal(for: fareMarket, isAirport: airport) + meetAndGreetServiceFeeCDF,
            waitingMinutes: waiting,
            market: fareMarket,
            isAirportZone: airport,
            bookingType: booking
        ).breakdown.totalCDF
    }

    /// Meet-and-greet surcharge (name board / door greeting) on top of Executive fare.
    private var meetAndGreetServiceFeeCDF: Int {
        guard meetAndGreetEnabled else { return 0 }
        switch fareMarket {
        case .kenya: return 200
        case .drc, .both: return 4_500
        }
    }

    var canConfirmRequest: Bool {
        guard dropoff != nil, selectedTier != nil else { return false }
        if bookForSomeoneElse {
            let nameOK = !passengerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let phoneOK = passengerPhone.filter(\.isNumber).count >= 7
            return nameOK && phoneOK
        }
        return true
    }

    func confirmRequest() {
        guard canConfirmRequest, let dropoff, let selectedTier else { return }
        // Any future schedule reserves; matches the "Reserve" CTA (do not start searching).
        if let when = scheduleForLater, when > Date() {
            let price = max(
                selectedTier.priceCDF - appliedPromoDiscountCDF,
                AppLocale.minimumFareLocal(for: fareMarket)
            )
            reservedTrips.insert(
                ReservedTrip(
                    id: UUID().uuidString,
                    pickupName: pickup.name,
                    dropoffName: dropoff.name,
                    stopNames: stops.map(\.name),
                    tierName: selectedTier.name,
                    when: when,
                    priceCDF: price,
                    priceUSD: AppLocale.usdFromLocal(price, market: fareMarket),
                    paymentMethod: paymentMethod,
                    status: scheduleReminderEnabled ? .reminderSet : .confirmed,
                    reminderEnabled: scheduleReminderEnabled,
                    preferences: currentRidePreferences,
                    promoCode: appliedPromoDiscountCDF > 0 ? promoCode.uppercased() : nil,
                    passengerName: bookForSomeoneElse && !passengerName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? passengerName
                        : nil
                ),
                at: 0
            )
            ReservedTripStore.save(reservedTrips)
            refreshReservationStatuses()
            let whenLabel = when.formatted(date: .abbreviated, time: .shortened)
            let code = reservedTrips.first?.confirmationCode ?? ""
            reservationConfirmationMessage = "Ride reserved for \(whenLabel). Confirmation \(code)."
            notifications?.postTripUpdate(
                title: "Ride reserved",
                body: "Pickup \(whenLabel) · \(pickup.name) → \(dropoff.name). Code \(code)."
            )
            resetBookingDraft(keepHistory: true)
            phase = .idle
            return
        }
        phase = .searching
        searchAttemptCount = 0
        matchingStatus = .searching
        lastCancellation = nil
        searchStartedAt = Date()
        driverAssignedAt = nil
        estimatedMatchingSeconds = 10
        searchMessage = "Looking for nearby \(selectedTier.name) drivers…"
        seedNearbyVehicles()
        startSearchLifecycle(dropoff: dropoff, tier: selectedTier)
    }

    /// Rider taps Retry after a no-drivers outcome.
    func retrySearch() {
        guard phase == .searching,
              matchingStatus == .noDrivers,
              let dropoff,
              let selectedTier
        else { return }
        searchAttemptCount += 1
        matchingStatus = .retrying
        searchStartedAt = Date()
        estimatedMatchingSeconds = 6
        searchMessage = "Trying nearby drivers again…"
        seedNearbyVehicles()
        startSearchLifecycle(dropoff: dropoff, tier: selectedTier)
    }

    func dismissCancellationBanner() {
        lastCancellation = nil
    }

    func confirmBoarding() {
        guard phase == .driverArrived, let trip = activeTrip else { return }
        let requirePIN = UserDefaults.standard.object(forKey: "vuum.safety.requirePIN") as? Bool ?? true
        if requirePIN {
            let entered = boardingPINEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard entered == trip.tripPIN else {
                boardingPINRejected = true
                return
            }
        }
        boardingPINRejected = false
        boardingPINEntry = ""
        startInTrip()
    }

    func sendChat(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isChatAvailable else { return }
        chatMessages.append(
            ChatMessage(sender: "You", text: trimmed, isRider: true)
        )
        scheduleDriverReply(to: trimmed)
    }

    /// Opens `tel:` for the assigned driver when a number exists; otherwise no-ops silently.
    func callDriver() {
        DriverCallHelper.placeCall(to: activeTrip?.driver.phone)
    }

    func markChatRead() {
        unreadChatCount = 0
    }

    func setChatPresented(_ presented: Bool) {
        chatPresented = presented
        if presented {
            unreadChatCount = 0
        }
    }

    private func clearChatThread() {
        chatReplyTask?.cancel()
        chatReplyTask = nil
        driverIsTyping = false
        chatMessages = []
        unreadChatCount = 0
        chatPresented = false
        chatTripID = nil
    }

    private func appendDriverChat(_ text: String) {
        guard activeTrip != nil else { return }
        switch phase {
        case .matched, .driverEnRoute, .driverArrived, .inTrip:
            break
        default:
            return
        }
        chatMessages.append(
            ChatMessage(
                sender: activeTrip?.driver.name ?? "Driver",
                text: text,
                isRider: false
            )
        )
        if !chatPresented {
            unreadChatCount += 1
        }
    }

    private func scheduleDriverReply(to riderText: String) {
        chatReplyTask?.cancel()
        let tripID = chatTripID
        let delayNs = UInt64.random(in: 900_000_000...2_200_000_000)
        chatReplyTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, self.chatTripID == tripID else { return }
            self.driverIsTyping = true
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled, self.chatTripID == tripID else {
                self.driverIsTyping = false
                return
            }
            self.driverIsTyping = false
            self.appendDriverChat(self.driverReply(for: riderText))
        }
    }

    private func scheduleProactiveDriverMessage(_ text: String, after delayNs: UInt64) {
        let tripID = chatTripID
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled, self.chatTripID == tripID else { return }
            self.driverIsTyping = true
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, self.chatTripID == tripID else {
                self.driverIsTyping = false
                return
            }
            self.driverIsTyping = false
            self.appendDriverChat(text)
        }
    }

    private func driverReply(for riderText: String) -> String {
        let lower = riderText.lowercased()
        let plate = activeTrip?.driver.plate ?? "my car"
        let pickup = activeTrip?.pickup.name ?? "the pickup"
        let profileLines = activeTrip?.driver.chatReplyLines ?? []

        if lower.contains("where") || lower.contains("location") || lower.contains("pin") {
            return "I'm heading to \(pickup). Look for plate \(plate)."
        }
        if lower.contains("outside") || lower.contains("here") || lower.contains("waiting") {
            return "Perfect — pulling up now. Wave when you see \(plate)."
        }
        if lower.contains("late") || lower.contains("minute") || lower.contains("coming") {
            return "No rush — I'll wait at the pin."
        }
        if lower.contains("gate") || lower.contains("entrance") || lower.contains("door") {
            return "Got it. I'll meet you there."
        }
        if lower.contains("ac") || lower.contains("quiet") || lower.contains("music") {
            return "Understood — adjusting now."
        }
        if lower.contains("thank") {
            return "You're welcome."
        }

        if !profileLines.isEmpty, Bool.random() {
            return profileLines.randomElement() ?? profileLines[0]
        }

        switch phase {
        case .driverArrived:
            return [
                "I'm here at the pin. Share the trip PIN when you're ready.",
                "Parked nearby — look for \(plate).",
                "Ready when you are.",
            ].randomElement()!
        case .inTrip:
            return [
                "On it — we'll take the clearer route.",
                "Traffic looks fine from here.",
                "I'll update you if anything changes.",
            ].randomElement()!
        default:
            return profileLines.randomElement() ?? [
                "On my way — see you shortly.",
                "Traffic is light, arriving soon.",
                "I'm at the pin. Look for \(plate).",
            ].randomElement()!
        }
    }

    func requestSOS(coordinate: CLLocationCoordinate2D? = nil) {
        sosRequested = true
        sosRequestedAt = Date()
        safetyTeamNotified = false
        incidentFlagged = true
        notifications?.postSafetyEvent(
            title: "Emergency help requested",
            body: TripShare.sosDetailBody(for: activeTrip, coordinate: coordinate)
        )
        sosNotifyTask?.cancel()
        sosNotifyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard let self, !Task.isCancelled, self.sosRequested else { return }
            self.safetyTeamNotified = true
        }
    }

    func dismissTripShareReminder() {
        showTripShareReminder = false
    }

    func cancelSearch(reason: String? = nil) {
        let note = normalizedCancelReason(reason)
        recordCancellation(reason: note, feeLocal: 0, wasFree: true)
        finalizeTripAudio()
        stopPickupWaitTicker()
        cancelInFlightGoogleWork()
        cancelLifecycle()
        searchStartedAt = nil
        driverAssignedAt = nil
        matchingStatus = .idle
        searchAttemptCount = 0
        phase = .choosingRide
        activeTrip = nil
        clearChatThread()
        clearRouteDeviationState()
        sosRequested = false
        sosRequestedAt = nil
        safetyTeamNotified = false
        showTripShareReminder = false
        incidentFlagged = false
    }

    func cancelActiveTrip(reason: String? = nil) {
        let cancelNote = normalizedCancelReason(reason)
        let fee = cancellationFeeLocal
        let wasFree = isCancellationFree
        recordCancellation(reason: cancelNote, feeLocal: fee, wasFree: wasFree)
        if let trip = activeTrip {
            if phase == .matched || phase == .driverEnRoute || phase == .driverArrived {
                fieldSales?.flagCancelledAfterMatch(
                    tripId: trip.id,
                    tripLabel: "\(trip.pickup.name) → \(trip.dropoff.name)"
                )
            }
            var fare = trip.fare
            if fee > 0 {
                // Surface the cancel fee on the cancelled receipt total for Activity.
                fare = FareBreakdown(
                    baseFareCDF: fare.baseFareCDF,
                    distanceFareCDF: fare.distanceFareCDF,
                    timeFareCDF: fare.timeFareCDF,
                    bookingFeeCDF: fare.bookingFeeCDF,
                    waitingFareCDF: fare.waitingFareCDF,
                    surgeMultiplier: fare.surgeMultiplier,
                    surgeFareCDF: fare.surgeFareCDF,
                    tollCDF: fare.tollCDF,
                    serviceFeeCDF: fare.serviceFeeCDF,
                    discountCDF: fare.discountCDF,
                    taxCDF: fare.taxCDF,
                    subtotalCDF: fare.subtotalCDF + fee,
                    totalCDF: fee,
                    totalUSD: AppLocale.usdFromLocal(fee, market: fareMarket),
                    distanceKm: fare.distanceKm,
                    durationMinutes: fare.durationMinutes,
                    minimumFareApplied: false
                )
            }
            let receipt = TripReceipt(
                id: trip.id.isEmpty ? UUID().uuidString : trip.id,
                date: Date(),
                pickupName: trip.pickup.name,
                dropoffName: trip.dropoff.name,
                stopNames: trip.stops.map(\.name),
                driverName: trip.driver.name,
                vehicle: trip.driver.vehicle,
                plate: trip.driver.plate,
                tierName: trip.tier.name,
                paymentMethod: trip.paymentMethod,
                status: .cancelled,
                fare: fare,
                rating: nil,
                cancelReason: cancelNote
            )
            tripHistory.insert(receipt, at: 0)
            TripHistoryStore.save(tripHistory)
        }
        finalizeTripAudio()
        stopPickupWaitTicker()
        cancelInFlightGoogleWork()
        cancelLifecycle()
        searchStartedAt = nil
        driverAssignedAt = nil
        matchingStatus = .idle
        resetBookingDraft(keepHistory: true)
        phase = .idle
        seedNearbyVehicles()
    }

    private func normalizedCancelReason(_ reason: String?) -> String {
        let trimmed = reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Cancelled by rider" : trimmed
    }

    private func recordCancellation(reason: String, feeLocal: Int, wasFree: Bool) {
        lastCancellation = CancellationRecord(
            id: UUID().uuidString,
            reason: reason,
            feeLocal: feeLocal,
            wasFree: wasFree,
            phaseRaw: phase.rawValue,
            at: Date()
        )
    }

    func toggleDraftRatingTag(_ tag: String) {
        if draftRatingTags.contains(tag) {
            draftRatingTags.remove(tag)
        } else {
            draftRatingTags.insert(tag)
        }
    }

    func setDraftTip(_ amountCDF: Int) {
        draftTipCDF = max(0, amountCDF)
    }

    func submitRatingAndFinish() {
        persistPostTripFeedback(includeRating: true)
        resetToHome()
    }

    /// Leaves Activity history without a star rating (tip still applied if chosen).
    func skipRatingAndFinish() {
        persistPostTripFeedback(includeRating: false)
        resetToHome()
    }

    private func persistPostTripFeedback(includeRating: Bool) {
        guard var receipt = lastReceipt else { return }
        if includeRating {
            receipt.rating = draftRating
        }
        receipt.tipCDF = draftTipCDF
        let note = draftRatingComment.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.feedbackNote = note.isEmpty ? nil : note
        receipt.feedbackTags = draftRatingTags.sorted()
        lastReceipt = receipt
        upsertHistory(receipt)
    }

    private func upsertHistory(_ receipt: TripReceipt) {
        if let idx = tripHistory.firstIndex(where: { $0.id == receipt.id }) {
            tripHistory[idx] = receipt
        } else {
            tripHistory.insert(receipt, at: 0)
        }
        TripHistoryStore.save(tripHistory)
    }

    func resetToHome() {
        cancelLifecycle()
        resetBookingDraft(keepHistory: true)
        lastReceipt = nil
        draftRating = 5
        draftRatingComment = ""
        draftRatingTags = []
        draftTipCDF = 0
        searchStartedAt = nil
        driverAssignedAt = nil
        phase = .idle
        seedNearbyVehicles()
    }

    // MARK: - Diagnostics (hidden tools)

    /// Jumps trip phase for internal QA. Creates a minimal active trip when needed.
    func diagnosticsForcePhase(_ target: TripPhase) {
        cancelLifecycle()
        switch target {
        case .idle:
            resetToHome()
        case .selectingDestination:
            resetBookingDraft(keepHistory: true)
            phase = .selectingDestination
        case .choosingRide:
            if dropoff == nil {
                dropoff = MockPlaces.destinations(for: fareMarket).first
            }
            phase = .choosingRide
            farePreview = estimatedBreakdown()
        case .searching, .matched, .driverEnRoute, .driverArrived, .inTrip, .completed:
            ensureDiagnosticsActiveTrip()
            phase = target
            if target == .completed, let trip = activeTrip {
                finishTrip(trip)
            }
        }
    }

    func diagnosticsClearHistory() {
        tripHistory = []
        TripHistoryStore.save(tripHistory)
        lastReceipt = nil
    }

    private func ensureDiagnosticsActiveTrip() {
        if dropoff == nil {
            dropoff = MockPlaces.destinations(for: fareMarket).first
        }
        if selectedTier == nil {
            selectedTier = availableTiers.first
        }
        guard activeTrip == nil,
              let dest = dropoff,
              let tier = selectedTier ?? availableTiers.first
        else { return }

        let driver = MockDrivers.random(for: tier.vehicleClass, market: fareMarket)
        let route = TripGeo.routePolyline(from: pickup.coordinate, to: dest.coordinate, samples: 24)
        let distance = TripGeo.pathLengthMeters(route)
        let airport = MockSurge.isAirportTrip(pickup: pickup, dropoff: dest)
        let fare = MockFares.breakdown(
            distanceMeters: distance,
            tier: tier,
            discountCDF: appliedPromoDiscountCDF,
            surgeMultiplier: 1,
            tollCDF: MockSurge.tollLocal(for: fareMarket, isAirport: airport),
            waitingMinutes: 0,
            market: fareMarket
        )
        activeTrip = ActiveTrip(
            id: UUID().uuidString,
            pickup: pickup,
            dropoff: dest,
            stops: stops,
            tier: tier,
            driver: driver,
            fare: fare,
            driverCoordinate: pickup.coordinate,
            driverHeading: 0,
            pickupRoute: route,
            tripRoute: route,
            etaMinutes: max(1, tier.etaMinutes),
            distanceRemainingMeters: distance,
            statusHeadline: "Diagnostics trip",
            statusDetail: dest.name,
            tripPIN: "1234",
            paymentMethod: paymentMethod,
            passengerName: nil,
            promoCode: nil,
            preferences: currentRidePreferences
        )
    }

    // MARK: - Lifecycle

    private func resetBookingDraft(keepHistory: Bool) {
        finalizeTripAudio()
        dropoff = nil
        stops = []
        isAddingStop = false
        preferredTierID = nil
        stickyInjectTierID = nil
        selectedTier = nil
        activeTrip = nil
        previewRoute = []
        previewRouteTask?.cancel()
        previewRouteTask = nil
        previewRouteWaypoints = nil
        routeAssignTask?.cancel()
        routeAssignTask = nil
        legRefineTask?.cancel()
        legRefineTask = nil
        destinationRouteGeneration &+= 1
        isRecalculatingTripRoute = false
        destinationChangeNotice = nil
        clearRouteDeviationState()
        clearChatThread()
        sosRequested = false
        sosRequestedAt = nil
        safetyTeamNotified = false
        showTripShareReminder = false
        incidentFlagged = false
        sosNotifyTask?.cancel()
        sosNotifyTask = nil
        reverseGeocodeTask?.cancel()
        reverseGeocodeTask = nil
        promoCode = ""
        appliedPromoDiscountCDF = 0
        promoStatus = .idle
        surgeState = .inactive
        farePreview = nil
        bookForSomeoneElse = false
        passengerName = ""
        passengerPhone = ""
        scheduleForLater = nil
        scheduleReminderEnabled = true
        preferQuietRide = false
        accessibilityNotes = ""
        negotiateFareEnabled = false
        negotiatedTargetCDF = nil
        bookOnCompanyWallet = false
        vipExecutiveTransfer = false
        meetAndGreetEnabled = false
        meetAndGreetSignName = ""
        meetAndGreetDoorInstruction = ""
        driverSpeedKmh = 0
        automaticSafetyNotice = nil
        tripPurpose = ""
        packageNotes = ""
        hourlyDurationHours = 0
        boardingPINEntry = ""
        boardingPINRejected = false
        if paymentMethod == .companyWallet {
            paymentMethod = .cash
        }
        if !keepHistory {
            tripHistory = []
        }
    }

    private func applyPreferredTierIfNeeded() {
        guard stickyInjectTierID == nil else { return }
        defer { preferredTierID = nil }
        guard let preferredTierID,
              let match = availableTiers.first(where: { $0.id == ServiceProductID.canonical(preferredTierID) })
                ?? availableTiers.first(where: { $0.id == preferredTierID })
        else { return }
        selectedTier = match
    }

    private func clearPreviewRoute() {
        previewRouteTask?.cancel()
        previewRouteTask = nil
        previewRouteWaypoints = nil
        previewRoute = []
    }

    private func refreshPreviewRoute() {
        let waypoints = tripWaypoints
        guard waypoints.count >= 2 else {
            clearPreviewRoute()
            return
        }
        // §54: identical waypoints + outstanding or completed preview → do not re-hit Google.
        if previewRouteWaypoints == waypoints {
            if previewRouteTask != nil { return }
            if !previewRoute.isEmpty { return }
        }
        previewRouteTask?.cancel()
        previewRouteWaypoints = waypoints
        // Immediate synthetic path so the map never blanks while Directions loads.
        previewRoute = RouteEngine.synthetic(through: waypoints).coordinates
        previewRouteTask = Task { [weak self] in
            let built = await RouteEngine.route(through: waypoints)
            await MainActor.run {
                guard let self, !Task.isCancelled else { return }
                guard self.phase == .choosingRide || self.phase == .searching else { return }
                // Ignore stale responses if pickup/stops/dropoff changed mid-flight.
                guard self.tripWaypoints == waypoints else { return }
                self.previewRoute = built.coordinates
                self.previewRouteTask = nil
                self.refreshTierPricing()
            }
        }
    }

    /// Stops capture and deletes the temp file unless the rider flagged an incident.
    private func finalizeTripAudio() {
        if incidentFlagged {
            audioRecorder.retainRecordingFile()
        } else {
            audioRecorder.deleteRecording()
        }
    }

    func setBookOnCompanyWallet(_ enabled: Bool) {
        if enabled {
            let account = MockCorporate.miningCo
            let fareCDF = selectedTier?.priceCDF ?? 0
            guard account.remainingSpendCDF > 0 else {
                bookOnCompanyWallet = false
                if paymentMethod == .companyWallet {
                    paymentMethod = paymentStore?.selectedMethod ?? .cash
                }
                return
            }
            if fareCDF > 0, !account.canCoverFare(cdf: fareCDF) {
                bookOnCompanyWallet = false
                if paymentMethod == .companyWallet {
                    paymentMethod = paymentStore?.selectedMethod ?? .cash
                }
                return
            }
            bookOnCompanyWallet = true
            paymentMethod = .companyWallet
        } else {
            bookOnCompanyWallet = false
            paymentMethod = paymentStore?.selectedMethod ?? .cash
        }
        refreshZoneContext()
        if phase == .choosingRide || dropoff != nil {
            refreshTierPricing()
        } else {
            refreshAvailableTiers(distanceMeters: 4_500)
        }
    }

    func setVIPExecutiveTransfer(_ enabled: Bool) {
        vipExecutiveTransfer = enabled
        if !enabled {
            meetAndGreetEnabled = false
            meetAndGreetSignName = ""
            meetAndGreetDoorInstruction = ""
            tripPurpose = ""
        }
        refreshZoneContext()
        refreshAvailableTiers(distanceMeters: dropoff == nil ? 4_500 : tripRouteDistanceMeters)
        guard enabled else { return }
        if let executive = availableTiers.first(where: { $0.id == "executive" }) {
            selectedTier = executive
        }
    }

    func setMeetAndGreetEnabled(_ enabled: Bool) {
        meetAndGreetEnabled = enabled
        if enabled {
            vipExecutiveTransfer = true
            if let executive = availableTiers.first(where: { $0.id == "executive" }) {
                selectedTier = executive
            }
        } else {
            meetAndGreetSignName = ""
            meetAndGreetDoorInstruction = ""
        }
        updateFarePreview()
    }

    private func refreshZoneContext() {
        zoneContext = ServiceZoneCatalog.resolve(
            place: pickup,
            market: fareMarket,
            accountType: riderAccountType
        )
        surgeState = MockSurge.state(
            pickup: pickup,
            dropoff: dropoff,
            market: fareMarket,
            accountType: riderAccountType
        )
        if !surgeState.isActive, zoneContext.surgeMultiplier > 1.001 {
            surgeState = SurgeState(
                multiplier: zoneContext.surgeMultiplier,
                label: zoneContext.surgeLabel,
                zoneId: zoneContext.primaryZone?.id ?? zoneContext.cityId
            )
        }
    }

    private func refreshAvailableTiers(distanceMeters: Double) {
        let raw = MockFares.tiers(
            for: distanceMeters,
            market: fareMarket,
            surgeMultiplier: surgeState.multiplier,
            stopCount: stops.count
        )
        let allowed = zoneContext.availableServiceIDs
        var filtered = raw.filter { zoneContext.allows(serviceID: $0.id) }
        // Airport product only when zone (or trip endpoints) warrant it.
        if !zoneContext.isAirportArea && !MockSurge.isAirportTrip(pickup: pickup, dropoff: dropoff) {
            filtered.removeAll { $0.id == ServiceProductID.airport }
        } else if MockSurge.isAirportTrip(pickup: pickup, dropoff: dropoff),
                  !filtered.contains(where: { $0.id == ServiceProductID.airport }),
                  let airportTier = raw.first(where: { $0.id == ServiceProductID.airport }) {
            filtered.append(airportTier)
        }
        // Sticky inject from product sheets stays visible even if zone would hide it.
        if let sticky = stickyInjectTierID {
            if let rebuilt = ProductCatalogTiers.rebuild(
                id: sticky,
                distanceMeters: distanceMeters,
                hourlyHours: hourlyDurationHours,
                market: fareMarket
            ) {
                if let index = filtered.firstIndex(where: { $0.id == rebuilt.id }) {
                    filtered[index] = rebuilt
                } else {
                    filtered.insert(rebuilt, at: 0)
                }
            } else if let match = raw.first(where: { $0.id == sticky }),
                      !filtered.contains(where: { $0.id == sticky }) {
                filtered.insert(match, at: 0)
            }
        }
        if filtered.isEmpty, !allowed.isEmpty {
            filtered = raw.filter { $0.id == ServiceProductID.vuum || $0.id == ServiceProductID.comfort }
        }
        if filtered.isEmpty {
            filtered = raw
        }
        availableTiers = filtered
    }

    private func refreshTierPricing() {
        refreshZoneContext()
        guard dropoff != nil else {
            refreshAvailableTiers(distanceMeters: 4_500)
            farePreview = nil
            return
        }
        refreshAvailableTiers(distanceMeters: tripRouteDistanceMeters)
        if let sticky = stickyInjectTierID,
           let match = availableTiers.first(where: { $0.id == sticky }) {
            selectedTier = match
        } else if let preferred = preferredTierID,
                  let match = availableTiers.first(where: { $0.id == ServiceProductID.canonical(preferred) })
                    ?? availableTiers.first(where: { $0.id == preferred }) {
            selectedTier = match
        } else if let selected = selectedTier,
                  let match = availableTiers.first(where: { $0.id == selected.id }) {
            selectedTier = match
        } else {
            selectedTierDefault()
        }
        updateFarePreview()
    }

    private func updateFarePreview() {
        farePreview = estimatedBreakdown()
    }

    private func selectedTierDefault() {
        selectedTier = availableTiers.first
    }

    private func startSearchLifecycle(dropoff: Place, tier: RideTier) {
        cancelLifecycle()
        let generation = lifecycleGeneration
        let attempt = searchAttemptCount
        let accelerated = testingAcceleratedLifecycle
        let totalTicks = accelerated ? 1 : (attempt == 0 ? 9 : 5)
        let tickNanos: UInt64 = accelerated ? 40_000_000 : 1_000_000_000
        estimatedMatchingSeconds = totalTicks
        if matchingStatus != .retrying {
            matchingStatus = .searching
        }
        lifecycleTask = Task { [weak self] in
            guard let self else { return }
            for remaining in stride(from: totalTicks - 1, through: 0, by: -1) {
                try? await Task.sleep(nanoseconds: tickNanos)
                guard !Task.isCancelled else { return }
                let keepGoing = await MainActor.run { () -> Bool in
                    guard self.lifecycleGeneration == generation, self.phase == .searching else { return false }
                    self.estimatedMatchingSeconds = remaining
                    let elapsed = totalTicks - remaining
                    if !accelerated, attempt == 0, elapsed == 3 {
                        self.matchingStatus = .delayed
                        self.searchMessage = "Connection is slow — still searching…"
                    } else if !accelerated, elapsed == (attempt == 0 ? 5 : 2) {
                        self.matchingStatus = attempt == 0 ? .searching : .retrying
                        self.searchMessage = "Matching the closest driver…"
                        self.nudgeNearbyVehicles()
                    } else if remaining == 1, attempt > 0 || !self.simulateNoDriversOnNextSearch {
                        self.searchMessage = "Confirming your driver…"
                    }
                    return true
                }
                guard keepGoing else { return }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.lifecycleGeneration == generation, self.phase == .searching else { return }
                self.estimatedMatchingSeconds = 0
                if attempt == 0, self.simulateNoDriversOnNextSearch {
                    self.simulateNoDriversOnNextSearch = false
                    self.matchingStatus = .noDrivers
                    self.searchMessage = "No drivers available nearby"
                    return
                }
                self.matchingStatus = .idle
                self.simulateNoDriversOnNextSearch = true
                self.assignDriver(dropoff: dropoff, tier: tier)
            }
        }
    }

    private func startPickupWaitTicker() {
        stopPickupWaitTicker()
        pickupWaitSeconds = 0
        pickupWaitChargeLocal = 0
        let generation = lifecycleGeneration
        waitTickerTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                let keepGoing = await MainActor.run { () -> Bool in
                    guard self.phase == .driverArrived else { return false }
                    // generation can advance when approach motion ends; wait ticker is independent.
                    _ = generation
                    self.pickupWaitSeconds += 1
                    let billable = self.billablePickupWaitMinutes
                    self.pickupWaitChargeLocal = billable * MockSurge.waitingPerMinute(for: self.fareMarket)
                    if var trip = self.activeTrip {
                        if self.pickupWaitGraceRemaining > 0 {
                            trip.statusDetail = "Waiting · free for \(self.pickupWaitGraceRemaining)s"
                        } else {
                            let charge = AppLocale.formatPrimary(
                                local: self.pickupWaitChargeLocal,
                                market: self.fareMarket
                            )
                            trip.statusDetail = "Waiting · \(charge) wait time"
                        }
                        self.activeTrip = trip
                    }
                    return true
                }
                if !keepGoing { return }
            }
        }
    }

    private func stopPickupWaitTicker() {
        waitTickerTask?.cancel()
        waitTickerTask = nil
    }

    private func applyPickupWaitToActiveFare() {
        guard var trip = activeTrip else { return }
        let waitMinutes = billablePickupWaitMinutes
        guard waitMinutes > 0 || trip.fare.waitingFareCDF > 0 else { return }
        let stopWait = stops.isEmpty ? 0 : stops.count * Self.waitMinutesPerStop
        let airport = MockSurge.isAirportTrip(pickup: trip.pickup, dropoff: trip.dropoff)
        trip.fare = MockFares.breakdown(
            distanceMeters: TripGeo.pathLengthMeters(trip.tripRoute),
            tier: trip.tier,
            discountCDF: appliedPromoDiscountCDF,
            surgeMultiplier: surgeState.multiplier,
            tollCDF: MockSurge.tollLocal(for: fareMarket, isAirport: airport),
            waitingMinutes: stopWait + waitMinutes,
            market: fareMarket
        )
        activeTrip = trip
    }

    private func assignDriver(dropoff: Place, tier: RideTier) {
        let vehicleClass = tier.vehicleClass
        let pickupETA = max(tier.etaMinutes, VehiclePickupETA.minutes(for: vehicleClass))
        let spawnMeters = TripMotionTiming.approachDistanceMeters(
            etaMinutes: pickupETA,
            vehicleClass: vehicleClass
        )
        let driver = MockDrivers.random(for: vehicleClass, market: fareMarket)
        let angle = Double.random(in: 0..<(2 * .pi))
        let spawned = offset(
            pickup.coordinate,
            northMeters: cos(angle) * spawnMeters,
            eastMeters: sin(angle) * spawnMeters
        )
        let start = nearbyVehicles.first(where: { $0.vehicleClass == vehicleClass })?.coordinate ?? spawned
        var waypoints = [pickup.coordinate]
        waypoints.append(contentsOf: stops.map(\.coordinate))
        waypoints.append(dropoff.coordinate)

        // Resolve road polylines via RouteProvider (Routes → Directions → synthetic).
        searchMessage = "Confirming your driver's route…"
        let generation = lifecycleGeneration
        let capturedPickup = pickup
        let capturedStops = stops
        let capturedPayment = paymentMethod
        let capturedDiscount = appliedPromoDiscountCDF
        let capturedPromo = promoCode
        let capturedNotes = packageNotes
        let capturedHourly = hourlyDurationHours
        let capturedPassenger = bookForSomeoneElse && !passengerName.trimmingCharacters(in: .whitespaces).isEmpty
            ? passengerName
            : nil
        let capturedPrefs = currentRidePreferences
        routeAssignTask?.cancel()
        routeAssignTask = Task { [weak self] in
            // Routes API (traffic-aware) → Directions → synthetic; always drawable.
            let pickupBuilt = await RouteEngine.route(from: start, to: capturedPickup.coordinate)
            guard !Task.isCancelled else { return }
            let tripBuilt = await RouteEngine.route(through: waypoints)
            guard !Task.isCancelled else { return }
            // Prefer live/traffic duration for approach when available; keep class ETA otherwise.
            let approachETA = pickupBuilt.isTrafficAware
                ? max(1, pickupBuilt.durationMinutes)
                : pickupETA
            await MainActor.run {
                guard let self else { return }
                guard self.lifecycleGeneration == generation, self.phase == .searching else { return }
                self.finishAssignDriver(
                    dropoff: dropoff,
                    tier: tier,
                    vehicleClass: vehicleClass,
                    pickupETA: approachETA,
                    driver: driver,
                    start: start,
                    pickupRoute: pickupBuilt.coordinates,
                    tripRoute: tripBuilt.coordinates,
                    tripDistance: tripBuilt.distanceMeters,
                    tripDurationSeconds: tripBuilt.durationSeconds,
                    pickupPlace: capturedPickup,
                    stopPlaces: capturedStops,
                    payment: capturedPayment,
                    discount: capturedDiscount,
                    promoCodeRaw: capturedPromo,
                    notes: capturedNotes,
                    hourlyHours: capturedHourly,
                    passenger: capturedPassenger,
                    prefs: capturedPrefs
                )
            }
        }
    }

    private func finishAssignDriver(
        dropoff: Place,
        tier: RideTier,
        vehicleClass: VehicleClass,
        pickupETA: Int,
        driver: DriverProfile,
        start: GeoPoint,
        pickupRoute: [GeoPoint],
        tripRoute: [GeoPoint],
        tripDistance: Double,
        tripDurationSeconds: TimeInterval,
        pickupPlace: Place,
        stopPlaces: [Place],
        payment: PaymentMethod,
        discount: Int,
        promoCodeRaw: String,
        notes: String,
        hourlyHours: Int,
        passenger: String?,
        prefs: RidePreferences
    ) {
        let waiting = stopPlaces.isEmpty ? 0 : stopPlaces.count * Self.waitMinutesPerStop
        let airport = MockSurge.isAirportTrip(pickup: pickupPlace, dropoff: dropoff)
        surgeState = MockSurge.state(pickup: pickupPlace, dropoff: dropoff)
        let meetFee = meetAndGreetEnabled ? meetAndGreetServiceFeeCDF : 0
        let fare = MockFares.breakdown(
            distanceMeters: tripDistance,
            tier: tier,
            discountCDF: discount,
            surgeMultiplier: surgeState.multiplier,
            tollCDF: MockSurge.tollLocal(for: fareMarket, isAirport: airport) + meetFee,
            waitingMinutes: waiting,
            market: fareMarket
        )
        if case .applied(let code, _, _) = promoStatus {
            promoStore?.consumeUse(for: code)
        }
        let pickupDistance = TripGeo.pathLengthMeters(pickupRoute)
        let pin = String(Int.random(in: 1000...9999))

        var detail = "Arrives in \(TripGeo.formatDuration(minutes: pickupETA))"
        if let summary = prefs.summaryLine {
            detail = "\(detail) · \(summary)"
        }
        let tripThreadID = UUID().uuidString
        activeTrip = ActiveTrip(
            id: tripThreadID,
            pickup: pickupPlace,
            dropoff: dropoff,
            stops: stopPlaces,
            tier: tier,
            driver: driver,
            fare: fare,
            driverCoordinate: start,
            driverHeading: TripGeo.bearingDegrees(from: start, to: pickupPlace.coordinate),
            pickupRoute: pickupRoute,
            tripRoute: tripRoute,
            routeDurationSeconds: max(tripDurationSeconds, 0),
            etaMinutes: pickupETA,
            distanceRemainingMeters: pickupDistance,
            statusHeadline: "\(driver.name) accepted your ride",
            statusDetail: detail,
            tripPIN: pin,
            paymentMethod: payment,
            passengerName: passenger,
            promoCode: discount > 0 ? promoCodeRaw.uppercased() : nil,
            preferences: prefs
        )
        chatTripID = tripThreadID
        showTripShareReminder = TripShare.shareByDefaultEnabled
        var opening: [ChatMessage] = [
            ChatMessage(
                sender: driver.name,
                text: "\(driver.resolvedChatOpening) ETA \(TripGeo.formatDuration(minutes: pickupETA)).",
                isRider: false
            )
        ]
        if prefs.quietRide {
            opening.append(
                ChatMessage(
                    sender: "You",
                    text: "Please keep the ride quiet — minimal conversation and soft music.",
                    isRider: true
                )
            )
        }
        let a11y = prefs.accessibilityNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !a11y.isEmpty {
            opening.append(
                ChatMessage(
                    sender: "You",
                    text: "Accessibility note: \(a11y)",
                    isRider: true
                )
            )
        }
        if !notes.isEmpty {
            let label = vipExecutiveTransfer ? "Driver notes" : "Package notes"
            opening.append(
                ChatMessage(
                    sender: "You",
                    text: "\(label): \(notes)",
                    isRider: true
                )
            )
        }
        if meetAndGreetEnabled {
            var meetParts: [String] = ["Meet-and-greet"]
            let sign = meetAndGreetSignName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sign.isEmpty {
                meetParts.append("name board \"\(sign)\"")
            }
            let door = meetAndGreetDoorInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
            if !door.isEmpty {
                meetParts.append(door)
            }
            opening.append(
                ChatMessage(
                    sender: "You",
                    text: meetParts.joined(separator: " · "),
                    isRider: true
                )
            )
        }
        let purpose = tripPurpose.trimmingCharacters(in: .whitespacesAndNewlines)
        if !purpose.isEmpty {
            opening.append(
                ChatMessage(
                    sender: "You",
                    text: "Trip purpose: \(purpose)",
                    isRider: true
                )
            )
        }
        if hourlyHours > 0 {
            opening.append(
                ChatMessage(
                    sender: "You",
                    text: "Hourly booking · \(hourlyHours) hr",
                    isRider: true
                )
            )
        }
        chatMessages = opening
        unreadChatCount = chatPresented ? 0 : 1
        driverIsTyping = false
        stopNearbyMotion()
        nearbyVehicles = []
        searchStartedAt = nil
        driverAssignedAt = Date()
        routeProgress = 0
        motionSimulationKind = nil
        motionBaselineETAMinutes = pickupETA
        phase = .matched
        applyAutomaticSafetyActivation(for: activeTrip)

        let approachDuration = testingAcceleratedLifecycle
            ? 0.28
            : TripMotionTiming.approachSimulationSeconds(for: vehicleClass)
        let matchedHoldNanos: UInt64 = testingAcceleratedLifecycle ? 40_000_000 : 900_000_000
        let generation = lifecycleGeneration
        lifecycleTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: matchedHoldNanos)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.lifecycleGeneration == generation, self.phase == .matched else { return }
                self.phase = .driverEnRoute
                self.syncLiveETARefresh()
                if var trip = self.activeTrip {
                    trip.statusHeadline = L10n.format("trip.driver_en_route", trip.driver.name)
                    trip.statusDetail = "Arrives in \(TripGeo.formatDuration(minutes: pickupETA)) · \(TripGeo.formatDistance(pickupDistance))"
                    self.activeTrip = trip
                }
                self.beginMotion(
                    path: pickupRoute,
                    duration: approachDuration,
                    kind: .toPickup,
                    baselineETA: pickupETA
                )
            }
        }
    }

    private func beginMotion(
        path: [GeoPoint],
        duration: TimeInterval,
        kind: MotionKind,
        baselineETA: Int
    ) {
        cancelLifecycle()
        motionPath = path
        motionDuration = duration
        motionFromFraction = 0
        motionToFraction = 1
        motionKind = kind
        motionBaselineETAMinutes = baselineETA
        motionStart = Date()
        routeProgress = 0
        switch kind {
        case .toPickup:
            motionSimulationKind = .approachingPickup
        case .toStop:
            motionSimulationKind = .enRouteToDropoff
        case .toDropoff:
            motionSimulationKind = .enRouteToDropoff
        }
        let generation = lifecycleGeneration
        lifecycleTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let finished = await MainActor.run {
                    self.advanceMotionFrame(generation: generation)
                }
                if finished { break }
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }
    }

    private func advanceMotionFrame(generation: Int) -> Bool {
        guard generation == lifecycleGeneration else { return true }
        guard var trip = activeTrip, let start = motionStart, !motionPath.isEmpty else { return true }
        let elapsed = Date().timeIntervalSince(start)
        let t = min(1, elapsed / max(motionDuration, 0.1))
        let eased = 1 - pow(1 - t, 2)
        let fraction = motionFromFraction + (motionToFraction - motionFromFraction) * eased
        let sample = TripGeo.pointAlong(path: motionPath, fraction: fraction)
        var displayPoint = sample.point
        switch motionKind {
        case .toPickup:
            break
        case .toStop, .toDropoff:
            // Brief lateral drift so corridor detection can surface during live playback.
            displayPoint = presentationRouteWiggle(
                on: sample.point,
                headingDegrees: sample.heading,
                wallProgress: t
            )
        }
        trip.driverCoordinate = displayPoint
        // Cap turn rate so polyline corners don't spin the marker.
        trip.driverHeading = TripGeo.smoothHeading(
            current: trip.driverHeading,
            target: sample.heading,
            maxStepDegrees: 32
        )
        routeProgress = fraction

        let remaining = TripGeo.remainingDistanceMeters(path: motionPath, fraction: fraction)
        trip.distanceRemainingMeters = remaining
        trip.waitingAtStopIndex = nil
        let classSpeed = Int(VehiclePickupETA.tripSpeedKmh(for: trip.tier.vehicleClass).rounded())
        // Ease displayed speed: approach starts slower, trip cruises near class speed.
        driverSpeedKmh = max(8, Int(Double(classSpeed) * (0.55 + 0.45 * eased)))

        switch motionKind {
        case .toPickup:
            trip.etaMinutes = TripMotionTiming.displayedETAMinutes(
                baseline: motionBaselineETAMinutes,
                fraction: fraction
            )
            trip.statusHeadline = L10n.format("trip.driver_en_route", trip.driver.name)
            trip.statusDetail = "Arrives in \(TripGeo.formatDuration(minutes: trip.etaMinutes)) · \(TripGeo.formatDistance(remaining))"
            activeTrip = trip
            clearRouteDeviationState()
            if t >= 1 {
                phase = .driverArrived
                motionSimulationKind = nil
                routeProgress = 1
                trip.statusHeadline = L10n.t("trip.driver_arrived")
                trip.statusDetail = L10n.format("trip.meet_at_pickup", trip.driver.name)
                trip.etaMinutes = 0
                trip.distanceRemainingMeters = 0
                boardingPINEntry = ""
                boardingPINRejected = false
                driverSpeedKmh = 0
                activeTrip = trip
                startPickupWaitTicker()
                scheduleProactiveDriverMessage(
                    "I've arrived. Look for \(trip.driver.plate) and share the trip PIN when you're ready.",
                    after: 1_200_000_000
                )
                return true
            }
        case .toStop(let index):
            // Prefer Google/route baseline remaining (same path as approach), not fixedSpeed.
            trip.etaMinutes = TripMotionTiming.displayedETAMinutes(
                baseline: motionBaselineETAMinutes,
                fraction: fraction
            )
            let stopName = trip.stops.indices.contains(index) ? trip.stops[index].name : "Stop \(index + 1)"
            trip.statusHeadline = "Next stop · \(stopName)"
            trip.statusDetail = "\(TripGeo.formatDuration(minutes: trip.etaMinutes)) · \(TripGeo.formatDistance(remaining))"
            activeTrip = trip
            updateRouteDeviation(position: displayPoint, expectedRoute: trip.tripRoute)
            if t >= 1 {
                beginWaitingAtStop(index)
                return true
            }
        case .toDropoff:
            trip.etaMinutes = TripMotionTiming.displayedETAMinutes(
                baseline: motionBaselineETAMinutes,
                fraction: fraction
            )
            trip.statusHeadline = L10n.t("trip.heading_to_destination")
            trip.statusDetail = "\(TripGeo.formatDuration(minutes: trip.etaMinutes)) · \(TripGeo.formatDistance(remaining)) remaining"
            activeTrip = trip
            updateRouteDeviation(position: displayPoint, expectedRoute: trip.tripRoute)
            if t >= 1 {
                motionSimulationKind = nil
                routeProgress = 1
                clearRouteDeviationState()
                finishTrip(trip)
                return true
            }
        }
        return false
    }

    /// Soft lateral offset mid-leg so the corridor monitor can raise a realistic notice.
    private func presentationRouteWiggle(
        on point: GeoPoint,
        headingDegrees: Double,
        wallProgress: Double
    ) -> GeoPoint {
        // Flat plateau (~20–55% wall time) so ~6s persistence fits on short legs.
        let rampIn = 0.18
        let holdStart = 0.22
        let holdEnd = 0.52
        let rampOut = 0.58
        guard wallProgress > rampIn, wallProgress < rampOut else { return point }

        let envelope: Double
        if wallProgress < holdStart {
            envelope = (wallProgress - rampIn) / max(holdStart - rampIn, 0.01)
        } else if wallProgress > holdEnd {
            envelope = (rampOut - wallProgress) / max(rampOut - holdEnd, 0.01)
        } else {
            envelope = 1
        }
        let meters = 150 * max(0, min(envelope, 1))
        guard meters > 8 else { return point }
        return TripGeo.offsetPerpendicular(point, headingDegrees: headingDegrees, meters: meters)
    }

    private func updateRouteDeviation(position: GeoPoint, expectedRoute: [GeoPoint]) {
        let snap = routeDeviationMonitor.evaluate(
            position: position,
            expectedRoute: expectedRoute,
            now: Date()
        )
        routeDeviationDistanceMeters = snap.distanceMeters
        if snap.didActivateNotice {
            routeDeviationNoticeDismissed = false
        }
        if !snap.isNoticeActive {
            routeDeviationNoticeDismissed = false
            didPostRouteDeviationNotification = false
            routeDeviationNotice = nil
        } else if routeDeviationNoticeDismissed {
            routeDeviationNotice = nil
        } else {
            routeDeviationNotice = snap.noticeText
        }
        if snap.didActivateNotice, !didPostRouteDeviationNotification {
            didPostRouteDeviationNotification = true
            notifications?.postSafetyEvent(
                title: L10n.Route.deviationTitle,
                body: L10n.Route.deviationBody
            )
        }
    }

    private func clearRouteDeviationState() {
        routeDeviationMonitor.reset()
        routeDeviationNotice = nil
        routeDeviationDistanceMeters = 0
        didPostRouteDeviationNotification = false
        routeDeviationNoticeDismissed = false
    }

    /// Rider dismissed the off-route banner (detection keeps running).
    func dismissRouteDeviationNotice() {
        routeDeviationNotice = nil
        routeDeviationNoticeDismissed = true
    }

    private func startInTrip() {
        guard var trip = activeTrip else { return }
        stopPickupWaitTicker()
        applyPickupWaitToActiveFare()
        clearRouteDeviationState()
        phase = .inTrip
        syncLiveETARefresh()
        trip = activeTrip ?? trip
        trip.waitingAtStopIndex = nil
        activeTrip = trip
        inTripWaypointIndex = 0
        applyAutomaticSafetyActivation(for: trip)
        beginNextInTripLeg(announceStart: true)
    }

    /// Night / long-trip rules can auto-share and start safety recording (SA09).
    private func applyAutomaticSafetyActivation(for trip: ActiveTrip?) {
        let decision = SafetyAutoActivation.evaluate(distanceKm: trip?.fare.distanceKm ?? 0)
        if decision.shouldAutoShare {
            showTripShareReminder = true
        }
        if decision.shouldAutoRecord, canRecordTripAudio, !audioRecorder.isRecording {
            automaticSafetyNotice = decision.reason.map { "Safety recording started · \($0)" }
                ?? "Safety recording started automatically"
            Task { @MainActor in
                if await audioRecorder.startRecording() {
                    notifications?.postRecordingStarted()
                }
            }
        }
    }

    private func beginNextInTripLeg(announceStart: Bool = false) {
        guard var trip = activeTrip else { return }
        var waypoints = [trip.pickup.coordinate]
        waypoints.append(contentsOf: trip.stops.map(\.coordinate))
        waypoints.append(trip.dropoff.coordinate)
        let destIndex = inTripWaypointIndex + 1
        guard destIndex < waypoints.count, inTripWaypointIndex < waypoints.count else {
            finishTrip(trip)
            return
        }
        let from = waypoints[inTripWaypointIndex]
        let to = waypoints[destIndex]
        trip.driverCoordinate = from
        trip.waitingAtStopIndex = nil

        // Reuse assign-time trip polyline (Routes/Directions/synthetic) — avoid recalculating the whole trip.
        let reusedPath: [GeoPoint]
        if trip.tripRoute.count >= 2 {
            reusedPath = TripGeo.subpath(along: trip.tripRoute, from: from, to: to, samples: 40)
        } else {
            reusedPath = RouteEngine.synthetic(from: from, to: to).coordinates
        }
        startInTripLegMotion(
            trip: &trip,
            path: reusedPath,
            from: from,
            destIndex: destIndex,
            waypointCount: waypoints.count,
            announceStart: announceStart,
            durationMinutesOverride: nil
        )

        // When keyed, refine this leg with live road geometry + traffic ETA (early progress only).
        // Capture generation *after* beginMotion (it bumps lifecycleGeneration).
        MapBootstrap.configureIfNeeded()
        guard MapBootstrap.hasAPIKey else { return }
        let generation = lifecycleGeneration
        let legIndex = inTripWaypointIndex
        let vehicleClass = trip.tier.vehicleClass
        legRefineTask?.cancel()
        legRefineTask = Task { [weak self] in
            let live = await RouteEngine.route(from: from, to: to)
            guard !Task.isCancelled else { return }
            guard live.hasRoadGeometry || live.isTrafficAware else { return }
            await MainActor.run {
                guard let self else { return }
                guard !Task.isCancelled,
                      self.lifecycleGeneration == generation,
                      self.phase == .inTrip,
                      self.inTripWaypointIndex == legIndex,
                      self.routeProgress < 0.22,
                      var current = self.activeTrip
                else { return }
                let eta = live.isTrafficAware
                    ? max(1, live.durationMinutes)
                    : TripGeo.etaMinutes(
                        distanceMeters: live.distanceMeters > 0
                            ? live.distanceMeters
                            : TripGeo.pathLengthMeters(live.coordinates),
                        speedKmh: VehiclePickupETA.tripSpeedKmh(for: vehicleClass)
                    )
                self.startInTripLegMotion(
                    trip: &current,
                    path: live.coordinates.count >= 2 ? live.coordinates : reusedPath,
                    from: from,
                    destIndex: destIndex,
                    waypointCount: waypoints.count,
                    announceStart: false,
                    durationMinutesOverride: eta
                )
                if self.legRefineTask?.isCancelled == false {
                    self.legRefineTask = nil
                }
            }
        }
    }

    private func startInTripLegMotion(
        trip: inout ActiveTrip,
        path: [GeoPoint],
        from: GeoPoint,
        destIndex: Int,
        waypointCount: Int,
        announceStart: Bool,
        durationMinutesOverride: Int?
    ) {
        let distance = TripGeo.pathLengthMeters(path)
        let eta: Int
        if let override = durationMinutesOverride {
            eta = max(1, override)
        } else if trip.routeDurationSeconds > 0 {
            let totalMeters = max(TripGeo.pathLengthMeters(trip.tripRoute), 1)
            let scaled = trip.routeDurationSeconds * (distance / totalMeters)
            eta = max(1, Int(ceil(scaled / 60.0)))
        } else {
            eta = TripGeo.etaMinutes(
                distanceMeters: distance,
                speedKmh: VehiclePickupETA.tripSpeedKmh(for: trip.tier.vehicleClass)
            )
        }
        trip.driverCoordinate = from
        trip.distanceRemainingMeters = distance
        trip.etaMinutes = eta

        let isDropoffLeg = destIndex == waypointCount - 1
        if isDropoffLeg {
            trip.statusHeadline = L10n.format("trip.on_the_way", trip.dropoff.name)
            trip.statusDetail = "\(TripGeo.formatDuration(minutes: eta)) · \(TripGeo.formatDistance(distance))"
            activeTrip = trip
            if announceStart {
                scheduleProactiveDriverMessage(
                    "Trip started — heading to \(trip.dropoff.name).",
                    after: 900_000_000
                )
            }
            beginMotion(
                path: path,
                duration: TripMotionTiming.tripSimulationDurationSeconds(displayedETAMinutes: eta),
                kind: .toDropoff,
                baselineETA: eta
            )
        } else {
            let stopIndex = destIndex - 1
            let stopName = trip.stops.indices.contains(stopIndex) ? trip.stops[stopIndex].name : "Stop \(stopIndex + 1)"
            trip.statusHeadline = "Next stop · \(stopName)"
            trip.statusDetail = "\(TripGeo.formatDuration(minutes: eta)) · \(TripGeo.formatDistance(distance))"
            activeTrip = trip
            if announceStart {
                scheduleProactiveDriverMessage(
                    "Trip started — first stop \(stopName).",
                    after: 900_000_000
                )
            }
            beginMotion(
                path: path,
                duration: TripMotionTiming.tripSimulationDurationSeconds(displayedETAMinutes: eta),
                kind: .toStop(stopIndex),
                baselineETA: eta
            )
        }
    }

    private func beginWaitingAtStop(_ index: Int) {
        guard var trip = activeTrip, trip.stops.indices.contains(index) else {
            inTripWaypointIndex += 1
            beginNextInTripLeg()
            return
        }
        cancelLifecycle()
        let stop = trip.stops[index]
        trip.waitingAtStopIndex = index
        trip.driverCoordinate = stop.coordinate
        trip.etaMinutes = 0
        trip.distanceRemainingMeters = 0
        trip.statusHeadline = "Waiting at stop"
        trip.statusDetail = "\(stop.name) · \(Self.waitMinutesPerStop) min wait included"
        activeTrip = trip
        motionSimulationKind = .waitingAtStop
        routeProgress = 1
        updateRouteDeviation(position: stop.coordinate, expectedRoute: trip.tripRoute)
        scheduleProactiveDriverMessage(
            "Stopped at \(stop.name). Continuing shortly.",
            after: 500_000_000
        )
        let generation = lifecycleGeneration
        lifecycleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.waitSimulationSeconds * 1_000_000_000))
            await MainActor.run {
                guard let self, self.lifecycleGeneration == generation else { return }
                self.continueInTripAfterStop(at: index)
            }
        }
    }

    private func continueInTripAfterStop(at index: Int) {
        guard var trip = activeTrip else { return }
        trip.waitingAtStopIndex = nil
        activeTrip = trip
        inTripWaypointIndex = index + 1
        beginNextInTripLeg()
    }

    private func finishTrip(_ trip: ActiveTrip) {
        chatReplyTask?.cancel()
        chatReplyTask = nil
        driverIsTyping = false
        chatTripID = nil
        cancelLifecycle()
        // Stop capture but keep the file until home so post-trip incident reports can attach it.
        audioRecorder.retainRecordingFile()
        phase = .completed
        stopLiveETARefresh()
        var done = trip
        done.driverCoordinate = trip.dropoff.coordinate
        done.distanceRemainingMeters = 0
        done.etaMinutes = 0
        done.statusHeadline = L10n.t("trip.arrived")
        done.statusDetail = trip.dropoff.name
        activeTrip = done

        let receipt = TripReceipt(
            id: trip.id.isEmpty ? UUID().uuidString : trip.id,
            date: Date(),
            pickupName: trip.pickup.name,
            dropoffName: trip.dropoff.name,
            stopNames: trip.stops.map(\.name),
            driverName: trip.driver.name,
            vehicle: trip.driver.vehicle,
            plate: trip.driver.plate,
            tierName: trip.tier.name,
            paymentMethod: trip.paymentMethod,
            status: .completed,
            fare: trip.fare,
            tipCDF: 0,
            rating: nil
        )
        lastReceipt = receipt
        upsertHistory(receipt)
        draftRating = 5
        draftRatingComment = ""
        draftRatingTags = []
        draftTipCDF = 0
        driverAssignedAt = nil

        let market = fareMarket
        let fareLocal = trip.fare.totalCDF
        let fareUSD = trip.fare.totalUSD
        let method = trip.paymentMethod
        let label = "\(trip.pickup.name) → \(trip.dropoff.name)"
        let receiptId = receipt.id
        let tripId = receipt.id
        let durationMinutes = trip.fare.durationMinutes
        Task { [weak paymentStore, weak fieldSales] in
            let tx = await paymentStore?.recordTripPayment(
                tripId: tripId,
                tripLabel: label,
                fareLocal: fareLocal,
                fareUSD: fareUSD,
                market: market,
                method: method,
                receiptId: receiptId
            )
            let paid = tx?.status == .successful
            fieldSales?.evaluateAfterCompletedTrip(
                tripId: tripId,
                tripLabel: label,
                fareCDF: fareLocal,
                durationMinutes: durationMinutes,
                paymentSucceeded: paid,
                paymentMethodPresent: true
            )
        }
    }

    private func cancelLifecycle() {
        stopLiveETARefresh()
        lifecycleGeneration += 1
        lifecycleTask?.cancel()
        lifecycleTask = nil
        motionStart = nil
        motionPath = []
        motionSimulationKind = nil
        routeProgress = 0
    }

    /// Starts/stops optional live ETA refresh for approach / in-trip when policy allows.
    private func syncLiveETARefresh() {
        guard MapTrafficSettings.shouldRefreshETA(lowDataMode: AppPreferences.shared.lowDataMode) else {
            stopLiveETARefresh()
            return
        }
        switch phase {
        case .driverEnRoute, .inTrip:
            break
        default:
            stopLiveETARefresh()
            return
        }
        guard etaRefreshTask == nil else { return }
        let generation = lifecycleGeneration
        etaRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let nanos = UInt64(MapTrafficSettings.etaRefreshIntervalSeconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.lifecycleGeneration == generation else { return }
                    self.performLiveETARefresh()
                }
            }
        }
    }

    private func stopLiveETARefresh() {
        etaRefreshTask?.cancel()
        etaRefreshTask = nil
    }

    /// Re-queries `RouteEngine` for remaining driver?target duration when a Maps key is present.
    private func performLiveETARefresh() {
        guard MapTrafficSettings.shouldRefreshETA(lowDataMode: AppPreferences.shared.lowDataMode) else {
            stopLiveETARefresh()
            return
        }
        guard activeTrip != nil else { return }
        let origin = activeTrip!.driverCoordinate
        let destination: GeoPoint
        switch phase {
        case .driverEnRoute:
            destination = activeTrip!.pickup.coordinate
        case .inTrip:
            let trip = activeTrip!
            if let waiting = trip.waitingAtStopIndex, trip.stops.indices.contains(waiting) {
                destination = trip.stops[waiting].coordinate
            } else if let nextStop = trip.stops.first(where: { stop in
                TripGeo.distanceMeters(from: origin, to: stop.coordinate) > 40
            }) {
                destination = nextStop.coordinate
            } else {
                destination = trip.dropoff.coordinate
            }
        default:
            return
        }
        let generation = lifecycleGeneration
        Task { [weak self] in
            let built = await RouteEngine.route(from: origin, to: destination)
            await MainActor.run {
                guard let self, self.lifecycleGeneration == generation, var live = self.activeTrip else { return }
                // Keep motion-derived ETA when Google is unavailable; only apply live traffic-aware results.
                guard built.isTrafficAware, built.source != .synthetic else { return }
                live.etaMinutes = built.durationMinutes
                live.distanceRemainingMeters = built.distanceMeters
                live.routeDurationSeconds = built.durationSeconds
                self.activeTrip = live
            }
        }
    }
    private var showsNearbyVehicles: Bool {
        switch phase {
        case .idle, .selectingDestination, .choosingRide, .searching:
            return true
        default:
            return false
        }
    }

    private func seedNearbyVehicles() {
        seedNearbyVehicles(preferring: selectedTier?.vehicleClass ?? .standard)
    }

    private func seedNearbyVehicles(preferring preferred: VehicleClass) {
        let base = pickup.coordinate
        var classes: [VehicleClass] = [.standard, .bike, .large, .standard, .standard, .bike]
        // Bias the fleet toward the selected product so match ETA / icons stay coherent.
        classes[0] = preferred
        classes[3] = preferred
        nearbyVehicles = (0..<6).map { index in
            let angle = Double(index) * (.pi / 3.0)
            let radius = 280.0 + Double(index) * 90.0
            return MapVehicle(
                id: "near-\(index)",
                coordinate: offset(base, northMeters: cos(angle) * radius, eastMeters: sin(angle) * radius),
                heading: (angle * 180 / .pi + 90).truncatingRemainder(dividingBy: 360),
                vehicleClass: classes[index]
            )
        }
        startNearbyMotionIfNeeded()
    }

    private func startNearbyMotionIfNeeded() {
        guard showsNearbyVehicles, !nearbyVehicles.isEmpty else {
            stopNearbyMotion()
            return
        }
        guard nearbyMotionTask == nil else { return }
        nearbyMotionTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                guard !Task.isCancelled else { return }
                let keepGoing = await MainActor.run { () -> Bool in
                    guard self.showsNearbyVehicles, !self.nearbyVehicles.isEmpty else {
                        self.stopNearbyMotion()
                        return false
                    }
                    self.nudgeNearbyVehicles()
                    return true
                }
                if !keepGoing { return }
            }
        }
    }

    private func stopNearbyMotion() {
        nearbyMotionTask?.cancel()
        nearbyMotionTask = nil
    }

    private func nudgeNearbyVehicles() {
        let base = pickup.coordinate
        nearbyVehicles = nearbyVehicles.map { vehicle in
            var next = vehicle
            let step = Double.random(in: 22...48)
            let headingRad = vehicle.heading * .pi / 180
            let north = cos(headingRad) * step + Double.random(in: -10...10)
            let east = sin(headingRad) * step + Double.random(in: -10...10)
            var coordinate = offset(vehicle.coordinate, northMeters: north, eastMeters: east)
            if TripGeo.distanceMeters(from: base, to: coordinate) > 1_100 {
                let angle = Double.random(in: 0..<(2 * .pi))
                let radius = Double.random(in: 280...720)
                coordinate = offset(base, northMeters: cos(angle) * radius, eastMeters: sin(angle) * radius)
            }
            next.coordinate = coordinate
            var heading = vehicle.heading + Double.random(in: -18...18)
            heading = heading.truncatingRemainder(dividingBy: 360)
            if heading < 0 { heading += 360 }
            next.heading = heading
            return next
        }
    }

    private func offset(_ point: GeoPoint, northMeters: Double, eastMeters: Double) -> GeoPoint {
        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLon = 111_320.0 * cos(point.latitude * .pi / 180)
        return GeoPoint(
            latitude: point.latitude + northMeters / metersPerDegreeLat,
            longitude: point.longitude + eastMeters / max(metersPerDegreeLon, 1)
        )
    }
}

enum TripHistoryStore {
    private static let key = "vuum.tripHistory.v3"
    private static let legacyKey = "vuum.tripHistory"

    static func load() -> [TripReceipt] {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([TripReceipt].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        if let data = UserDefaults.standard.data(forKey: legacyKey),
           let decoded = try? JSONDecoder().decode([StoredReceipt].self, from: data) {
            let migrated = decoded.map(\.asReceipt)
            save(migrated)
            return migrated
        }
        return MockTripHistory.samples
    }

    static func save(_ receipts: [TripReceipt]) {
        let trimmed = Array(receipts.prefix(40))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

enum ReservationStore {
    private static let key = "vuum.reservations.v1"

    static func load() -> [ReservedTrip] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ReservedTrip].self, from: data)
        else { return [] }
        return decoded.sorted { $0.when < $1.when }
    }

    static func save(_ trips: [ReservedTrip]) {
        if let data = try? JSONEncoder().encode(Array(trips.prefix(20))) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

typealias ReservedTripStore = ReservationStore

private struct StoredReceipt: Codable {
    var id: String
    var date: Date
    var pickupName: String
    var dropoffName: String
    var stopNames: [String]?
    var driverName: String
    var vehicle: String?
    var plate: String?
    var tierName: String
    var paymentMethodRaw: String?
    var statusRaw: String?
    var tipCDF: Int?
    var baseFareCDF: Int?
    var distanceFareCDF: Int?
    var timeFareCDF: Int?
    var bookingFeeCDF: Int?
    var waitingFareCDF: Int?
    var surgeMultiplier: Double?
    var surgeFareCDF: Int?
    var tollCDF: Int?
    var serviceFeeCDF: Int?
    var discountCDF: Int?
    var taxCDF: Int?
    var subtotalCDF: Int?
    var totalCDF: Int
    var totalUSD: Double
    var distanceKm: Double
    var durationMinutes: Int
    var rating: Int?
    var feedbackNote: String?
    var feedbackTags: [String]?
    var cancelReason: String?

    var asReceipt: TripReceipt {
        let method = paymentMethodRaw.flatMap(PaymentMethod.init(rawValue:)) ?? .cash
        let status = statusRaw.flatMap(TripReceiptStatus.init(rawValue:)) ?? .completed
        return TripReceipt(
            id: id,
            date: date,
            pickupName: pickupName,
            dropoffName: dropoffName,
            stopNames: stopNames ?? [],
            driverName: driverName,
            vehicle: vehicle ?? "",
            plate: plate ?? "",
            tierName: tierName,
            paymentMethod: method,
            status: status,
            fare: FareBreakdown(
                baseFareCDF: baseFareCDF ?? 0,
                distanceFareCDF: distanceFareCDF ?? 0,
                timeFareCDF: timeFareCDF ?? 0,
                bookingFeeCDF: bookingFeeCDF ?? 0,
                waitingFareCDF: waitingFareCDF ?? 0,
                surgeMultiplier: surgeMultiplier ?? 1,
                surgeFareCDF: surgeFareCDF ?? 0,
                tollCDF: tollCDF ?? 0,
                serviceFeeCDF: serviceFeeCDF ?? 0,
                discountCDF: discountCDF ?? 0,
                taxCDF: taxCDF ?? 0,
                subtotalCDF: subtotalCDF,
                totalCDF: totalCDF,
                totalUSD: totalUSD,
                distanceKm: distanceKm,
                durationMinutes: durationMinutes
            ),
            tipCDF: tipCDF ?? 0,
            rating: rating,
            feedbackNote: feedbackNote,
            feedbackTags: feedbackTags ?? [],
            cancelReason: cancelReason
        )
    }
}
