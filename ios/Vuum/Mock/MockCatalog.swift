import Foundation

// Local presentation catalogs for places, drivers, fares, and trip history.
// Internal comments may say mock; rider-facing copy must not.

enum MockPlaces {
    /// Market-default map center when GPS is unavailable — not the rider's live pickup.
    /// Do not label these "Current location"; that string is reserved for unresolved GPS.
    static let lubumbashiCenter = Place(
        id: "lub-center",
        name: "Avenue Mobutu",
        subtitle: "Lubumbashi",
        coordinate: GeoPoint(latitude: -11.6644, longitude: 27.4794)
    )

    static let nairobiCenter = Place(
        id: "nbo-center",
        name: "Kenyatta Avenue",
        subtitle: "Nairobi",
        coordinate: GeoPoint(latitude: -1.2864, longitude: 36.8172)
    )

    /// Lubumbashi / Kolwezi catalog (DRC default). Local place suggestions only.
    static let destinationsDRC: [Place] = [
        Place(
            id: "gcm",
            name: "Gare Centrale",
            subtitle: "Lubumbashi",
            coordinate: GeoPoint(latitude: -11.6609, longitude: 27.4826)
        ),
        Place(
            id: "airport",
            name: "Luano International Airport",
            subtitle: "FBM · Lubumbashi",
            coordinate: GeoPoint(latitude: -11.5913, longitude: 27.5308)
        ),
        Place(
            id: "unilu",
            name: "Université de Lubumbashi",
            subtitle: "Campus Kasapa",
            coordinate: GeoPoint(latitude: -11.6147, longitude: 27.4802)
        ),
        Place(
            id: "kenya",
            name: "Kenya Market",
            subtitle: "Lubumbashi",
            coordinate: GeoPoint(latitude: -11.6688, longitude: 27.4751)
        ),
        Place(
            id: "hybride",
            name: "Hybride Mall",
            subtitle: "Lubumbashi",
            coordinate: GeoPoint(latitude: -11.6521, longitude: 27.4915)
        ),
        Place(
            id: "kolwezi-center",
            name: "Kolwezi Centre",
            subtitle: "Lualaba",
            coordinate: GeoPoint(latitude: -10.7148, longitude: 25.4667)
        ),
        Place(
            id: "hotel-karavia",
            name: "Hôtel Karavia",
            subtitle: "Lubumbashi",
            coordinate: GeoPoint(latitude: -11.6554, longitude: 27.4872)
        ),
        Place(
            id: "golf",
            name: "Lubumbashi Golf Club",
            subtitle: "Golf",
            coordinate: GeoPoint(latitude: -11.6402, longitude: 27.4588)
        ),
        Place(
            id: "bel-air",
            name: "Bel Air",
            subtitle: "Lubumbashi",
            coordinate: GeoPoint(latitude: -11.6712, longitude: 27.4620)
        ),
        Place(
            id: "ruashi",
            name: "Ruashi Mining Gate",
            subtitle: "Ruashi · Lubumbashi",
            coordinate: GeoPoint(latitude: -11.6280, longitude: 27.5450)
        ),
        Place(
            id: "zoo",
            name: "Zoo de Lubumbashi",
            subtitle: "Parc zoologique",
            coordinate: GeoPoint(latitude: -11.6480, longitude: 27.4695)
        ),
        Place(
            id: "snel",
            name: "SNEL Siège",
            subtitle: "Avenue Mama Yemo",
            coordinate: GeoPoint(latitude: -11.6625, longitude: 27.4858)
        ),
        Place(
            id: "kolwezi-airport",
            name: "Kolwezi Airport",
            subtitle: "KWZ · Lualaba",
            coordinate: GeoPoint(latitude: -10.7660, longitude: 25.5050)
        ),
        Place(
            id: "kolwezi-gcamines",
            name: "Gécamines Kolwezi",
            subtitle: "Lualaba",
            coordinate: GeoPoint(latitude: -10.7050, longitude: 25.4780)
        ),
        Place(
            id: "marche-kenya",
            name: "Marché de Kenya",
            subtitle: "Kampemba",
            coordinate: GeoPoint(latitude: -11.6705, longitude: 27.4720)
        ),
    ]

    /// Nairobi-centric catalog when market is Kenya.
    static let destinationsKenya: [Place] = [
        Place(
            id: "nbo-jkia",
            name: "Jomo Kenyatta International Airport",
            subtitle: "NBO · Embakasi",
            coordinate: GeoPoint(latitude: -1.3192, longitude: 36.9278)
        ),
        Place(
            id: "nbo-westlands",
            name: "Westlands",
            subtitle: "Nairobi",
            coordinate: GeoPoint(latitude: -1.2670, longitude: 36.8110)
        ),
        Place(
            id: "nbo-cbd",
            name: "Nairobi CBD",
            subtitle: "Central Business District",
            coordinate: GeoPoint(latitude: -1.2833, longitude: 36.8167)
        ),
        Place(
            id: "nbo-karen",
            name: "Karen",
            subtitle: "Nairobi",
            coordinate: GeoPoint(latitude: -1.3197, longitude: 36.7114)
        ),
        Place(
            id: "nbo-kilimani",
            name: "Kilimani",
            subtitle: "Nairobi",
            coordinate: GeoPoint(latitude: -1.2890, longitude: 36.7850)
        ),
        Place(
            id: "nbo-yaya",
            name: "Yaya Centre",
            subtitle: "Argwings Kodhek Rd",
            coordinate: GeoPoint(latitude: -1.2921, longitude: 36.7820)
        ),
        Place(
            id: "nbo-two-rivers",
            name: "Two Rivers Mall",
            subtitle: "Runda",
            coordinate: GeoPoint(latitude: -1.2170, longitude: 36.8020)
        ),
        Place(
            id: "nbo-wilson",
            name: "Wilson Airport",
            subtitle: "WIL · Nairobi",
            coordinate: GeoPoint(latitude: -1.3217, longitude: 36.8148)
        ),
        Place(
            id: "nbo-lavington",
            name: "Lavington",
            subtitle: "Nairobi",
            coordinate: GeoPoint(latitude: -1.2830, longitude: 36.7680)
        ),
        Place(
            id: "nbo-gigiri",
            name: "UN Gigiri",
            subtitle: "United Nations Ave",
            coordinate: GeoPoint(latitude: -1.2340, longitude: 36.8160)
        ),
        Place(
            id: "nbo-jkia-terminals",
            name: "JKIA Terminal 1A",
            subtitle: "Arrivals · Embakasi",
            coordinate: GeoPoint(latitude: -1.3225, longitude: 36.9255)
        ),
        Place(
            id: "nbo-westgate",
            name: "Westgate Mall",
            subtitle: "Mwanzi Rd · Westlands",
            coordinate: GeoPoint(latitude: -1.2610, longitude: 36.8030)
        ),
        Place(
            id: "nbo-south-b",
            name: "South B",
            subtitle: "Nairobi",
            coordinate: GeoPoint(latitude: -1.3160, longitude: 36.8400)
        ),
        Place(
            id: "nbo-syokimau",
            name: "Syokimau SGR",
            subtitle: "Mombasa Rd",
            coordinate: GeoPoint(latitude: -1.3540, longitude: 36.9100)
        ),
    ]

    /// Backward-compatible alias — DRC destinations.
    static var destinations: [Place] { destinationsDRC }

    static func defaultCenter(for market: AppLocale.Market) -> Place {
        switch market {
        case .kenya: return nairobiCenter
        case .drc, .both: return lubumbashiCenter
        }
    }

    static func destinations(for market: AppLocale.Market) -> [Place] {
        switch market {
        case .kenya: return destinationsKenya
        case .drc, .both: return destinationsDRC
        }
    }

    static func citySubtitle(for market: AppLocale.Market) -> String {
        switch market {
        case .kenya: return "Nairobi"
        case .drc, .both: return "Lubumbashi"
        }
    }
}

enum MockDrivers {
    // MARK: - DRC car fleet (standard)

    /// Local presentation roster — initials avatars when `photoAssetName` is nil.
    static let roster: [DriverProfile] = [
        make(
            id: "d1", name: "Jean-Baptiste M.", rating: 4.92,
            vehicle: "Toyota Corolla · White", plate: "CD 4821 AB",
            trips: 1840, phone: "+243970111001", vehicleClass: .standard,
            years: 7, languages: ["French", "Swahili", "English"],
            opening: "Bonjour — I’m Jean-Baptiste in the white Corolla, plate CD 4821 AB. On my way now.",
            replies: [
                "I’m approaching the pin — look for the white Corolla.",
                "Traffic is light; see you in a few minutes.",
                "I’m at the entrance. Wave when you spot me.",
            ]
        ),
        make(
            id: "d2", name: "Grace K.", rating: 4.88,
            vehicle: "Hyundai Accent · Silver", plate: "CD 1190 KA",
            trips: 1264, phone: "+243970111002", vehicleClass: .standard,
            years: 5, languages: ["French", "English"],
            opening: "Hi, Grace here — silver Accent, plate CD 1190 KA. Heading to you now.",
            replies: [
                "Got it — I’ll wait at the pin.",
                "Almost there. Silver Accent.",
                "Share the trip PIN when you’re ready to board.",
            ]
        ),
        make(
            id: "d3", name: "Patrick T.", rating: 4.95,
            vehicle: "Suzuki Dzire · Blue", plate: "CD 7742 LS",
            trips: 2103, phone: "+243970111003", vehicleClass: .standard,
            years: 9, languages: ["French", "Lingala", "English"],
            opening: "Patrick here — blue Dzire, CD 7742 LS. On the way to pick you up.",
            replies: [
                "I’m circling the block — blue Dzire.",
                "No problem, I’ll wait.",
                "Clear route from here.",
            ]
        ),
        make(
            id: "d4", name: "Amina N.", rating: 4.90,
            vehicle: "Kia Rio · Black", plate: "CD 3308 KW",
            trips: 978, phone: "+243970111004", vehicleClass: .standard,
            years: 4, languages: ["French", "Swahili"],
            opening: "Amina — black Kia Rio, CD 3308 KW. Leaving for your pickup now.",
            replies: [
                "I’m at the pin. Look for the black Rio.",
                "Understood — adjusting now.",
                "Ready when you are.",
            ]
        ),
        make(
            id: "d5", name: "Olivier S.", rating: 4.86,
            vehicle: "Toyota Axio · Grey", plate: "CD 9055 LB",
            trips: 1560, phone: "+243970111005", vehicleClass: .standard,
            years: 6, languages: ["French", "English"],
            opening: "Olivier in the grey Axio (CD 9055 LB). En route to you.",
            replies: [
                "Two minutes out.",
                "I’ll meet you at the gate.",
                "Plate CD 9055 LB — grey Axio.",
            ]
        ),
        make(
            id: "d6", name: "Chantal M.", rating: 4.93,
            vehicle: "Nissan Note · Pearl", plate: "CD 2218 HM",
            trips: 1342, phone: "+243970111006", vehicleClass: .standard,
            years: 5, languages: ["French", "Swahili", "English"],
            opening: "Chantal here — pearl Nissan Note, CD 2218 HM. On my way.",
            replies: [
                "Traffic cleared — arriving soon.",
                "I’m parked by the pin.",
                "Have a good ride with me.",
            ]
        ),
    ]

    // MARK: - Bike / 2-Wheels

    static let bikeRoster: [DriverProfile] = [
        make(
            id: "b1", name: "Chris M.", rating: 4.91,
            vehicle: "Honda Ace 125 · Red", plate: "BK 2041",
            trips: 3120, phone: "+243970111011", vehicleClass: .bike,
            years: 8, languages: ["French", "Lingala"],
            opening: "Chris on the red Honda Ace (BK 2041). Helmet ready — rolling to you.",
            replies: [
                "I’m on two wheels — red Honda, BK 2041.",
                "Near the corner. Wave and I’ll pull over.",
                "Short hop — we’ll beat the traffic.",
            ]
        ),
        make(
            id: "b2", name: "Sarah L.", rating: 4.87,
            vehicle: "TVS Apache · Black", plate: "BK 8812",
            trips: 1988, phone: "+243970111012", vehicleClass: .bike,
            years: 4, languages: ["French", "English"],
            opening: "Sarah — black TVS Apache, BK 8812. Heading your way on bike.",
            replies: [
                "Pulling up on the black Apache.",
                "I’ll wait by the curb.",
                "Ready for a quick city hop.",
            ]
        ),
        make(
            id: "b3", name: "Joseph K.", rating: 4.89,
            vehicle: "Bajaj Boxer · Blue", plate: "BK 4509",
            trips: 2410, phone: "+243970111013", vehicleClass: .bike,
            years: 6, languages: ["French", "Swahili"],
            opening: "Joseph on a blue Bajaj Boxer (BK 4509). On my way.",
            replies: [
                "Blue Boxer at the pin.",
                "I’ll take the quieter streets.",
                "See you shortly.",
            ]
        ),
        make(
            id: "b4", name: "Naomi W.", rating: 4.94,
            vehicle: "Yamaha Crux · White", plate: "BK 6720",
            trips: 1675, phone: "+243970111014", vehicleClass: .bike,
            years: 5, languages: ["French", "English", "Swahili"],
            opening: "Naomi — white Yamaha Crux, BK 6720. Rolling out now.",
            replies: [
                "White Crux — BK 6720.",
                "I’m outside. Helmet’s ready.",
                "Let’s go when you are.",
            ]
        ),
    ]

    // MARK: - XXL / Executive / Airport (large)

    static let largeRoster: [DriverProfile] = [
        make(
            id: "x1", name: "Didier K.", rating: 4.94,
            vehicle: "Toyota Noah · Silver", plate: "XL 5520 CD",
            trips: 1422, phone: "+243970111021", vehicleClass: .large,
            years: 10, languages: ["French", "English"],
            opening: "Didier — silver Toyota Noah, XL 5520 CD. Plenty of space; on my way.",
            replies: [
                "Silver Noah with room for everyone.",
                "I can help with luggage at the curb.",
                "Parked at the pin — XL 5520 CD.",
            ]
        ),
        make(
            id: "x2", name: "Esther B.", rating: 4.96,
            vehicle: "Hyundai H1 · White", plate: "XL 1194 CD",
            trips: 890, phone: "+243970111022", vehicleClass: .large,
            years: 7, languages: ["French", "Swahili", "English"],
            opening: "Esther in the white H1 van (XL 1194 CD). Heading to pick you up.",
            replies: [
                "White H1 — easy to spot.",
                "I’ll wait with the hazards on.",
                "Group seating is ready.",
            ]
        ),
        make(
            id: "x3", name: "Marc O.", rating: 4.93,
            vehicle: "Mercedes V-Class · Black", plate: "EX 4401 CD",
            trips: 654, phone: "+243970111023", vehicleClass: .large,
            years: 11, languages: ["French", "English"],
            opening: "Marc — black V-Class, EX 4401 CD. Executive pickup underway.",
            replies: [
                "Black V-Class at your service.",
                "Climate set — boarding when you’re ready.",
                "I’ll meet you at arrivals if needed.",
            ]
        ),
        make(
            id: "x4", name: "Pauline D.", rating: 4.97,
            vehicle: "Toyota HiAce · Pearl", plate: "XL 8802 CD",
            trips: 1120, phone: "+243970111024", vehicleClass: .large,
            years: 8, languages: ["French", "Lingala", "English"],
            opening: "Pauline — pearl HiAce, XL 8802 CD. On the way for your group.",
            replies: [
                "Pearl HiAce with luggage space.",
                "I can wait a few minutes at the pin.",
                "Ready for boarding.",
            ]
        ),
        make(
            id: "x5", name: "Ibrahim Y.", rating: 4.91,
            vehicle: "Land Cruiser Prado · Black", plate: "EX 2108 CD",
            trips: 520, phone: "+243970111025", vehicleClass: .large,
            years: 12, languages: ["French", "English", "Arabic"],
            opening: "Ibrahim — black Prado, EX 2108 CD. Executive transfer en route.",
            replies: [
                "Black Prado standing by.",
                "Route is clear from here.",
                "I’ll confirm when I’m at the terminal curb.",
            ]
        ),
    ]

    // MARK: - Kenya market fleets

    static let kenyaRoster: [DriverProfile] = [
        make(
            id: "kd1", name: "Brian O.", rating: 4.91,
            vehicle: "Toyota Axio · Silver", plate: "KDA 482J",
            trips: 2210, phone: "+254712111001", vehicleClass: .standard,
            years: 6, languages: ["English", "Swahili"],
            opening: "Brian — silver Axio, KDA 482J. On my way to you.",
            replies: [
                "Silver Axio, KDA 482J.",
                "I’m near the pin.",
                "Traffic is moving — almost there.",
            ]
        ),
        make(
            id: "kd2", name: "Faith W.", rating: 4.89,
            vehicle: "Mazda Demio · Red", plate: "KDG 901A",
            trips: 1680, phone: "+254712111002", vehicleClass: .standard,
            years: 5, languages: ["English", "Swahili"],
            opening: "Faith here — red Demio, KDG 901A. Heading over now.",
            replies: [
                "Red Demio at the pickup.",
                "I’ll wait by the entrance.",
                "Ready when you are.",
            ]
        ),
        make(
            id: "kd3", name: "Dennis M.", rating: 4.94,
            vehicle: "Toyota Fielder · White", plate: "KDE 334C",
            trips: 3012, phone: "+254712111003", vehicleClass: .standard,
            years: 9, languages: ["English", "Swahili"],
            opening: "Dennis — white Fielder, KDE 334C. En route.",
            replies: [
                "White Fielder coming up.",
                "Share the PIN at the door.",
                "Clear roads from here.",
            ]
        ),
        make(
            id: "kd4", name: "Aisha N.", rating: 4.87,
            vehicle: "Honda Fit · Grey", plate: "KDF 118B",
            trips: 990, phone: "+254712111004", vehicleClass: .standard,
            years: 4, languages: ["English", "Swahili"],
            opening: "Aisha — grey Fit, KDF 118B. On my way.",
            replies: [
                "Grey Fit at the pin.",
                "No rush — I’ll wait.",
                "See you shortly.",
            ]
        ),
    ]

    static let kenyaBikeRoster: [DriverProfile] = [
        make(
            id: "kb1", name: "Kevin M.", rating: 4.90,
            vehicle: "TVS HLX · Black", plate: "KMC 204A",
            trips: 4100, phone: "+254712111011", vehicleClass: .bike,
            years: 7, languages: ["English", "Swahili"],
            opening: "Kevin on a black TVS HLX (KMC 204A). Rolling to you.",
            replies: [
                "Black bike — KMC 204A.",
                "I’ll take the shortcut.",
                "Wave and I’ll stop.",
            ]
        ),
        make(
            id: "kb2", name: "Lucy A.", rating: 4.88,
            vehicle: "Boxer BM150 · Red", plate: "KMD 881B",
            trips: 2550, phone: "+254712111012", vehicleClass: .bike,
            years: 5, languages: ["English", "Swahili"],
            opening: "Lucy — red Boxer, KMD 881B. On my way.",
            replies: [
                "Red Boxer at the curb.",
                "Helmet ready for you.",
                "Quick hop — let’s go.",
            ]
        ),
    ]

    static let kenyaLargeRoster: [DriverProfile] = [
        make(
            id: "kx1", name: "Peter K.", rating: 4.95,
            vehicle: "Toyota Noah · White", plate: "KCA 552K",
            trips: 1320, phone: "+254712111021", vehicleClass: .large,
            years: 8, languages: ["English", "Swahili"],
            opening: "Peter — white Noah, KCA 552K. Room for the group; en route.",
            replies: [
                "White Noah with luggage space.",
                "I’m at arrivals curb if needed.",
                "Ready for boarding.",
            ]
        ),
        make(
            id: "kx2", name: "Mary J.", rating: 4.97,
            vehicle: "Mercedes Vito · Black", plate: "KCB 440L",
            trips: 710, phone: "+254712111022", vehicleClass: .large,
            years: 10, languages: ["English", "Swahili"],
            opening: "Mary — black Vito, KCB 440L. Executive pickup underway.",
            replies: [
                "Black Vito standing by.",
                "Climate’s set — take your time.",
                "I’ll confirm when I’m at the pin.",
            ]
        ),
        make(
            id: "kx3", name: "Samuel O.", rating: 4.92,
            vehicle: "Hyundai H1 · Silver", plate: "KCC 119M",
            trips: 980, phone: "+254712111023", vehicleClass: .large,
            years: 7, languages: ["English", "Swahili"],
            opening: "Samuel — silver H1, KCC 119M. Heading to pick you up.",
            replies: [
                "Silver H1 — easy to spot.",
                "I can help with bags.",
                "Parked with hazards on.",
            ]
        ),
    ]

    static func random() -> DriverProfile {
        random(for: .standard)
    }

    static func random(
        for vehicleClass: VehicleClass,
        market: AppLocale.Market = AppLocale.current
    ) -> DriverProfile {
        let kenya = market == .kenya
        let pool: [DriverProfile]
        switch vehicleClass {
        case .bike:
            pool = kenya ? kenyaBikeRoster : bikeRoster
        case .standard:
            pool = kenya ? kenyaRoster : roster
        case .large:
            pool = kenya ? kenyaLargeRoster : largeRoster
        }
        return pool.randomElement() ?? pool[0]
    }

    /// Builds a chat-ready driver profile. `photoAssetName` stays nil → initials placeholder.
    private static func make(
        id: String,
        name: String,
        rating: Double,
        vehicle: String,
        plate: String,
        trips: Int,
        phone: String,
        vehicleClass: VehicleClass,
        years: Int,
        languages: [String],
        opening: String,
        replies: [String],
        photoAssetName: String? = nil
    ) -> DriverProfile {
        DriverProfile(
            id: id,
            name: name,
            rating: rating,
            vehicle: vehicle,
            plate: plate,
            tripsCompleted: trips,
            phone: phone,
            photoAssetName: photoAssetName,
            vehicleClass: vehicleClass,
            yearsDriving: years,
            languages: languages,
            chatOpeningLine: opening,
            chatReplyLines: replies,
            bio: "\(name.split(separator: " ").first.map(String.init) ?? name) is a verified Vuum driver with \(years)+ years on the road.",
            backgroundCheckPassed: rating >= 4.2,
            vehicleInspection: rating >= 4.5 ? .current : (rating >= 4.0 ? .dueSoon : .overdue)
        )
    }
}

enum MockCorporate {
    static let miningCo = CorporateAccount(
        companyName: "Mining Co. Lubumbashi",
        department: "Field operations",
        employeeRole: "Site coordinator",
        employeeId: "MC-LUB-1842",
        costCentre: "OPS · Lubumbashi",
        monthlySpendLimitCDF: 2_500_000,
        spentThisMonthCDF: 845_000,
        companyWalletBalanceCDF: 18_400_000,
        transportAllowanceCDF: 2_500_000,
        sosContactName: "Mining Co. Security Desk",
        sosContactPhone: "+243 970 000 112",
        corporateSupportPhone: "+243 970 000 200",
        vipTransferEnabled: true,
        meetAndGreetDefault: true
    )

    static var recentTrips: [CorporateTripRecord] {
        let now = Date()
        return [
            CorporateTripRecord(
                id: "corp-1",
                date: now.addingTimeInterval(-90_000),
                pickupName: "Mining Co. HQ",
                dropoffName: "Lubumbashi Airport",
                tierName: "Executive",
                purpose: "Executive transfer · meet-and-greet",
                costCentre: miningCo.costCentre,
                totalCDF: 48_500,
                billedToCompany: true
            ),
            CorporateTripRecord(
                id: "corp-2",
                date: now.addingTimeInterval(-250_000),
                pickupName: "Hôtel Karavia",
                dropoffName: "Mining Co. HQ",
                tierName: "Comfort",
                purpose: "Site visit",
                costCentre: miningCo.costCentre,
                totalCDF: 18_200,
                billedToCompany: true
            ),
        ]
    }
}

/// Zone / time-based surge configuration (admin-ready structure).
enum MockSurge {
    static let airportZoneIDs: Set<String> = [
        "airport", "nbo-jkia", "nbo-wilson",
        "lub-airport", "nbo-jkia-zone", "nbo-wilson-zone",
    ]

    static func isAirportPlace(_ place: Place?) -> Bool {
        ServiceZoneCatalog.isAirportPlace(place)
    }

    static func isAirportTrip(pickup: Place, dropoff: Place?) -> Bool {
        ServiceZoneCatalog.isAirportTrip(pickup: pickup, dropoff: dropoff)
    }

    /// Resolves configurable surge for the pickup zone and local clock.
    static func state(
        pickup: Place,
        dropoff: Place? = nil,
        market: AppLocale.Market = AppLocale.current,
        accountType: RiderAccountType = .personal,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SurgeState {
        let resolution = ServiceZoneCatalog.resolve(
            place: pickup,
            market: market,
            accountType: accountType,
            now: now
        )
        // Dropoff at an airport still qualifies for airport toll / demand even if pickup is city.
        if let dropoff, ServiceZoneCatalog.isAirportPlace(dropoff), !resolution.isAirportArea {
            let dropRes = ServiceZoneCatalog.resolve(
                place: dropoff,
                market: market,
                accountType: accountType,
                now: now
            )
            let mult = max(resolution.surgeMultiplier, dropRes.surgeMultiplier, 1.3)
            if mult > 1.001 {
                return SurgeState(
                    multiplier: mult,
                    label: dropRes.surgeLabel.isEmpty ? "Airport area" : dropRes.surgeLabel,
                    zoneId: dropRes.primaryZone?.id ?? "airport"
                )
            }
        }
        if resolution.surgeMultiplier > 1.001 {
            return SurgeState(
                multiplier: resolution.surgeMultiplier,
                label: resolution.surgeLabel,
                zoneId: resolution.primaryZone?.id ?? resolution.cityId
            )
        }
        return .inactive
    }

    static func tollLocal(for market: AppLocale.Market, isAirport: Bool) -> Int {
        guard isAirport else { return 0 }
        return market == .kenya ? 150 : 2_500
    }

    static func serviceFeeLocal(for market: AppLocale.Market) -> Int {
        market == .kenya ? 25 : 400
    }

    static func waitingPerMinute(for market: AppLocale.Market) -> Int {
        market == .kenya ? 3 : 60
    }
}

enum MockFares {
    static var tiers: [RideTier] { tiers(for: 4_500) }

    static func tiers(
        for distanceMeters: Double,
        market: AppLocale.Market = AppLocale.current,
        surgeMultiplier: Double = 1.0,
        stopCount: Int = 0
    ) -> [RideTier] {
        let base: [RideTier]
        switch market {
        case .kenya:
            base = kenyaTiers(for: distanceMeters)
        case .drc, .both:
            base = drcTiers(for: distanceMeters)
        }
        let fareMarket: AppLocale.Market = market == .kenya ? .kenya : .drc
        let waitCharge = max(0, stopCount) * 3 * MockSurge.waitingPerMinute(for: fareMarket)
        let surge = max(surgeMultiplier, 1.0)
        guard surge > 1.001 || waitCharge > 0 else { return base }
        return base.map { tier in
            var next = tier
            var price = tier.priceCDF + waitCharge
            if surge > 1.001 {
                price = Int((Double(price) * surge).rounded())
            }
            next.priceCDF = price
            next.priceUSD = AppLocale.usdFromLocal(price, market: fareMarket)
            return next
        }
    }

    private static func kenyaTiers(for distanceMeters: Double) -> [RideTier] {
        let km = max(distanceMeters / 1000.0, 1.2)
        func price(base: Int, perKm: Int) -> (local: Int, usd: Double) {
            let local = base + Int((km * Double(perKm)).rounded())
            return (local, AppLocale.usdFromLocal(local, market: .kenya))
        }
        let vuum = price(base: 200, perKm: 80)
        let comfort = price(base: 280, perKm: 105)
        let xxl = price(base: 400, perKm: 140)
        let airport = price(base: 480, perKm: 155)
        return makeTiers(vuum: vuum, comfort: comfort, xxl: xxl, airport: airport, market: .kenya)
    }

    private static func drcTiers(for distanceMeters: Double) -> [RideTier] {
        let km = max(distanceMeters / 1000.0, 1.2)
        func price(base: Int, perKm: Int) -> (local: Int, usd: Double) {
            let local = base + Int((km * Double(perKm)).rounded())
            return (local, AppLocale.usdFromLocal(local, market: .drc))
        }
        let vuum = price(base: 2500, perKm: 1800)
        let comfort = price(base: 3500, perKm: 2200)
        let xxl = price(base: 4500, perKm: 2800)
        let airport = price(base: 5500, perKm: 3000)
        return makeTiers(vuum: vuum, comfort: comfort, xxl: xxl, airport: airport, market: .drc)
    }

    private static func makeTiers(
        vuum: (local: Int, usd: Double),
        comfort: (local: Int, usd: Double),
        xxl: (local: Int, usd: Double),
        airport: (local: Int, usd: Double),
        market: AppLocale.Market
    ) -> [RideTier] {
        let executiveLocal = Int((Double(xxl.local) * 1.35).rounded())
        let carETA = VehiclePickupETA.minutes(for: .standard)
        let xxlETA = VehiclePickupETA.minutes(for: .large)
        return [
            RideTier(
                id: ServiceProductID.vuum,
                name: "Vuum",
                detail: "Affordable everyday rides",
                capacity: 4,
                etaMinutes: carETA,
                priceCDF: vuum.local,
                priceUSD: vuum.usd,
                systemImage: ServiceProductID.systemImage(forProductID: ServiceProductID.vuum),
                vehicleClass: .standard
            ),
            RideTier(
                id: ServiceProductID.comfort,
                name: "Comfort",
                detail: "Newer cars · extra space",
                capacity: 4,
                etaMinutes: carETA,
                priceCDF: comfort.local,
                priceUSD: comfort.usd,
                systemImage: ServiceProductID.systemImage(forProductID: ServiceProductID.comfort),
                vehicleClass: .standard
            ),
            RideTier(
                id: ServiceProductID.xxl,
                name: "Vuum XXL",
                detail: "Up to 6 passengers",
                capacity: 6,
                etaMinutes: xxlETA,
                priceCDF: xxl.local,
                priceUSD: xxl.usd,
                systemImage: ServiceProductID.systemImage(forProductID: ServiceProductID.xxl),
                vehicleClass: .large
            ),
            RideTier(
                id: ServiceProductID.executive,
                name: "Executive",
                detail: "Premium cars · top-rated drivers",
                capacity: 3,
                etaMinutes: xxlETA,
                priceCDF: executiveLocal,
                priceUSD: AppLocale.usdFromLocal(executiveLocal, market: market),
                systemImage: ServiceProductID.systemImage(forProductID: ServiceProductID.executive),
                vehicleClass: .large
            ),
            RideTier(
                id: ServiceProductID.airport,
                name: "Airport",
                detail: "Terminal pickup · luggage space",
                capacity: 4,
                etaMinutes: xxlETA,
                priceCDF: airport.local,
                priceUSD: airport.usd,
                systemImage: ServiceProductID.systemImage(forProductID: ServiceProductID.airport),
                vehicleClass: .large
            ),
        ]
    }

    /// Pricing engine: base + distance + time + waiting + surge + toll + service fee − promo.
    static func breakdown(
        distanceMeters: Double,
        tier: RideTier,
        discountCDF: Int = 0,
        surgeMultiplier: Double = 1.0,
        tollCDF: Int = 0,
        serviceFeeCDF: Int? = nil,
        waitingMinutes: Int = 0,
        market: AppLocale.Market = AppLocale.current,
        isAirportZone: Bool? = nil,
        bookingType: PricingInput.BookingType = .onDemand,
        corporateDiscountLocal: Int = 0
    ) -> FareBreakdown {
        quote(
            distanceMeters: distanceMeters,
            tier: tier,
            discountCDF: discountCDF,
            surgeMultiplier: surgeMultiplier,
            tollCDF: tollCDF,
            serviceFeeCDF: serviceFeeCDF,
            waitingMinutes: waitingMinutes,
            market: market,
            isAirportZone: isAirportZone,
            bookingType: bookingType,
            corporateDiscountLocal: corporateDiscountLocal
        ).breakdown
    }

    /// Typed quote (primary / secondary Money + itemized breakdown).
    static func quote(
        distanceMeters: Double,
        tier: RideTier,
        discountCDF: Int = 0,
        surgeMultiplier: Double = 1.0,
        tollCDF: Int = 0,
        serviceFeeCDF: Int? = nil,
        waitingMinutes: Int = 0,
        market: AppLocale.Market = AppLocale.current,
        isAirportZone: Bool? = nil,
        bookingType: PricingInput.BookingType = .onDemand,
        corporateDiscountLocal: Int = 0
    ) -> PricingResult {
        let fareMarket: AppLocale.Market = market == .kenya ? .kenya : .drc
        var card = PricingRateCard.catalog(market: fareMarket, serviceCategory: tier.id)
        if let serviceFeeCDF {
            card.serviceFee = serviceFeeCDF
        }
        if tollCDF > 0 {
            card.airportToll = tollCDF
        }
        let airport = isAirportZone ?? (tollCDF > 0)
        let booking: PricingInput.BookingType = {
            if bookingType != .onDemand { return bookingType }
            if tier.id == "executive" { return .executive }
            return .onDemand
        }()
        let input = PricingInput(
            serviceCategory: tier.id,
            distanceMeters: distanceMeters,
            waitingMinutes: waitingMinutes,
            surgeMultiplier: surgeMultiplier,
            isAirportZone: airport || tollCDF > 0,
            bookingType: booking,
            promoDiscountLocal: discountCDF,
            corporateDiscountLocal: corporateDiscountLocal,
            market: fareMarket,
            listPriceLocal: tier.priceCDF,
            rateCard: card
        )
        return PricingEngine.quote(input)
    }
}

enum MockTripHistory {
    static var samples: [TripReceipt] {
        switch AppLocale.current {
        case .kenya:
            return kenyaSamples
        case .drc, .both:
            return drcSamples
        }
    }

    private static let kenyaSamples: [TripReceipt] = [
        TripReceipt(
            id: "hist-1",
            date: Date().addingTimeInterval(-86_400),
            pickupName: "Westlands",
            dropoffName: "Kilimani",
            stopNames: ["Sarit Centre"],
            driverName: "Brian O.",
            vehicle: "Toyota Corolla",
            plate: "KDA 482L",
            tierName: "Vuum",
            paymentMethod: .mpesa,
            status: .completed,
            fare: FareBreakdown(
                baseFareCDF: 80,
                distanceFareCDF: 220,
                timeFareCDF: 48,
                bookingFeeCDF: 20,
                discountCDF: 0,
                totalCDF: 368,
                totalUSD: 2.85,
                distanceKm: 3.4,
                durationMinutes: 12
            ),
            tipCDF: 50,
            rating: 5
        ),
        TripReceipt(
            id: "hist-2",
            date: Date().addingTimeInterval(-172_800),
            pickupName: "CBD",
            dropoffName: "Lavington",
            driverName: "Faith W.",
            tierName: "Comfort",
            fare: FareBreakdown(
                baseFareCDF: 100,
                distanceFareCDF: 280,
                timeFareCDF: 56,
                bookingFeeCDF: 20,
                discountCDF: 0,
                totalCDF: 456,
                totalUSD: 3.53,
                distanceKm: 4.1,
                durationMinutes: 14
            ),
            rating: 4
        ),
        TripReceipt(
            id: "hist-3",
            date: Date().addingTimeInterval(-259_200),
            pickupName: "JKIA Terminal 1A",
            dropoffName: "Westlands",
            driverName: "Peter K.",
            tierName: "Airport",
            fare: FareBreakdown(
                baseFareCDF: 120,
                distanceFareCDF: 980,
                timeFareCDF: 140,
                bookingFeeCDF: 40,
                waitingFareCDF: 30,
                surgeMultiplier: 1.3,
                surgeFareCDF: 393,
                tollCDF: 150,
                serviceFeeCDF: 25,
                discountCDF: 0,
                totalCDF: 1_878,
                totalUSD: 14.55,
                distanceKm: 16.2,
                durationMinutes: 38
            ),
            rating: 5
        ),
        TripReceipt(
            id: "hist-4",
            date: Date().addingTimeInterval(-345_600),
            pickupName: "Kilimani",
            dropoffName: "Yaya Centre",
            driverName: "Kevin M.",
            tierName: "2-Wheels",
            fare: FareBreakdown(
                baseFareCDF: 60,
                distanceFareCDF: 90,
                timeFareCDF: 20,
                bookingFeeCDF: 15,
                discountCDF: 0,
                totalCDF: 185,
                totalUSD: 1.43,
                distanceKm: 1.8,
                durationMinutes: 8
            ),
            rating: 5
        ),
        TripReceipt(
            id: "hist-5",
            date: Date().addingTimeInterval(-432_000),
            pickupName: "Two Rivers Mall",
            dropoffName: "Karen",
            driverName: "Mary J.",
            tierName: "Vuum XXL",
            fare: FareBreakdown(
                baseFareCDF: 150,
                distanceFareCDF: 620,
                timeFareCDF: 96,
                bookingFeeCDF: 40,
                discountCDF: 100,
                totalCDF: 806,
                totalUSD: 6.25,
                distanceKm: 9.4,
                durationMinutes: 24
            ),
            rating: 4
        ),
    ]

    private static let drcSamples: [TripReceipt] = [
        TripReceipt(
            id: "hist-1",
            date: Date().addingTimeInterval(-86_400),
            pickupName: "Kenya Market",
            dropoffName: "Hybride Mall",
            stopNames: ["Avenue Mobutu"],
            driverName: "Grace K.",
            vehicle: "Toyota RAV4",
            plate: "AAC 482 L",
            tierName: "Vuum",
            paymentMethod: .orangeMoney,
            status: .completed,
            fare: FareBreakdown(
                baseFareCDF: 2000,
                distanceFareCDF: 4200,
                timeFareCDF: 960,
                bookingFeeCDF: 500,
                waitingFareCDF: 0,
                surgeMultiplier: 1.25,
                surgeFareCDF: 1915,
                tollCDF: 0,
                serviceFeeCDF: 400,
                discountCDF: 1500,
                subtotalCDF: 9975,
                totalCDF: 8475,
                totalUSD: 2.97,
                distanceKm: 3.4,
                durationMinutes: 12
            ),
            tipCDF: 500,
            rating: 5
        ),
        TripReceipt(
            id: "hist-2",
            date: Date().addingTimeInterval(-172_800),
            pickupName: "Hôtel Karavia",
            dropoffName: "Gare Centrale",
            driverName: "Jean-Baptiste M.",
            tierName: "Comfort",
            fare: FareBreakdown(
                baseFareCDF: 2500,
                distanceFareCDF: 5100,
                timeFareCDF: 1120,
                bookingFeeCDF: 500,
                discountCDF: 0,
                totalCDF: 9220,
                totalUSD: 3.24,
                distanceKm: 4.1,
                durationMinutes: 14
            ),
            rating: 4
        ),
        TripReceipt(
            id: "hist-3",
            date: Date().addingTimeInterval(-259_200),
            pickupName: "Luano International Airport",
            dropoffName: "Hôtel Karavia",
            driverName: "Marc O.",
            tierName: "Airport",
            fare: FareBreakdown(
                baseFareCDF: 3500,
                distanceFareCDF: 12_800,
                timeFareCDF: 2400,
                bookingFeeCDF: 800,
                waitingFareCDF: 300,
                surgeMultiplier: 1.3,
                surgeFareCDF: 5_940,
                tollCDF: 2_500,
                serviceFeeCDF: 400,
                discountCDF: 0,
                totalCDF: 28_640,
                totalUSD: 10.05,
                distanceKm: 14.8,
                durationMinutes: 32
            ),
            rating: 5
        ),
        TripReceipt(
            id: "hist-4",
            date: Date().addingTimeInterval(-345_600),
            pickupName: "Kenya Market",
            dropoffName: "SNEL Siège",
            driverName: "Chris M.",
            tierName: "2-Wheels",
            fare: FareBreakdown(
                baseFareCDF: 1500,
                distanceFareCDF: 2200,
                timeFareCDF: 400,
                bookingFeeCDF: 300,
                discountCDF: 0,
                totalCDF: 4400,
                totalUSD: 1.54,
                distanceKm: 2.1,
                durationMinutes: 9
            ),
            rating: 5
        ),
        TripReceipt(
            id: "hist-5",
            date: Date().addingTimeInterval(-432_000),
            pickupName: "Kolwezi Centre",
            dropoffName: "Gécamines Kolwezi",
            driverName: "Didier K.",
            vehicle: "Suzuki Swift",
            plate: "AAD 204 K",
            tierName: "Vuum XXL",
            paymentMethod: .cash,
            status: .cancelled,
            fare: FareBreakdown(
                baseFareCDF: 3200,
                distanceFareCDF: 6800,
                timeFareCDF: 1280,
                bookingFeeCDF: 600,
                discountCDF: 0,
                totalCDF: 0,
                totalUSD: 0,
                distanceKm: 5.6,
                durationMinutes: 0
            ),
            cancelReason: "Rider cancelled before pickup"
        ),
    ]
}
