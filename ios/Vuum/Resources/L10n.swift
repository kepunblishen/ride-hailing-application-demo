import Foundation
import Combine

/// Supported rider UI languages (RFQ: FR primary, EN, Lingala, Kiswahili).
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case french = "fr"
    case lingala = "ln"
    case kiswahili = "sw"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        case .lingala: return "Lingala"
        case .kiswahili: return "Kiswahili"
        }
    }

    static func resolved(from code: String?) -> AppLanguage {
        guard let code, let lang = AppLanguage(rawValue: code) else { return .english }
        return lang
    }
}

/// Persists language (and future prefs) in UserDefaults; drives `L10n` lookups.
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    static let languageKey = "vuum.language"
    static let lowDataModeKey = "vuum.lowDataMode"

    @Published var languageCode: String {
        didSet {
            guard languageCode != oldValue else { return }
            UserDefaults.standard.set(languageCode, forKey: Self.languageKey)
        }
    }

    /// Lite / low-data mode: simpler map, traffic off, fewer decorative assets (R18/D14/T12).
    @Published var lowDataMode: Bool {
        didSet {
            guard lowDataMode != oldValue else { return }
            UserDefaults.standard.set(lowDataMode, forKey: Self.lowDataModeKey)
            if lowDataMode {
                UserDefaults.standard.set(false, forKey: MapTrafficSettings.trafficKey)
                UserDefaults.standard.set(false, forKey: MapTrafficSettings.etaRefreshKey)
            }
        }
    }

    var language: AppLanguage {
        get { AppLanguage.resolved(from: languageCode) }
        set { languageCode = newValue.rawValue }
    }

    init(defaults: UserDefaults = .standard) {
        languageCode = defaults.string(forKey: Self.languageKey) ?? AppLanguage.english.rawValue
        lowDataMode = defaults.bool(forKey: Self.lowDataModeKey)
    }
}

/// In-app string catalog. Prefer `L10n.Home.whereTo` or `L10n.t("home.where_to")`.
enum L10n {
    static var language: AppLanguage {
        AppPreferences.shared.language
    }

    static func t(_ key: String) -> String {
        t(key, language: language)
    }

    static func t(_ key: String, language: AppLanguage) -> String {
        if let value = catalog[key]?[language] {
            return value
        }
        if let fallback = catalog[key]?[.english] {
            return fallback
        }
        return key
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    private static func s(_ en: String, _ fr: String, _ ln: String, _ sw: String) -> [AppLanguage: String] {
        [.english: en, .french: fr, .lingala: ln, .kiswahili: sw]
    }

    // MARK: - Common

    enum Common {
        static var cancel: String { t("common.cancel") }
        static var close: String { t("common.close") }
        static var `continue`: String { t("common.continue") }
        static var next: String { t("common.next") }
        static var back: String { t("common.back") }
        static var save: String { t("common.save") }
        static var delete: String { t("common.delete") }
        static var or: String { t("common.or") }
        static var apply: String { t("common.apply") }
        static var change: String { t("common.change") }
        static var gotIt: String { t("common.got_it") }
        static var clear: String { t("common.clear") }
        static var notSet: String { t("common.not_set") }
    }

    // MARK: - Auth

    enum Auth {
        static var getStartedTitle: String { t("auth.get_started_title") }
        static var mobileNumber: String { t("auth.mobile_number") }
        static var continueApple: String { t("auth.continue_apple") }
        static var continueGoogle: String { t("auth.continue_google") }
        static var continueEmail: String { t("auth.continue_email") }
        static var findAccount: String { t("auth.find_account") }
        static var smsDisclaimer: String { t("auth.sms_disclaimer") }
        static var otpPrompt: String { t("auth.otp_prompt") }
        static var changedNumber: String { t("auth.changed_number") }
        static var resendSMS: String { t("auth.resend_sms") }
        static var backupCode: String { t("auth.backup_code") }
        static var digitA11y: String { t("auth.digit_a11y") }
        static var termsTitle: String { t("auth.terms_title") }
        static var termsBodyLead: String { t("auth.terms_body_lead") }
        static var termsOfUse: String { t("auth.terms_of_use") }
        static var termsBodyMid: String { t("auth.terms_body_mid") }
        static var privacyNotice: String { t("auth.privacy_notice") }
        static var termsBodyAge: String { t("auth.terms_body_age") }
        static var iAgree: String { t("auth.i_agree") }
        static var confirmInfo: String { t("auth.confirm_info") }
        static var firstName: String { t("auth.first_name") }
        static var lastName: String { t("auth.last_name") }
        static var welcome: String { t("auth.welcome") }
        static var customizing: String { t("auth.customizing") }
        static var countryCode: String { t("auth.country_code") }
        static var searchCountry: String { t("auth.search_country") }
        static var noCountries: String { t("auth.no_countries") }
        static var clearSearch: String { t("auth.clear_search") }
        static var phoneInvalid: String { t("auth.phone_invalid") }
        static var otpInvalid: String { t("auth.otp_invalid") }
        static var otpExpired: String { t("auth.otp_expired") }
        static var otpTooManyAttempts: String { t("auth.otp_too_many") }
        static var nameInvalid: String { t("auth.name_invalid") }
        static var emailInvalid: String { t("auth.email_invalid") }
        static var emailOptional: String { t("auth.email_optional") }
        static var resendIn: String { t("auth.resend_in") }
        static var backupTitle: String { t("auth.backup_title") }
        static var backupHint: String { t("auth.backup_hint") }
        static var backupSubmit: String { t("auth.backup_submit") }
        static var termsDocument: String { t("auth.terms_document") }
        static var privacyDocument: String { t("auth.privacy_document") }
        static var sendingCode: String { t("auth.sending_code") }
        static var verifyingCode: String { t("auth.verifying_code") }
    }

    // MARK: - Home

    enum Home {
        static var whereTo: String { t("home.where_to") }
        static var pickup: String { t("home.pickup") }
        static var adjust: String { t("home.adjust") }
        static var now: String { t("home.now") }
        static var later: String { t("home.later") }
        static var upcoming: String { t("home.upcoming") }
        static var tagline: String { t("home.tagline") }
        static var taglineKenya: String { t("home.tagline_kenya") }
        static var rides: String { t("home.rides") }
        static var eats: String { t("home.eats") }
        static var suggestions: String { t("home.suggestions") }
        static var safety: String { t("home.safety") }
        static var recent: String { t("home.recent") }
        static var recenter: String { t("home.recenter") }
        static var addHome: String { t("home.add_home") }
        static var addWork: String { t("home.add_work") }
        static var promoTitle: String { t("home.promo_title") }
        static var promoBadge: String { t("home.promo_badge") }
        static var eatsSearch: String { t("home.eats_search") }
        static var eatsNearby: String { t("home.eats_nearby") }
        static var eatsExpanding: String { t("home.eats_expanding") }
        static var whereToHint: String { t("home.where_to_hint") }
        static var schedulePickup: String { t("home.schedule_pickup") }
        static var browseServices: String { t("home.browse_services") }
        static var tab: String { t("tab.home") }
    }

    // MARK: - Services

    enum Services {
        static var tab: String { t("tab.services") }
        static var title: String { t("services.title") }
        static var rideSection: String { t("services.ride_section") }
        static var moreSection: String { t("services.more_section") }
        static var goAnywhere: String { t("services.go_anywhere") }
        static var getDelivered: String { t("services.get_delivered") }
        static var rides: String { t("services.rides") }
        static var ridesDetail: String { t("services.rides_detail") }
        static var comfort: String { t("services.comfort") }
        static var comfortDetail: String { t("services.comfort_detail") }
        static var xl: String { t("services.xl") }
        static var xlDetail: String { t("services.xl_detail") }
        static var executive: String { t("services.executive") }
        static var executiveDetail: String { t("services.executive_detail") }
        static var reserve: String { t("services.reserve") }
        static var reserveDetail: String { t("services.reserve_detail") }
        static var courier: String { t("services.courier") }
        static var courierDetail: String { t("services.courier_detail") }
        static var corporate: String { t("services.corporate") }
        static var corporateDetail: String { t("services.corporate_detail") }
        static var upcomingReservations: String { t("services.upcoming_reservations") }
        static var twoWheels: String { t("services.two_wheels") }
        static var rental: String { t("services.rental") }
        static var hourly: String { t("services.hourly") }
        static var groupRide: String { t("services.group_ride") }
        static var comingSoonBody: String { t("services.coming_soon_body") }
        static var availableInCity: String { t("services.available_in_city") }
        static var promoBadge: String { t("services.promo_badge") }
        static var food: String { t("services.food") }
        static var grocery: String { t("services.grocery") }
        static var convenience: String { t("services.convenience") }
        static var alcohol: String { t("services.alcohol") }
        static var health: String { t("services.health") }
        static var packages: String { t("services.packages") }
    }

    // MARK: - Products

    enum Products {
        static var continueToBook: String { t("products.continue_to_book") }
        static var pickup: String { t("products.pickup") }
        static var dropoff: String { t("products.dropoff") }
        static var from: String { t("products.from") }
        static var to: String { t("products.to") }
        static var twoWheelsSubtitle: String { t("products.two_wheels_subtitle") }
        static var twoWheelsNote: String { t("products.two_wheels_note") }
        static var courierSubtitle: String { t("products.courier_subtitle") }
        static var packageDetails: String { t("products.package_details") }
        static var packageNotes: String { t("products.package_notes") }
        static var hourlySubtitle: String { t("products.hourly_subtitle") }
        static var duration: String { t("products.duration") }
        static var hours: String { t("products.hours") }
        static var hourSingular: String { t("products.hour_singular") }
        static var hoursPlural: String { t("products.hours_plural") }
        static var hourlyFareNote: String { t("products.hourly_fare_note") }
        static var groupSubtitle: String { t("products.group_subtitle") }
        static var passengers: String { t("products.passengers") }
        static var seats: String { t("products.seats") }
        static var groupNote: String { t("products.group_note") }
        static var twoWheelsDetail: String { t("products.two_wheels_detail") }
        static var courierDetail: String { t("products.courier_detail") }
        static var hourlyDetail: String { t("products.hourly_detail") }
        static var hourlyName: String { t("products.hourly_name") }
        static var packageSize: String { t("products.package_size") }
        static var sizeSmall: String { t("products.size_small") }
        static var sizeMedium: String { t("products.size_medium") }
        static var sizeLarge: String { t("products.size_large") }
        static var fragile: String { t("products.fragile") }
        static var recipientName: String { t("products.recipient_name") }
        static var recipientPhone: String { t("products.recipient_phone") }
    }

    // MARK: - Account

    enum Account {
        static var tab: String { t("tab.account") }
        static var title: String { t("account.title") }
        static var payments: String { t("account.payments") }
        static var paymentMethods: String { t("account.payment_methods") }
        static var paymentMethodsDetail: String { t("account.payment_methods_detail") }
        static var wallet: String { t("account.wallet") }
        static var walletDetail: String { t("account.wallet_detail") }
        static var safety: String { t("account.safety") }
        static var safetyDetail: String { t("account.safety_detail") }
        static var safetyToolkit: String { t("account.safety_toolkit") }
        static var settings: String { t("account.settings") }
        static var settingsDetail: String { t("account.settings_detail") }
        static var language: String { t("account.language") }
        static var notifications: String { t("account.notifications") }
        static var privacy: String { t("account.privacy") }
        static var signOut: String { t("account.sign_out") }
        static var preferencesTitle: String { t("account.preferences_title") }
        static var languageFooter: String { t("account.language_footer") }
        static var personalInfo: String { t("account.personal_info") }
        static var tripHistory: String { t("account.trip_history") }
        static var noTripsYet: String { t("account.no_trips_yet") }
        static var recentTripsCount: String { t("account.recent_trips_count") }
        static var trustedContacts: String { t("account.trusted_contacts") }
        static var trustedContactsDetail: String { t("account.trusted_contacts_detail") }
        static var businessProfile: String { t("account.business_profile") }
        static var businessProfileDetail: String { t("account.business_profile_detail") }
        static var promosSection: String { t("account.promos_section") }
        static var promosCredits: String { t("account.promos_credits") }
        static var promosCreditsDetail: String { t("account.promos_credits_detail") }
        static var rewards: String { t("account.rewards") }
        static var rewardsDetail: String { t("account.rewards_detail") }
        static var referFriends: String { t("account.refer_friends") }
        static var referFriendsDetail: String { t("account.refer_friends_detail") }
        static var helpSupport: String { t("account.help_support") }
        static var helpSupportDetail: String { t("account.help_support_detail") }
        static var about: String { t("account.about") }
        static var aboutDetail: String { t("account.about_detail") }
    }

    // MARK: - Settings

    enum Settings {
        static var title: String { t("settings.title") }
        static var preferences: String { t("settings.preferences") }
        static var appPreferences: String { t("settings.app_preferences") }
        static var appPreferencesDetail: String { t("settings.app_preferences_detail") }
        static var inbox: String { t("settings.inbox") }
        static var inboxDetail: String { t("settings.inbox_detail") }
        static var notificationSettings: String { t("settings.notification_settings") }
        static var notificationSettingsDetail: String { t("settings.notification_settings_detail") }
        static var savedPlaces: String { t("settings.saved_places") }
        static var savedPlacesDetail: String { t("settings.saved_places_detail") }
        static var privacyAccess: String { t("settings.privacy_access") }
        static var privacyDetail: String { t("settings.privacy_detail") }
        static var accessibility: String { t("settings.accessibility") }
        static var accessibilityDetail: String { t("settings.accessibility_detail") }
        static var calendar: String { t("settings.calendar") }
        static var calendarDetail: String { t("settings.calendar_detail") }
        static var accountSafety: String { t("settings.account_safety") }
        static var safetySettings: String { t("settings.safety_settings") }
        static var safetySettingsDetail: String { t("settings.safety_settings_detail") }
        static var trustedDetail: String { t("settings.trusted_detail") }
        static var market: String { t("settings.market") }
        static var marketAuto: String { t("settings.market_auto") }
        static var marketDRC: String { t("settings.market_drc") }
        static var marketKenya: String { t("settings.market_kenya") }
        static var activeMarket: String { t("settings.active_market") }
        static var marketFooter: String { t("settings.market_footer") }
        static var maps: String { t("settings.maps") }
        static var distance: String { t("settings.distance") }
        static var kilometers: String { t("settings.kilometers") }
        static var miles: String { t("settings.miles") }
        static var traffic: String { t("settings.traffic") }
        static var etaRefresh: String { t("settings.eta_refresh") }
        static var currency: String { t("settings.currency") }
        static var security: String { t("settings.security") }
        static var securityDetail: String { t("settings.security_detail") }
        static var home: String { t("settings.home") }
        static var work: String { t("settings.work") }
        static var favorites: String { t("settings.favorites") }
        static var recent: String { t("settings.recent") }
        static var setLocation: String { t("settings.set_location") }
        static var addFavorite: String { t("settings.add_favorite") }
        static var noFavorites: String { t("settings.no_favorites") }
        static var shortcuts: String { t("settings.shortcuts") }
        static var searchPlaces: String { t("settings.search_places") }
        static var suggestions: String { t("settings.suggestions") }
        static var results: String { t("settings.results") }
        static var setHome: String { t("settings.set_home") }
        static var setWork: String { t("settings.set_work") }
        static var clearHome: String { t("settings.clear_home") }
        static var clearWork: String { t("settings.clear_work") }
        static var accountStatus: String { t("settings.account_status") }
        static var statusActive: String { t("settings.status_active") }
        static var preferredLanguage: String { t("settings.preferred_language") }
        static var profileName: String { t("settings.profile_name") }
        static var profileContact: String { t("settings.profile_contact") }
        static var firstName: String { t("settings.first_name") }
        static var lastName: String { t("settings.last_name") }
        static var mobile: String { t("settings.mobile") }
        static var email: String { t("settings.email") }
        static var countryCode: String { t("settings.country_code") }
        static var saveChanges: String { t("settings.save_changes") }
        static var profileFooter: String { t("settings.profile_footer") }
        static var profileUpdated: String { t("settings.profile_updated") }
        static var profileUpdatedMsg: String { t("settings.profile_updated_msg") }
        static var locationSection: String { t("settings.location_section") }
        static var preciseLocation: String { t("settings.precise_location") }
        static var preciseLocationNote: String { t("settings.precise_location_note") }
        static var dataSection: String { t("settings.data_section") }
        static var analytics: String { t("settings.analytics") }
        static var personalizedOffers: String { t("settings.personalized_offers") }
        static var activityStatus: String { t("settings.activity_status") }
        static var controls: String { t("settings.controls") }
        static var downloadData: String { t("settings.download_data") }
        static var downloadDataMsg: String { t("settings.download_data_msg") }
        static var deleteAccount: String { t("settings.delete_account") }
        static var deleteAccountBody: String { t("settings.delete_account_body") }
        static var deleteConfirmHint: String { t("settings.delete_confirm_hint") }
        static var deleteConfirmTitle: String { t("settings.delete_confirm_title") }
        static var deleteConfirmMsg: String { t("settings.delete_confirm_msg") }
        static var permissions: String { t("settings.permissions") }
        static var openSystemSettings: String { t("settings.open_system_settings") }
        static var privacyPolicy: String { t("settings.privacy_policy") }
        static var requestSent: String { t("settings.request_sent") }
        static var submitRequest: String { t("settings.submit_request") }
        static var devicePermission: String { t("settings.device_permission") }
        static var pushAlerts: String { t("settings.push_alerts") }
        static var on: String { t("settings.on") }
        static var off: String { t("settings.off") }
        static var enableNotifications: String { t("settings.enable_notifications") }
        static var openSettings: String { t("settings.open_settings") }
        static var pushSection: String { t("settings.push_section") }
        static var tripUpdates: String { t("settings.trip_updates") }
        static var promotions: String { t("settings.promotions") }
        static var productNews: String { t("settings.product_news") }
        static var quietHours: String { t("settings.quiet_hours") }
        static var scheduledReminders: String { t("settings.scheduled_reminders") }
        static var safetyNotifications: String { t("settings.safety_notifications") }
        static var supportUpdates: String { t("settings.support_updates") }
        static var messagesSection: String { t("settings.messages_section") }
        static var smsAlerts: String { t("settings.sms_alerts") }
        static var emailReceipts: String { t("settings.email_receipts") }
        static var notifyFooter: String { t("settings.notify_footer") }
        static var openInbox: String { t("settings.open_inbox") }
        static var legal: String { t("settings.legal") }
        static var terms: String { t("settings.terms") }
        static var community: String { t("settings.community") }
        static var licenses: String { t("settings.licenses") }
        static var operatorLabel: String { t("settings.operator") }
        static var marketsLabel: String { t("settings.markets") }
        static var version: String { t("settings.version") }
        static var build: String { t("settings.build") }
        static var appLock: String { t("settings.app_lock") }
        static var biometric: String { t("settings.biometric") }
        static var activeSessions: String { t("settings.active_sessions") }
        static var thisDevice: String { t("settings.this_device") }
        static var recentSignIns: String { t("settings.recent_sign_ins") }
        static var signOutOthers: String { t("settings.sign_out_others") }
        static var locationPermission: String { t("settings.location_permission") }
        static var micPermission: String { t("settings.mic_permission") }
        static var notificationPermission: String { t("settings.notification_permission") }
        static var enableLocation: String { t("settings.enable_location") }
        static var signOutOthersDone: String { t("settings.sign_out_others_done") }
    }

    // MARK: - Activity

    enum Activity {
        static var tab: String { t("tab.activity") }
        static var title: String { t("activity.title") }
        static var emptyTitle: String { t("activity.empty_title") }
        static var emptyDetail: String { t("activity.empty_detail") }
    }

    // MARK: - Trip

    enum Trip {
        static var searching: String { t("trip.searching") }
        static var searchingDetail: String { t("trip.searching_detail") }
        static var driverEnRoute: String { t("trip.driver_en_route") }
        static var headingToPickup: String { t("trip.heading_to_pickup") }
        static var driverArrived: String { t("trip.driver_arrived") }
        static var meetAtPickup: String { t("trip.meet_at_pickup") }
        static var headingToDestination: String { t("trip.heading_to_destination") }
        static var onTheWay: String { t("trip.on_the_way") }
        static var arrived: String { t("trip.arrived") }
        static var chooseRide: String { t("trip.choose_ride") }
        static var confirmRide: String { t("trip.confirm_ride") }
        static var cancel: String { t("trip.cancel") }
        static var rideNow: String { t("trip.ride_now") }
        static var nearbyCars: String { t("trip.nearby_cars") }
        static var cancelRequest: String { t("trip.cancel_request") }
        static var cancelRequestTitle: String { t("trip.cancel_request_title") }
        static var cancelTrip: String { t("trip.cancel_trip") }
        static var cancelTripTitle: String { t("trip.cancel_trip_title") }
        static var adjustPickup: String { t("trip.adjust_pickup") }
        static var changeDestination: String { t("trip.change_destination") }
        static var addStop: String { t("trip.add_stop") }
        static var forMe: String { t("trip.for_me") }
        static var forOthers: String { t("trip.for_others") }
        static var promoCode: String { t("trip.promo_code") }
        static var promoApplied: String { t("trip.promo_applied") }
        static var passengerName: String { t("trip.passenger_name") }
        static var passengerPhone: String { t("trip.passenger_phone") }
        static var tripPIN: String { t("trip.trip_pin") }
        static var enterPIN: String { t("trip.enter_pin") }
        static var pinHint: String { t("trip.pin_hint") }
        static var pinMismatch: String { t("trip.pin_mismatch") }
        static var confirmBoarding: String { t("trip.confirm_boarding") }
        static var confirmTier: String { t("trip.confirm_tier") }
        static var reserveTier: String { t("trip.reserve_tier") }
        static var rideFallback: String { t("trip.ride_fallback") }
    }

    // MARK: - Destination search

    enum Destination {
        static var choose: String { t("destination.choose") }
        static var addStop: String { t("destination.add_stop") }
        static var searchPlaces: String { t("destination.search_places") }
        static var searchStop: String { t("destination.search_stop") }
        static var favorites: String { t("destination.favorites") }
        static var recent: String { t("destination.recent") }
        static var results: String { t("destination.results") }
        static var suggestions: String { t("destination.suggestions") }
        static var stops: String { t("destination.stops") }
        static var savedPlaces: String { t("destination.saved_places") }
        static var addHome: String { t("destination.add_home") }
        static var addWork: String { t("destination.add_work") }
        static var homeSubtitle: String { t("destination.home_subtitle") }
        static var workSubtitle: String { t("destination.work_subtitle") }
        static var setHome: String { t("destination.set_home") }
        static var setWork: String { t("destination.set_work") }
        static var stopProgress: String { t("destination.stop_progress") }
        static var favoritesHint: String { t("destination.favorites_hint") }
        static var noMatchingPlaces: String { t("destination.no_matching_places") }
        static var searchingPlaces: String { t("destination.searching_places") }
        static var couldNotOpenPlace: String { t("destination.could_not_open_place") }
        static var searchNewDestination: String { t("destination.search_new") }
        static var routeUnavailable: String { t("maps.error.no_route") }
        static var mapsUnavailable: String { t("maps.error.unavailable") }
    }

    // MARK: - Maps errors (rider-facing; never mention Google / HTTP / keys)

    enum Maps {
        static var unavailable: String { t("maps.error.unavailable") }
        static var busy: String { t("maps.error.busy") }
        static var temporary: String { t("maps.error.temporary") }
        static var generic: String { t("maps.error.generic") }
        static var network: String { t("maps.error.network") }
        static var noRoute: String { t("maps.error.no_route") }
        static var timeout: String { t("maps.error.temporary") }

        static var unavailableTitle: String { t("map.unavailable_title") }
        static var unavailableDetail: String { t("map.unavailable_detail") }
        static var a11yHome: String { t("map.a11y_home") }
        static var a11yPreview: String { t("map.a11y_preview") }
        static var a11yMatching: String { t("map.a11y_matching") }
        static var a11yApproach: String { t("map.a11y_approach") }
        static var a11yActive: String { t("map.a11y_active") }
        static var a11yCompleted: String { t("map.a11y_completed") }

        // Underscore keys used by `GoogleAPIError.riderMessageKey`
        static var errorUnavailable: String { t("maps.error_unavailable") }
        static var errorBusy: String { t("maps.error_busy") }
        static var errorTimeout: String { t("maps.error_timeout") }
        static var errorOffline: String { t("maps.error_offline") }
        static var errorGeneric: String { t("maps.error_generic") }
        static var errorNoRoute: String { t("maps.error_no_route") }
    }

    // MARK: - Permissions

    enum Permissions {
        static var title: String { t("permissions.title") }
        static var intro: String { t("permissions.intro") }
        static var location: String { t("permissions.location") }
        static var locationDetail: String { t("permissions.location_detail") }
        static var notifications: String { t("permissions.notifications") }
        static var notificationsDetail: String { t("permissions.notifications_detail") }
        static var microphone: String { t("permissions.microphone") }
        static var microphoneDetail: String { t("permissions.microphone_detail") }
        static var camera: String { t("permissions.camera") }
        static var cameraDetail: String { t("permissions.camera_detail") }
        static var motion: String { t("permissions.motion") }
        static var motionDetail: String { t("permissions.motion_detail") }
        static var changeAnytime: String { t("permissions.change_anytime") }
    }

    // MARK: - Safety

    enum Safety {
        static var title: String { t("safety.title") }
        static var sos: String { t("safety.sos") }
        static var helpRequested: String { t("safety.help_requested") }
        static var requestHelp: String { t("safety.request_help") }
        static var requestHelpConfirm: String { t("safety.request_help_confirm") }
        static var requestHelpNow: String { t("safety.request_help_now") }
        static var requestHelpBody: String { t("safety.request_help_body") }
        static var emergencyRequested: String { t("safety.emergency_requested") }
        static var emergencyDetail: String { t("safety.emergency_detail") }
        static var shareTrip: String { t("safety.share_trip") }
        static var shareSubject: String { t("safety.share_subject") }
        static var shareMessage: String { t("safety.share_message") }
        static var recordingNotice: String { t("safety.recording_notice") }
        static var recordAudio: String { t("safety.record_audio") }
        static var stopRecording: String { t("safety.stop_recording") }
        static var audioFooter: String { t("safety.audio_footer") }
    }

    // MARK: - Legal / About

    enum Legal {
        static var about: String { t("legal.about") }
        static var app: String { t("legal.app") }
        static var version: String { t("legal.version") }
        static var build: String { t("legal.build") }
        static var legal: String { t("legal.section") }
        static var terms: String { t("legal.terms") }
        static var privacy: String { t("legal.privacy") }
        static var guidelines: String { t("legal.guidelines") }
        static var licenses: String { t("legal.licenses") }
        static var operatorSection: String { t("legal.operator_section") }
        static var operatorName: String { t("legal.operator_name") }
        static var markets: String { t("legal.markets") }
        static var marketsValue: String { t("legal.markets_value") }
        static var diagnostics: String { t("legal.diagnostics") }
        static var diagnosticsUnlocked: String { t("legal.diagnostics_unlocked") }
        static var diagnosticsUnlockedMsg: String { t("legal.diagnostics_unlocked_msg") }
    }

    // MARK: - Places / Route rider errors

    enum Places {
        static var errorUnavailable: String { t("places.error_unavailable") }
        static var errorOffline: String { t("places.error_offline") }
        static var errorGeneric: String { t("places.error_generic") }
        static var errorNoResults: String { t("places.error_no_results") }
    }

    enum Route {
        static var errorUnable: String { t("route.error_unable") }
        static var deviationTitle: String { t("route.deviation_title") }
        static var deviationNotice: String { t("route.deviation_notice") }
        static var deviationBody: String { t("route.deviation_body") }
    }

    // MARK: Catalog

    private static let catalog: [String: [AppLanguage: String]] = [
        // Tabs
        "tab.home": s("Home", "Accueil", "Ndako", "Nyumbani"),
        "tab.services": s("Services", "Services", "Misala", "Huduma"),
        "tab.activity": s("Activity", "Activité", "Misala", "Shughuli"),
        "tab.account": s("Account", "Compte", "Konti", "Akaunti"),

        // Common
        "common.cancel": s("Cancel", "Annuler", "Longola", "Ghairi"),
        "common.close": s("Close", "Fermer", "Fungola", "Funga"),
        "common.continue": s("Continue", "Continuer", "Koba", "Endelea"),
        "common.next": s("Next", "Suivant", "Oyo elandi", "Ifuatayo"),
        "common.back": s("Back", "Retour", "Zonga", "Rudi"),
        "common.save": s("Save", "Enregistrer", "Bomba", "Hifadhi"),
        "common.delete": s("Delete", "Supprimer", "Longola", "Futa"),
        "common.or": s("or", "ou", "to", "au"),
        "common.apply": s("Apply", "Appliquer", "Salisa", "Tumia"),
        "common.change": s("Change", "Modifier", "Bobongola", "Badilisha"),
        "common.got_it": s("Got it", "Compris", "Nazoki", "Nimeelewa"),
        "common.clear": s("Clear", "Effacer", "Longola", "Futa"),
        "common.not_set": s("Not set", "Non défini", "Eza te", "Haijawekwa"),

        // Auth
        "auth.get_started_title": s("Get started with Vuum", "Commencez avec Vuum", "Bandela na Vuum", "Anza na Vuum"),
        "auth.mobile_number": s("Mobile number", "Numéro de mobile", "Numéro ya téléphone", "Nambari ya simu"),
        "auth.continue_apple": s("Continue with Apple", "Continuer avec Apple", "Koba na Apple", "Endelea na Apple"),
        "auth.continue_google": s("Continue with Google", "Continuer avec Google", "Koba na Google", "Endelea na Google"),
        "auth.continue_email": s("Continue with Email", "Continuer avec e-mail", "Koba na email", "Endelea na barua pepe"),
        "auth.find_account": s("Find my account", "Retrouver mon compte", "Luka konti na ngai", "Tafuta akaunti yangu"),
        "auth.sms_disclaimer": s(
            "By continuing, you may receive SMS or WhatsApp messages for verification. Message and data rates may apply.",
            "En continuant, vous pouvez recevoir des SMS ou messages WhatsApp pour vérification. Des frais peuvent s'appliquer.",
            "Soki okobi, okokoka kozwa SMS to WhatsApp mpo na vérification. Ba frais ekoki kozala.",
            "Ukienendelea, unaweza kupokea SMS au WhatsApp za uthibitishaji. Gharama za ujumbe zinaweza kutumika."
        ),
        "auth.otp_prompt": s(
            "Enter the 4-digit code sent to you at %@.",
            "Saisissez le code à 4 chiffres envoyé au %@.",
            "Kotia code ya ba chiffre 4 oyo etindami na %@.",
            "Weka msimbo wa tarakimu 4 uliotumwa kwa %@."
        ),
        "auth.changed_number": s("Changed your mobile number?", "Vous avez changé de numéro ?", "Obongoli numéro ?", "Umebadilisha nambari?"),
        "auth.resend_sms": s("Resend code via SMS", "Renvoyer le code par SMS", "Tinda code lisusu na SMS", "Tuma tena msimbo kwa SMS"),
        "auth.backup_code": s("Use Backup Code", "Utiliser un code de secours", "Salisa code ya backup", "Tumia msimbo wa akiba"),
        "auth.digit_a11y": s("Digit %d", "Chiffre %d", "Chiffre %d", "Tarakimu %d"),
        "auth.terms_title": s(
            "Accept Vuum’s Terms & Review Privacy Notice",
            "Accepter les conditions Vuum et consulter la confidentialité",
            "Ndimisa ba Conditions ya Vuum mpe Privacy",
            "Kubali Masharti ya Vuum na Soma Faragha"
        ),
        "auth.terms_body_lead": s(
            "By selecting “I Agree” below, I have reviewed and agree to the ",
            "En sélectionnant « J’accepte » ci-dessous, j’ai lu et j’accepte les ",
            "Na kopona “Nandimi” awa, natali mpe nandimi ",
            "Kwa kuchagua “Nakubali” hapa chini, nimesoma na ninakubali "
        ),
        "auth.terms_of_use": s("Terms of Use", "Conditions d’utilisation", "Ba Conditions", "Masharti ya Matumizi"),
        "auth.terms_body_mid": s(" and acknowledge the ", " et je prends connaissance de la ", " mpe nazali koyeba ", " na ninakubali "),
        "auth.privacy_notice": s("Privacy Notice", "Notice de confidentialité", "Privacy Notice", "Ilani ya Faragha"),
        "auth.terms_body_age": s(". I am at least 18 years of age.", ". J’ai au moins 18 ans.", ". Nazali na mbula 18 to koleka.", ". Nina angalau miaka 18."),
        "auth.i_agree": s("I Agree", "J’accepte", "Nandimi", "Nakubali"),
        "auth.confirm_info": s("Confirm your information", "Confirmez vos informations", "Ndimisa ba informations", "Thibitisha maelezo yako"),
        "auth.first_name": s("First name", "Prénom", "Kombo ya liboso", "Jina la kwanza"),
        "auth.last_name": s("Last name", "Nom", "Kombo ya nsuka", "Jina la ukoo"),
        "auth.welcome": s("Welcome to Vuum", "Bienvenue sur Vuum", "Boyei malamu na Vuum", "Karibu Vuum"),
        "auth.customizing": s("Customizing your experience…", "Personnalisation en cours…", "Tokosalisa expérience…", "Inabina uzoefu wako…"),
        "auth.country_code": s("Country code", "Indicatif pays", "Code ya mboka", "Msimbo wa nchi"),
        "auth.search_country": s("Search country or code", "Rechercher un pays ou un code", "Luka mboka to code", "Tafuta nchi au msimbo"),
        "auth.no_countries": s("No countries match", "Aucun pays ne correspond", "Mboka ezwami te", "Hakuna nchi inayolingana"),
        "auth.clear_search": s("Clear search", "Effacer la recherche", "Longola boluki", "Futa utafutaji"),
        "auth.phone_invalid": s(
            "Enter a valid mobile number for your country.",
            "Saisissez un numéro valide pour votre pays.",
            "Tyá numéro ya téléphone oyo eza malamu.",
            "Weka nambari sahihi ya simu kwa nchi yako."
        ),
        "auth.otp_invalid": s(
            "That code is incorrect. Try again.",
            "Ce code est incorrect. Réessayez.",
            "Code oyo eza mabe. Meka lisusu.",
            "Msimbo si sahihi. Jaribu tena."
        ),
        "auth.otp_expired": s(
            "This code has expired. Request a new one.",
            "Ce code a expiré. Demandez-en un nouveau.",
            "Code oyo esili. Senga mosusu.",
            "Msimbo umeisha muda. Omba mpya."
        ),
        "auth.otp_too_many": s(
            "Too many attempts. Resend a new code.",
            "Trop de tentatives. Renvoyez un nouveau code.",
            "Ba tentatives ebele. Tinda code ya sika.",
            "Jaribio nyingi mno. Tuma msimbo mpya."
        ),
        "auth.name_invalid": s(
            "Enter your first and last name (at least 2 letters each).",
            "Saisissez votre prénom et nom (2 lettres minimum).",
            "Tyá kombo ya liboso mpe ya nsuka.",
            "Weka jina la kwanza na la ukoo (herufi 2+)."
        ),
        "auth.email_invalid": s(
            "Enter a valid email, or leave it blank.",
            "Saisissez un e-mail valide, ou laissez vide.",
            "Tyá email oyo eza malamu, to tiká mpamba.",
            "Weka barua pepe sahihi, au acha wazi."
        ),
        "auth.email_optional": s("Email (optional)", "E-mail (facultatif)", "Email (si olingi)", "Barua pepe (si hiari)"),
        "auth.resend_in": s("Resend in %d s", "Renvoyer dans %d s", "Tinda na %d s", "Tuma tena baada ya %d s"),
        "auth.backup_title": s("Backup code", "Code de secours", "Code ya backup", "Msimbo wa akiba"),
        "auth.backup_hint": s(
            "Enter your 4-digit backup code.",
            "Saisissez votre code de secours à 4 chiffres.",
            "Tyá code ya backup ya ba chiffres 4.",
            "Weka msimbo wako wa akiba wa tarakimu 4."
        ),
        "auth.backup_submit": s("Verify backup code", "Vérifier le code", "Ndimisa code", "Thibitisha msimbo"),
        "auth.terms_document": s(
            "By using Vuum you agree to Congo Mobility SARL’s terms for booking rides, payments in CDF and USD (and KES where applicable), cancellations, and conduct toward drivers and riders.\n\nCorporate and field-sales programs may include additional agreements.",
            "En utilisant Vuum, vous acceptez les conditions de Congo Mobility SARL pour les courses, les paiements en CDF et USD (et KES le cas échéant), les annulations et le comportement envers chauffeurs et passagers.\n\nLes programmes entreprise et terrain peuvent inclure des accords supplémentaires.",
            "Na kosalela Vuum, ondimisi ba conditions ya Congo Mobility SARL mpo na ba voyage, ba paiement na CDF mpe USD, ba annulation mpe bozali malamu na ba chauffeur.\n\nBa programme ya entreprise ekoki kozala na ba accord mosusu.",
            "Kwa kutumia Vuum unakubali masharti ya Congo Mobility SARL kuhusu safari, malipo ya CDF na USD (na KES inapohitajika), kughairi, na mwenendo kwa madereva na abiria.\n\nProgramu za kampuni zinaweza kuwa na mikataba ya ziada."
        ),
        "auth.privacy_document": s(
            "Vuum processes account details, trip locations, and payment preferences to provide rides and safety features.\n\nYou can manage sharing preferences under Privacy in Settings after you sign in.",
            "Vuum traite les informations de compte, les positions de trajet et les préférences de paiement pour fournir les courses et les fonctions de sécurité.\n\nVous pourrez gérer le partage dans Confidentialité après connexion.",
            "Vuum esaleli ba renseignements ya konti, ba localisation ya voyage mpe ba préférences ya paiement mpo na kosalisa ba voyage mpe libateli.\n\nOkoki kobongola partage na Privacy na Settings.",
            "Vuum huchakata taarifa za akaunti, maeneo ya safari, na mapendeleo ya malipo ili kutoa safari na vipengele vya usalama.\n\nUnaweza kudhibiti ushiriki chini ya Faragha katika Mipangilio baada ya kuingia."
        ),
        "auth.sending_code": s("Sending code…", "Envoi du code…", "Kotinda code…", "Inatuma msimbo…"),
        "auth.verifying_code": s("Verifying…", "Vérification…", "Vérification…", "Inathibitisha…"),

        // Home
        "home.where_to": s("Where to?", "Où allez-vous ?", "Okende wapi ?", "Unakwenda wapi?"),
        "home.pickup": s("Pickup", "Prise en charge", "Esika ya kozwa", "Mahali pa kuchukuliwa"),
        "home.adjust": s("Adjust", "Ajuster", "Bobongola", "Rekebisha"),
        "home.now": s("Now", "Maintenant", "Sika oyo", "Sasa"),
        "home.later": s("Later", "Plus tard", "Na nsima", "Baadaye"),
        "home.upcoming": s("Upcoming", "À venir", "Eya", "Zijazo"),
        "home.tagline": s(
            "Ride across Lubumbashi & Kolwezi",
            "Déplacez-vous à Lubumbashi et Kolwezi",
            "Tambola na Lubumbashi mpe Kolwezi",
            "Safari Lubumbashi na Kolwezi"
        ),
        "home.tagline_kenya": s(
            "Ride across Nairobi",
            "Déplacez-vous à Nairobi",
            "Tambola na Nairobi",
            "Safari Nairobi"
        ),
        "home.rides": s("Rides", "Courses", "Ba voyage", "Safari"),
        "home.eats": s("Eats", "Repas", "Biléyi", "Chakula"),
        "home.suggestions": s("Suggestions", "Suggestions", "Ba suggestion", "Mapendekezo"),
        "home.safety": s("Safety", "Sécurité", "Libateli", "Usalama"),
        "home.recent": s("Recent", "Récents", "Ya sika", "Za hivi karibuni"),
        "home.recenter": s("Recenter map", "Recentrer la carte", "Zongisa carte", "Rejesha ramani"),
        "home.add_home": s("Add Home", "Ajouter Maison", "Bakisa Ndako", "Ongeza Nyumbani"),
        "home.add_work": s("Add Work", "Ajouter Travail", "Bakisa Mosala", "Ongeza Kazini"),
        "home.promo_title": s("Ride farther for less", "Allez plus loin pour moins", "Tambola mosika na ntalo ya moke", "Safari zaidi kwa bei nafuu"),
        "home.promo_badge": s("Promo", "Promo", "Promo", "Promo"),
        "home.eats_search": s("Search restaurants & dishes", "Rechercher restaurants et plats", "Luka ba restaurant mpe biléyi", "Tafuta migahawa na vyakula"),
        "home.eats_nearby": s("Nearby", "À proximité", "Pene na yo", "Karibu"),
        "home.eats_expanding": s(
            "Food delivery is expanding neighborhood by neighborhood.",
            "La livraison de repas s’étend quartier par quartier.",
            "Livraison ya biléyi ezali kokota quartier na quartier.",
            "Uwasilishaji wa chakula unaenea mtaa baada ya mtaa."
        ),
        "home.where_to_hint": s("Search for a destination", "Rechercher une destination", "Luka esika okende", "Tafuta mahali pa kwenda"),
        "home.schedule_pickup": s("Schedule pickup", "Planifier la prise en charge", "Bokisa oyo ya kozwa", "Panga uchukuzi"),
        "home.browse_services": s("Browse services", "Parcourir les services", "Tala misala", "Vinjari huduma"),

        // Services
        "services.title": s("Services", "Services", "Misala", "Huduma"),
        "services.ride_section": s("Ride", "Course", "Voyage", "Safari"),
        "services.more_section": s("More", "Plus", "Mosusu", "Zaidi"),
        "services.go_anywhere": s("Go anywhere", "Allez partout", "Kende bisika nyonso", "Nenda popote"),
        "services.get_delivered": s("Get anything delivered", "Faites-vous livrer", "Zwa livraison", "Pata uwasilishaji"),
        "services.rides": s("Rides", "Courses", "Ba voyage", "Safari"),
        "services.rides_detail": s(
            "Point-to-point rides around the city",
            "Trajets de point à point en ville",
            "Ba voyage na kati ya engumba",
            "Safari kutoka sehemu hadi sehemu mjini"
        ),
        "services.comfort": s("Comfort", "Confort", "Comfort", "Starehe"),
        "services.comfort_detail": s(
            "Newer cars with extra space",
            "Voitures plus récentes avec plus d'espace",
            "Ba voiture ya sika na esika ebele",
            "Magari mapya yenye nafasi zaidi"
        ),
        "services.xl": s("Vuum XXL", "Vuum XXL", "Vuum XXL", "Vuum XXL"),
        "services.xl_detail": s(
            "Up to 6 passengers · larger vehicles",
            "Jusqu’à 6 passagers · véhicules plus grands",
            "Bato 6 · ba véhicule ya monene",
            "Abiria 6 · magari makubwa"
        ),
        "services.executive": s("Executive", "Exécutif", "Executive", "Executive"),
        "services.executive_detail": s(
            "Premium cars · top-rated drivers",
            "Voitures premium · chauffeurs mieux notés",
            "Ba voiture ya malamu · ba chauffeur ya rating ya likolo",
            "Magari bora · madereva wenye rating juu"
        ),
        "services.reserve": s("Reserve", "Réserver", "Koboka", "Weka nafasi"),
        "services.reserve_detail": s(
            "Schedule a pickup ahead of time",
            "Planifier une prise en charge à l'avance",
            "Bokisa oyo ya kozwa liboso",
            "Panga uchukuzi mapema"
        ),
        "services.courier": s("Courier", "Courrier", "Courier", "Usafirishaji"),
        "services.courier_detail": s(
            "Send packages across town",
            "Envoyez des colis en ville",
            "Tinda ba colis na engumba",
            "Tuma vifurushi mjini"
        ),
        "services.corporate": s("Corporate", "Entreprise", "Entreprise", "Kampuni"),
        "services.corporate_detail": s(
            "Business travel profiles",
            "Profils de déplacement professionnel",
            "Ba profil ya mosala",
            "Wasifu wa safari za biashara"
        ),
        "services.upcoming_reservations": s(
            "Upcoming reservations",
            "Réservations à venir",
            "Ba réservation oyo eza koya",
            "Uhifadhi ujao"
        ),
        "services.two_wheels": s("2-Wheels", "2-Roues", "Mabike 2", "Magurudumu 2"),
        "services.rental": s("Rental", "Location", "Location", "Kukodisha"),
        "services.hourly": s("Hourly", "À l’heure", "Na ngonga", "Kwa saa"),
        "services.group_ride": s("Group Ride", "Course de groupe", "Voyage ya groupe", "Safari ya kikundi"),
        "services.coming_soon_body": s(
            "%@ is rolling out neighborhood by neighborhood. Check back here when it's live near you.",
            "%@ arrive quartier par quartier. Revenez quand ce sera disponible près de chez vous.",
            "%@ ezali koyangela quartier na quartier. Zonga soki esili pene na yo.",
            "%@ inafunguliwa mtaa kwa mtaa. Rudi hapa itakapokuwa karibu nawe."
        ),
        "services.available_in_city": s("Available in your city", "Disponible dans votre ville", "Ezali na engumba na yo", "Inapatikana katika jiji lako"),
        "services.promo_badge": s("Promo", "Promo", "Promo", "Promo"),
        "services.food": s("Food", "Repas", "Biléyi", "Chakula"),
        "services.grocery": s("Grocery", "Épicerie", "Magasin", "Mboga"),
        "services.convenience": s("Convenience", "Proximité", "Esika pene", "Duka la karibu"),
        "services.alcohol": s("Alcohol", "Alcool", "Malafu", "Pombe"),
        "services.health": s("Health", "Santé", "Bolamu", "Afya"),
        "services.packages": s("Packages", "Colis", "Ba colis", "Vifurushi"),

        // Products
        "products.continue_to_book": s("Continue to book", "Continuer la réservation", "Koba na booking", "Endelea kuhifadhi"),
        "products.pickup": s("Pickup", "Prise en charge", "Esika ya kozwa", "Mahali pa kuchukuliwa"),
        "products.dropoff": s("Drop-off", "Destination", "Esika ya kopesa", "Mahali pa kushusha"),
        "products.from": s("From", "De", "Uta", "Kutoka"),
        "products.to": s("To", "Vers", "Na", "Kwenda"),
        "products.two_wheels_subtitle": s(
            "Beat traffic with a bike or scooter for short city trips.",
            "Évitez le trafic en vélo ou scooter pour les courts trajets.",
            "Pasa traffic na bike to scooter mpo na ba voyage ya moke.",
            "Epuka msongamano kwa baiskeli au skuta kwa safari fupi."
        ),
        "products.two_wheels_note": s(
            "Available in your city for solo riders. Helmets provided by the partner.",
            "Disponible en ville pour les trajets solo. Casques fournis par le partenaire.",
            "Ezali na engumba mpo na moto moko. Ba casque ezali na partenaire.",
            "Inapatikana mjini kwa msafiri mmoja. Helmet hutolewa na mshirika."
        ),
        "products.courier_subtitle": s(
            "Send a package across town with pickup and delivery notes.",
            "Envoyez un colis en ville avec des notes de livraison.",
            "Tinda colis na engumba na ba notes ya livraison.",
            "Tuma kifurushi mjini na maelezo ya uchukuaji na uwasilishaji."
        ),
        "products.package_details": s("Package details", "Détails du colis", "Ba détails ya colis", "Maelezo ya kifurushi"),
        "products.package_notes": s(
            "Size, fragile items, recipient name…",
            "Taille, objets fragiles, nom du destinataire…",
            "Bonene, biloko ya fragile, kombo ya oyo azwa…",
            "Ukubwa, vitu dhaifu, jina la mpokeaji…"
        ),
        "products.hourly_subtitle": s(
            "Keep a driver with you for errands, meetings, or wait-and-return.",
            "Gardez un chauffeur pour courses, réunions ou aller-retour.",
            "Bika chauffeur na yo mpo na ba courses, ba reunion to kozonga.",
            "Weka dereva kwa shughuli, mikutano au kurudi."
        ),
        "products.duration": s("Duration", "Durée", "Ngonga", "Muda"),
        "products.hours": s("Hours", "Heures", "Ba ngonga", "Masaa"),
        "products.hour_singular": s("1 hour", "1 heure", "Ngonga 1", "Saa 1"),
        "products.hours_plural": s("%d hours", "%d heures", "Ba ngonga %d", "Masaa %d"),
        "products.hourly_fare_note": s(
            "Estimated fare updates for %d hour(s) once you continue.",
            "Le tarif estimé se met à jour pour %d heure(s) ensuite.",
            "Tarif eza kobongwana mpo na ngonga %d soki okobi.",
            "Makadirio ya nauli yatasasishwa kwa saa %d ukiendelea."
        ),
        "products.group_subtitle": s(
            "Book a larger vehicle when you're traveling with friends or colleagues.",
            "Réservez un plus grand véhicule avec amis ou collègues.",
            "Boka voiture ya monene soki otamboli na ba ami to ba collègue.",
            "Hifadhi gari kubwa unaposafiri na marafiki au wenzako."
        ),
        "products.passengers": s("Passengers", "Passagers", "Ba passager", "Abiria"),
        "products.seats": s("%d seats", "%d places", "Ba place %d", "Viti %d"),
        "products.group_note": s(
            "We'll prefer Vuum XXL for groups of three or more.",
            "Nous privilégions Vuum XXL pour les groupes de trois ou plus.",
            "Tokopona Vuum XXL mpo na groupe ya batu 3 to koleka.",
            "Tutapendelea Vuum XXL kwa vikundi vya watatu au zaidi."
        ),
        "products.two_wheels_detail": s("Quick trips · bike or scooter", "Trajets rapides · vélo ou scooter", "Voyage ya noki · bike to scooter", "Safari za haraka · baiskeli au skuta"),
        "products.courier_detail": s("On-demand package delivery", "Livraison de colis à la demande", "Livraison ya colis na demande", "Uwasilishaji wa kifurushi kwa mahitaji"),
        "products.hourly_detail": s("Driver stays with you for the booked time", "Le chauffeur reste avec vous", "Chauffeur abikali na yo", "Dereva anakaa nawe kwa muda uliohifadhiwa"),
        "products.hourly_name": s("Hourly · %d hr", "À l’heure · %d h", "Na ngonga · %d h", "Kwa saa · %d saa"),
        "products.package_size": s("Size", "Taille", "Bonene", "Ukubwa"),
        "products.size_small": s("Small", "Petit", "Moke", "Ndogo"),
        "products.size_medium": s("Medium", "Moyen", "Kati", "Wastani"),
        "products.size_large": s("Large", "Grand", "Monene", "Kubwa"),
        "products.fragile": s("Fragile handling", "Fragile", "Fragile", "Dhaifu"),
        "products.recipient_name": s("Recipient name", "Nom du destinataire", "Kombo ya oyo azwa", "Jina la mpokeaji"),
        "products.recipient_phone": s("Recipient phone", "Téléphone du destinataire", "Téléphone ya oyo azwa", "Simu ya mpokeaji"),

        // Account
        "account.title": s("Account", "Compte", "Konti", "Akaunti"),
        "account.payments": s("Payments", "Paiements", "Ba paiement", "Malipo"),
        "account.payment_methods": s("Payment methods", "Moyens de paiement", "Ba méthode ya kobongisa", "Njia za malipo"),
        "account.payment_methods_detail": s("Cash, Mobile Money, card", "Espèces, Mobile Money, carte", "Cash, Mobile Money, carte", "Pesa taslimu, Mobile Money, kadi"),
        "account.wallet": s("Wallet", "Portefeuille", "Portefeuille", "Pochi"),
        "account.wallet_detail": s("CDF & USD balances", "Soldes CDF et USD", "Ba solde CDF mpe USD", "Salio za CDF na USD"),
        "account.safety": s("Safety", "Sécurité", "Libateli", "Usalama"),
        "account.safety_detail": s("SOS, trip share, PIN", "SOS, partage de trajet, PIN", "SOS, partage ya voyage, PIN", "SOS, shiriki safari, PIN"),
        "account.safety_toolkit": s("Safety toolkit", "Outils de sécurité", "Ba outil ya libateli", "Zana za usalama"),
        "account.settings": s("App settings", "Réglages", "Ba paramètre", "Mipangilio"),
        "account.settings_detail": s("Language, privacy, alerts", "Langue, confidentialité, alertes", "Monɔkɔ, privacy, ba alerte", "Lugha, faragha, arifa"),
        "account.language": s("Language", "Langue", "Monɔkɔ", "Lugha"),
        "account.notifications": s("Notifications", "Notifications", "Ba notification", "Arifa"),
        "account.privacy": s("Privacy", "Confidentialité", "Privacy", "Faragha"),
        "account.sign_out": s("Sign out", "Se déconnecter", "Kobima", "Toka"),
        "account.preferences_title": s("App preferences", "Préférences", "Ba préférences", "Mapendeleo"),
        "account.language_footer": s(
            "Language preference is saved on this device.",
            "La préférence de langue est enregistrée sur cet appareil.",
            "Monɔkɔ ekobombama na téléphone oyo.",
            "Mapendeleo ya lugha yanahifadhiwa kwenye kifaa hiki."
        ),
        "account.personal_info": s("Personal info", "Infos personnelles", "Ba infos ya yo", "Maelezo binafsi"),
        "account.trip_history": s("Trip history", "Historique des trajets", "Histoire ya ba voyage", "Historia ya safari"),
        "account.no_trips_yet": s("No trips yet", "Aucun trajet pour l’instant", "Voyage te sika oyo", "Bado hakuna safari"),
        "account.recent_trips_count": s("%d recent trips", "%d trajets récents", "Ba voyage ya sika %d", "Safari %d za hivi karibuni"),
        "account.trusted_contacts": s("Trusted contacts", "Contacts de confiance", "Ba contact ya confiance", "Anwani za kuaminika"),
        "account.trusted_contacts_detail": s("Share live trip status", "Partager le trajet en direct", "Partager statut ya voyage", "Shiriki hali ya safari moja kwa moja"),
        "account.business_profile": s("Business profile", "Profil entreprise", "Profil ya mosala", "Wasifu wa biashara"),
        "account.business_profile_detail": s("Corporate travel", "Déplacements professionnels", "Ba voyage ya entreprise", "Safari za kampuni"),
        "account.promos_section": s("Promos & invites", "Promos et invitations", "Ba promo mpe ba invitation", "Promo na mialiko"),
        "account.promos_credits": s("Promos & credits", "Promos et crédits", "Ba promo mpe ba crédit", "Promo na mikopo"),
        "account.promos_credits_detail": s("Add voucher codes", "Ajouter des codes promo", "Bakisa ba code", "Ongeza misimbo ya vocha"),
        "account.rewards": s("Vuum Rewards", "Vuum Rewards", "Vuum Rewards", "Vuum Rewards"),
        "account.rewards_detail": s("Points & member perks", "Points et avantages", "Ba points mpe ba avantages", "Pointi na manufaa"),
        "account.refer_friends": s("Refer friends", "Parrainer des amis", "Benga ba ami", "Alika marafiki"),
        "account.refer_friends_detail": s("Invite riders · earn credit", "Invitez · gagnez du crédit", "Benga · zwa crédit", "Alika · pata mkopo"),
        "account.help_support": s("Help & support", "Aide et assistance", "Aide mpe support", "Msaada na usaidizi"),
        "account.help_support_detail": s("Trips, payments, safety", "Trajets, paiements, sécurité", "Ba voyage, ba paiement, libateli", "Safari, malipo, usalama"),
        "account.about": s("About", "À propos", "Mpo na", "Kuhusu"),
        "account.about_detail": s("Legal & app info", "Mentions légales", "Ba infos ya app", "Maelezo ya kisheria na programu"),

        // Settings
        "settings.title": s("Settings", "Réglages", "Ba paramètre", "Mipangilio"),
        "settings.preferences": s("Preferences", "Préférences", "Ba préférences", "Mapendeleo"),
        "settings.app_preferences": s("App preferences", "Préférences", "Ba préférences", "Mapendeleo ya programu"),
        "settings.app_preferences_detail": s("Language & market", "Langue et marché", "Monɔkɔ mpe marché", "Lugha na soko"),
        "settings.inbox": s("Inbox", "Boîte de réception", "Boîte", "Kikasha"),
        "settings.inbox_detail": s("Trips & offers", "Trajets et offres", "Ba voyage mpe ba offre", "Safari na ofa"),
        "settings.notification_settings": s("Notification settings", "Notifications", "Ba notification", "Mipangilio ya arifa"),
        "settings.notification_settings_detail": s("Push, SMS, email", "Push, SMS, e-mail", "Push, SMS, email", "Push, SMS, barua pepe"),
        "settings.saved_places": s("Saved places", "Lieux enregistrés", "Bisika ebombami", "Mahali yaliyohifadhiwa"),
        "settings.saved_places_detail": s("Home, work & favorites", "Maison, travail et favoris", "Ndako, mosala mpe ba favoris", "Nyumbani, kazi na vipendwa"),
        "settings.privacy_access": s("Privacy & access", "Confidentialité et accès", "Privacy mpe accès", "Faragha na ufikiaji"),
        "settings.privacy_detail": s("Data & location", "Données et localisation", "Ba données mpe localisation", "Data na eneo"),
        "settings.accessibility": s("Accessibility", "Accessibilité", "Accessibilité", "Ufikivu"),
        "settings.accessibility_detail": s("Display & interaction", "Affichage et interaction", "Affichage mpe interaction", "Onyesho na mwingiliano"),
        "settings.calendar": s("Calendar", "Calendrier", "Calendrier", "Kalenda"),
        "settings.calendar_detail": s("Trip reminders", "Rappels de trajet", "Ba rappel ya voyage", "Vikumbusho vya safari"),
        "settings.account_safety": s("Account safety", "Sécurité du compte", "Libateli ya konti", "Usalama wa akaunti"),
        "settings.safety_settings": s("Safety settings", "Réglages de sécurité", "Ba paramètre ya libateli", "Mipangilio ya usalama"),
        "settings.safety_settings_detail": s("SOS & trip tools", "SOS et outils de trajet", "SOS mpe ba outil", "SOS na zana za safari"),
        "settings.trusted_detail": s("Emergency sharing", "Partage d’urgence", "Partage ya urgence", "Kushiriki dharura"),
        "settings.market": s("Market", "Marché", "Marché", "Soko"),
        "settings.market_auto": s("Automatic", "Automatique", "Automatique", "Otomatiki"),
        "settings.market_drc": s("DRC (Lubumbashi · Kolwezi)", "RDC (Lubumbashi · Kolwezi)", "RDC (Lubumbashi · Kolwezi)", "DRC (Lubumbashi · Kolwezi)"),
        "settings.market_kenya": s("Kenya", "Kenya", "Kenya", "Kenya"),
        "settings.active_market": s("Active market", "Marché actif", "Marché oyo esalemi", "Soko amilifu"),
        "settings.market_footer": s(
            "Automatic uses your location when available, otherwise your device region. Manual override applies fares, currency, and city catalog.",
            "Automatique utilise votre position si disponible, sinon la région de l’appareil. Le choix manuel définit tarifs, devise et catalogue.",
            "Automatique esaleli localisation soki ezali, to région ya téléphone. Manuel eponi tarif, monnaie mpe catalogue.",
            "Otomatiki hutumia eneo lako ikiwa lipo, vinginevyo eneo la kifaa. Uchaguzi wa mkono huweka nauli, sarafu na orodha ya mji."
        ),
        "settings.maps": s("Maps", "Cartes", "Ba carte", "Ramani"),
        "settings.distance": s("Distance", "Distance", "Distance", "Umbali"),
        "settings.kilometers": s("Kilometers", "Kilomètres", "Ba kilomètre", "Kilomita"),
        "settings.miles": s("Miles", "Miles", "Ba mile", "Maili"),
        "settings.traffic": s("Show traffic layer", "Afficher le trafic", "Monisa traffic", "Onyesha msongamano"),
        "settings.eta_refresh": s("Refresh live ETA", "Actualiser l'ETA en direct", "Actualiser ETA ya sikoyo", "Sasisha ETA moja kwa moja"),
        "settings.currency": s("Currency display", "Affichage de la devise", "Monnaie", "Onyesho la sarafu"),
        "settings.security": s("Security", "Sécurité", "Sécurité", "Usalama"),
        "settings.security_detail": s("App lock & sessions", "Verrouillage et sessions", "Verrouillage mpe ba session", "Kufunga programu na vipindi"),
        "settings.home": s("Home", "Domicile", "Ndako", "Nyumbani"),
        "settings.work": s("Work", "Travail", "Mosala", "Kazini"),
        "settings.favorites": s("Favorites", "Favoris", "Ba favoris", "Vipendwa"),
        "settings.recent": s("Recent", "Récents", "Ya sika", "Za hivi karibuni"),
        "settings.set_location": s("Set location", "Définir le lieu", "Tia esika", "Weka eneo"),
        "settings.add_favorite": s("Add favorite", "Ajouter un favori", "Bakisa favori", "Ongeza kipendwa"),
        "settings.no_favorites": s("No favorites yet", "Aucun favori", "Favori te", "Hakuna vipendwa bado"),
        "settings.shortcuts": s("Shortcuts", "Raccourcis", "Ba raccourci", "Njia za mkato"),
        "settings.search_places": s("Search places", "Rechercher un lieu", "Luka esika", "Tafuta sehemu"),
        "settings.suggestions": s("Suggestions", "Suggestions", "Ba suggestion", "Mapendekezo"),
        "settings.results": s("Results", "Résultats", "Ba résultat", "Matokeo"),
        "settings.set_home": s("Set Home", "Définir Domicile", "Tia Ndako", "Weka Nyumbani"),
        "settings.set_work": s("Set Work", "Définir Travail", "Tia Mosala", "Weka Kazini"),
        "settings.clear_home": s("Clear Home", "Effacer Domicile", "Longola Ndako", "Futa Nyumbani"),
        "settings.clear_work": s("Clear Work", "Effacer Travail", "Longola Mosala", "Futa Kazini"),
        "settings.account_status": s("Account status", "Statut du compte", "Status ya konti", "Hali ya akaunti"),
        "settings.status_active": s("Active", "Actif", "Active", "Amilifu"),
        "settings.preferred_language": s("Preferred language", "Langue préférée", "Monɔkɔ oyo olingi", "Lugha unayopendelea"),
        "settings.profile_name": s("Name", "Nom", "Nkombo", "Jina"),
        "settings.profile_contact": s("Contact", "Contact", "Contact", "Mawasiliano"),
        "settings.first_name": s("First name", "Prénom", "Nkombo ya liboso", "Jina la kwanza"),
        "settings.last_name": s("Last name", "Nom", "Nkombo ya nsuka", "Jina la ukoo"),
        "settings.mobile": s("Mobile number", "Numéro mobile", "Numéro", "Nambari ya simu"),
        "settings.email": s("Email", "E-mail", "Email", "Barua pepe"),
        "settings.country_code": s("Code", "Indicatif", "Code", "Msimbo"),
        "settings.save_changes": s("Save changes", "Enregistrer", "Bomba", "Hifadhi mabadiliko"),
        "settings.profile_footer": s(
            "Your name is shown to drivers at pickup. Mobile is used for sign-in and trip alerts.",
            "Votre nom est affiché au chauffeur. Le mobile sert à la connexion et aux alertes.",
            "Nkombo na yo emonisami na chauffeur. Numéro esaleli connexion mpe ba alerte.",
            "Jina lako linaonyeshwa kwa dereva. Simu hutumika kuingia na arifa za safari."
        ),
        "settings.profile_updated": s("Profile updated", "Profil mis à jour", "Profil ekomi sika", "Wasifu umesasishwa"),
        "settings.profile_updated_msg": s(
            "Your personal details were saved on this device.",
            "Vos informations ont été enregistrées sur cet appareil.",
            "Ba info na yo ekomi na téléphone oyo.",
            "Maelezo yako yamehifadhiwa kwenye kifaa hiki."
        ),
        "settings.location_section": s("Location", "Localisation", "Esika", "Eneo"),
        "settings.precise_location": s("Precise location for pickup", "Position précise pour la prise en charge", "Esika ya solo mpo na kozwa", "Eneo sahihi kwa kuchukuliwa"),
        "settings.precise_location_note": s(
            "Approximate location may reduce ETA accuracy for drivers nearby.",
            "Une position approximative peut réduire la précision de l'ETA.",
            "Esika ya approximate ekoki kokitisa précision ya ETA.",
            "Eneo la makadirio linaweza kupunguza usahihi wa ETA."
        ),
        "settings.data_section": s("Data", "Données", "Ba donnée", "Data"),
        "settings.analytics": s("Help improve Vuum with usage data", "Aider à améliorer Vuum avec des données d'usage", "Salisa kobongisa Vuum", "Saidia kuboresha Vuum kwa data ya matumizi"),
        "settings.personalized_offers": s("Personalized offers", "Offres personnalisées", "Ba offre ya personnalisé", "Ofa binafsi"),
        "settings.activity_status": s("Show activity on shared trips", "Afficher l'activité sur les trajets partagés", "Monisa activité na ba voyage partagé", "Onyesha shughuli kwenye safari zilizoshirikiwa"),
        "settings.controls": s("Controls", "Contrôles", "Ba contrôle", "Vidhibiti"),
        "settings.download_data": s("Download my data", "Télécharger mes données", "Télécharger ba donnée", "Pakua data yangu"),
        "settings.download_data_msg": s(
            "We'll prepare a copy of your profile, trip receipts, and preference settings. You'll get a notification when it's ready.",
            "Nous préparerons une copie de votre profil, reçus et préférences. Vous recevrez une notification.",
            "Tokokabola copie ya profil, ba reçu mpe ba préférences. Okokufa notification.",
            "Tutaandaa nakala ya wasifu, risiti na mapendeleo. Utapata arifa itakapokuwa tayari."
        ),
        "settings.delete_account": s("Delete account", "Supprimer le compte", "Longola konti", "Futa akaunti"),
        "settings.delete_account_body": s(
            "Deleting your account removes your profile and signs you out on this device. Active trips should be completed or cancelled first.",
            "La suppression retire votre profil et vous déconnecte sur cet appareil. Terminez ou annulez d'abord les trajets actifs.",
            "Kolongola konti elongoli profil mpe ekobima yo. Silisa to longola ba voyage liboso.",
            "Kufuta akaunti huondoa wasifu na kukutoa kwenye kifaa hiki. Kamilisha au ghairi safari zinazoendelea kwanza."
        ),
        "settings.delete_confirm_hint": s("Type DELETE to confirm", "Tapez DELETE pour confirmer", "Kotia DELETE mpo na kondimisa", "Andika DELETE kuthibitisha"),
        "settings.delete_confirm_title": s("Delete your account?", "Supprimer votre compte ?", "Longola konti na yo?", "Futa akaunti yako?"),
        "settings.delete_confirm_msg": s(
            "This signs you out and clears your local account data.",
            "Cela vous déconnecte et efface les données locales du compte.",
            "Yango ekobima yo mpe elongoli ba donnée ya konti.",
            "Hii inakutoa na kufuta data ya akaunti kwenye kifaa."
        ),
        "settings.permissions": s("Permissions", "Autorisations", "Ba permission", "Ruhusa"),
        "settings.open_system_settings": s("Open system settings", "Ouvrir Réglages", "Fungola Settings", "Fungua mipangilio ya mfumo"),
        "settings.privacy_policy": s("Privacy policy", "Politique de confidentialité", "Politique ya privacy", "Sera ya faragha"),
        "settings.request_sent": s("Request sent", "Demande envoyée", "Demande etindami", "Ombi limetumwa"),
        "settings.submit_request": s("Submit request", "Envoyer la demande", "Tinda demande", "Wasilisha ombi"),
        "settings.device_permission": s("Device permission", "Permission appareil", "Permission ya téléphone", "Ruhusa ya kifaa"),
        "settings.push_alerts": s("Push alerts", "Alertes push", "Ba alerte push", "Arifa za push"),
        "settings.on": s("On", "Activé", "Allumé", "Washa"),
        "settings.off": s("Off", "Désactivé", "Zimi", "Zima"),
        "settings.enable_notifications": s("Enable notifications", "Activer les notifications", "Allumer ba notification", "Washa arifa"),
        "settings.open_settings": s("Open Settings", "Ouvrir Réglages", "Fungola Settings", "Fungua Mipangilio"),
        "settings.push_section": s("Push", "Push", "Push", "Push"),
        "settings.trip_updates": s("Trip status & driver updates", "Statut du trajet et mises à jour chauffeur", "Status ya voyage mpe chauffeur", "Hali ya safari na masasisho ya dereva"),
        "settings.promotions": s("Promotions & credits", "Promotions et crédits", "Ba promo mpe crédits", "Matangazo na mikopo"),
        "settings.product_news": s("Product news", "Nouveautés produits", "Ba news ya produit", "Habari za huduma"),
        "settings.quiet_hours": s("Quiet hours (22:00–07:00)", "Heures calmes (22:00–07:00)", "Ba heure ya quiet (22:00–07:00)", "Saa tulivu (22:00–07:00)"),
        "settings.scheduled_reminders": s("Scheduled ride reminders", "Rappels de courses réservées", "Ba rappel ya réservation", "Vikumbusho vya safari zilizopangwa"),
        "settings.safety_notifications": s("Safety notifications", "Notifications de sécurité", "Ba notification ya libateli", "Arifa za usalama"),
        "settings.support_updates": s("Support updates", "Mises à jour assistance", "Ba update ya support", "Masasisho ya usaidizi"),
        "settings.messages_section": s("Messages", "Messages", "Ba message", "Ujumbe"),
        "settings.sms_alerts": s("SMS for critical trip alerts", "SMS pour alertes critiques", "SMS mpo na ba alerte ya solo", "SMS kwa arifa muhimu za safari"),
        "settings.email_receipts": s("Email receipts", "Reçus par e-mail", "Ba reçu na email", "Risiti kwa barua pepe"),
        "settings.notify_footer": s(
            "Critical safety alerts are always delivered when a trip is active.",
            "Les alertes de sécurité critiques sont toujours envoyées pendant un trajet.",
            "Ba alerte ya libateli ya solo etindami ntango voyage ezali.",
            "Arifa muhimu za usalama hutumwa kila wakati safari inaendelea."
        ),
        "settings.open_inbox": s("Open inbox", "Ouvrir la boîte", "Fungola boîte", "Fungua kikasha"),
        "settings.legal": s("Legal", "Mentions légales", "Legal", "Kisheria"),
        "settings.terms": s("Terms of service", "Conditions d'utilisation", "Ba condition", "Sheria na masharti"),
        "settings.community": s("Community guidelines", "Règles de la communauté", "Ba règle ya communauté", "Mwongozo wa jamii"),
        "settings.licenses": s("Open-source licenses", "Licences open source", "Ba licence open source", "Leseni za chanzo wazi"),
        "settings.operator": s("Operator", "Opérateur", "Opérateur", "Opereta"),
        "settings.markets": s("Markets", "Marchés", "Ba marché", "Masoko"),
        "settings.version": s("Version", "Version", "Version", "Toleo"),
        "settings.build": s("Build", "Build", "Build", "Jengo"),
        "settings.app_lock": s("App lock", "Verrouillage", "Verrouillage", "Kufunga programu"),
        "settings.biometric": s("Require Face ID / Touch ID to open", "Exiger Face ID / Touch ID", "Exiger Face ID / Touch ID", "Hitaji Face ID / Touch ID kufungua"),
        "settings.active_sessions": s("Active sessions", "Sessions actives", "Ba session active", "Vipindi vinavyotumika"),
        "settings.this_device": s("This iPhone", "Cet iPhone", "iPhone oyo", "iPhone hii"),
        "settings.recent_sign_ins": s("Recent sign-ins", "Connexions récentes", "Ba connexion ya sika", "Uingiaji wa hivi karibuni"),
        "settings.sign_out_others": s("Sign out other devices", "Déconnecter les autres appareils", "Kobima na ba appareil mosusu", "Toka kwenye vifaa vingine"),
        "settings.location_permission": s("Location", "Localisation", "Localisation", "Eneo"),
        "settings.mic_permission": s("Microphone", "Microphone", "Microphone", "Maikrofoni"),
        "settings.notification_permission": s("Notifications", "Notifications", "Ba notification", "Arifa"),
        "settings.enable_location": s("Enable location", "Activer la localisation", "Allumer localisation", "Washa eneo"),
        "settings.sign_out_others_done": s(
            "Other devices will need to sign in again next time they open Vuum.",
            "Les autres appareils devront se reconnecter à la prochaine ouverture de Vuum.",
            "Ba appareil mosusu ekolinga connexion sika.",
            "Vifaa vingine vitahitaji kuingia tena wakati vinapofungua Vuum."
        ),
        "settings.clear_recent": s("Clear recent", "Effacer les récents", "Longola ya sika", "Futa za hivi karibuni"),
        "settings.no_matching_places": s("No matching places", "Aucun lieu correspondant", "Esika eza te", "Hakuna sehemu zinazolingana"),
        "settings.receipt_alerts": s("Receipt emails & push", "Reçus (e-mail et push)", "Ba reçu", "Risiti (barua pepe na push)"),

        // Activity
        "activity.title": s("Activity", "Activité", "Misala", "Shughuli"),
        "activity.empty_title": s("No recent trips", "Aucun trajet récent", "Voyage ya sika te", "Hakuna safari za hivi karibuni"),
        "activity.empty_detail": s(
            "Completed rides will appear here with fare details.",
            "Les courses terminées apparaîtront ici avec le détail du tarif.",
            "Ba voyage oyo esili ekosala awa na tarif.",
            "Safari zilizokamilika zitaonekana hapa na maelezo ya nauli."
        ),

        // Trip
        "trip.searching": s("Finding your ride", "Recherche d'un chauffeur", "Toluka chauffeur", "Inatafuta dereva"),
        "trip.searching_detail": s(
            "Matching you with a nearby driver",
            "Nous trouvons un chauffeur à proximité",
            "Toluka chauffeur oyo azali pene",
            "Inakutanisha na dereva karibu"
        ),
        "trip.driver_en_route": s("%@ is on the way", "%@ est en route", "%@ azali na nzela", "%@ yuko njiani"),
        "trip.heading_to_pickup": s(
            "Heading to your pickup",
            "En route vers votre prise en charge",
            "Azali koya na esika ya kozwa yo",
            "Anakuja mahali pa kuchukuliwa"
        ),
        "trip.driver_arrived": s("Your driver is here", "Votre chauffeur est arrivé", "Chauffeur na yo akomi", "Dereva wako amefika"),
        "trip.meet_at_pickup": s(
            "Meet %@ at pickup · enter trip PIN to board",
            "Rejoignez %@ · saisissez le PIN pour monter",
            "Kutanana na %@ · kotia PIN ya voyage",
            "Kutana na %@ · weka PIN ya safari"
        ),
        "trip.heading_to_destination": s(
            "Heading to destination",
            "En route vers la destination",
            "Tokeyi na destination",
            "Tunaelekea unakoenda"
        ),
        "trip.on_the_way": s("On the way to %@", "En route vers %@", "Tokeyi na %@", "Tunakwenda %@"),
        "trip.arrived": s("You've arrived", "Vous êtes arrivé", "Okomi", "Umefika"),
        "trip.choose_ride": s("Choose a ride", "Choisissez une course", "Pona voyage", "Chagua safari"),
        "trip.confirm_ride": s("Confirm ride", "Confirmer la course", "Ndimisa voyage", "Thibitisha safari"),
        "trip.cancel": s("Cancel", "Annuler", "Longola", "Ghairi"),
        "trip.ride_now": s("Ride now", "Partir maintenant", "Kende sika", "Safari sasa"),
        "trip.nearby_cars": s("Nearby cars are shown on the map", "Les voitures proches sont sur la carte", "Ba voiture pene emonisami na carte", "Magari karibu yanaonyeshwa kwenye ramani"),
        "trip.cancel_request": s("Cancel request", "Annuler la demande", "Longola demande", "Ghairi ombi"),
        "trip.cancel_request_title": s("Cancel request?", "Annuler la demande ?", "Longola demande ?", "Ghairi ombi?"),
        "trip.cancel_trip": s("Cancel trip", "Annuler le trajet", "Longola voyage", "Ghairi safari"),
        "trip.cancel_trip_title": s("Cancel trip?", "Annuler le trajet ?", "Longola voyage ?", "Ghairi safari?"),
        "trip.adjust_pickup": s("Adjust pickup", "Ajuster le point de prise en charge", "Bobongola esika ya kozwa", "Rekebisha mahali pa kuchukuliwa"),
        "trip.change_destination": s("Change destination", "Changer de destination", "Bobongola destination", "Badilisha unakoenda"),
        "trip.add_stop": s("Add a stop", "Ajouter un arrêt", "Bakisa arrêt", "Ongeza kituo"),
        "trip.for_me": s("For me", "Pour moi", "Mpo na ngai", "Kwa mimi"),
        "trip.for_others": s("For others", "Pour quelqu’un d’autre", "Mpo na mosusu", "Kwa wengine"),
        "trip.promo_code": s("Promo code", "Code promo", "Code ya promo", "Msimbo wa promo"),
        "trip.promo_applied": s("Promo applied · %@", "Promo appliquée · %@", "Promo esalemi · %@", "Promo imetumika · %@"),
        "trip.passenger_name": s("Passenger name", "Nom du passager", "Kombo ya passager", "Jina la abiria"),
        "trip.passenger_phone": s("Passenger phone", "Téléphone du passager", "Téléphone ya passager", "Simu ya abiria"),
        "trip.trip_pin": s("Trip PIN", "PIN du trajet", "PIN ya voyage", "PIN ya safari"),
        "trip.enter_pin": s("Enter PIN", "Saisir le PIN", "Kotia PIN", "Weka PIN"),
        "trip.pin_hint": s(
            "Enter the PIN after you share it with your driver",
            "Saisissez le PIN après l’avoir partagé avec le chauffeur",
            "Kotia PIN nsima ya kopesa yango na chauffeur",
            "Weka PIN baada ya kuishiriki na dereva"
        ),
        "trip.pin_mismatch": s(
            "PIN doesn’t match — check with your driver",
            "Le PIN ne correspond pas — vérifiez avec le chauffeur",
            "PIN eza te — talela na chauffeur",
            "PIN hailingani — angalia na dereva"
        ),
        "trip.confirm_boarding": s("Confirm boarding", "Confirmer l’embarquement", "Ndimisa kobima", "Thibitisha kupanda"),
        "trip.confirm_tier": s("Confirm %@", "Confirmer %@", "Ndimisa %@", "Thibitisha %@"),
        "trip.reserve_tier": s("Reserve %@", "Réserver %@", "Boka %@", "Hifadhi %@"),
        "trip.ride_fallback": s("ride", "course", "voyage", "safari"),

        // Destination
        "destination.choose": s("Choose destination", "Choisir une destination", "Pona destination", "Chagua unakoenda"),
        "destination.add_stop": s("Add a stop", "Ajouter un arrêt", "Bakisa arrêt", "Ongeza kituo"),
        "destination.search_places": s("Search places", "Rechercher un lieu", "Luka bisika", "Tafuta mahali"),
        "destination.search_stop": s("Search for a stop", "Rechercher un arrêt", "Luka arrêt", "Tafuta kituo"),
        "destination.favorites": s("Favorites", "Favoris", "Ba favoris", "Vipendwa"),
        "destination.recent": s("Recent", "Récents", "Ya sika", "Za hivi karibuni"),
        "destination.results": s("Results", "Résultats", "Ba résultat", "Matokeo"),
        "destination.suggestions": s("Suggestions", "Suggestions", "Ba suggestion", "Mapendekezo"),
        "destination.stops": s("Stops", "Arrêts", "Ba arrêt", "Vituo"),
        "destination.saved_places": s("Saved places", "Lieux enregistrés", "Bisika ebombami", "Mahali yaliyohifadhiwa"),
        "destination.add_home": s("Add Home", "Ajouter Maison", "Bakisa Ndako", "Ongeza Nyumbani"),
        "destination.add_work": s("Add Work", "Ajouter Travail", "Bakisa Mosala", "Ongeza Kazini"),
        "destination.home_subtitle": s(
            "Save an address for quick trips home",
            "Enregistrer une adresse pour rentrer vite",
            "Bomba adresse mpo na kozonga ndako noki",
            "Hifadhi anwani kwa safari za haraka nyumbani"
        ),
        "destination.work_subtitle": s("Save your workplace", "Enregistrer votre lieu de travail", "Bomba esika ya mosala", "Hifadhi mahali pa kazi"),
        "destination.set_home": s("Set Home", "Définir Maison", "Tya Ndako", "Weka Nyumbani"),
        "destination.set_work": s("Set Work", "Définir Travail", "Tya Mosala", "Weka Kazini"),
        "destination.stop_progress": s("Stop %d of %d", "Arrêt %d sur %d", "Arrêt %d ya %d", "Kituo %d kati ya %d"),
        "destination.favorites_hint": s(
            "Star places from the destination list to save them here.",
            "Ajoutez des lieux en favoris depuis la liste pour les retrouver ici.",
            "Tya étoile na bisika mpo na kobomba yango awa.",
            "Weka nyota kwenye mahali kutoka orodha ili kuyahifadhi hapa."
        ),
        "destination.no_matching_places": s(
            "No matching places",
            "Aucun lieu correspondant",
            "Esika eza te",
            "Hakuna sehemu zinazolingana"
        ),
        "destination.searching_places": s(
            "Searching…",
            "Recherche…",
            "Koluka…",
            "Inatafuta…"
        ),
        "destination.could_not_open_place": s(
            "Couldn't open that place. Try another.",
            "Impossible d'ouvrir ce lieu. Essayez-en un autre.",
            "Ekoki te kofungola esika wana. Meka mosusu.",
            "Haikuweza kufungua mahali hapo. Jaribu lingine."
        ),
        "maps.error.unavailable": s(
            "Maps isn't available right now.",
            "La carte n'est pas disponible pour le moment.",
            "Carte ezali te sikoyo.",
            "Ramani haipatikani sasa."
        ),
        "maps.error.busy": s(
            "Too many requests. Try again in a moment.",
            "Trop de demandes. Réessayez dans un instant.",
            "Ba demandes ebele. Meka lisusu noki.",
            "Maombi mengi. Jaribu tena baadaye kidogo."
        ),
        "maps.error.temporary": s(
            "Temporary connection issue. Try again.",
            "Problème de connexion temporaire. Réessayez.",
            "Problème ya connexion ya mwa tango. Meka lisusu.",
            "Tatizo la muda la muunganisho. Jaribu tena."
        ),
        "maps.error.generic": s(
            "Something went wrong. Try again.",
            "Une erreur s'est produite. Réessayez.",
            "Erreur esalemi. Meka lisusu.",
            "Hitilafu imetokea. Jaribu tena."
        ),
        "maps.error.network": s(
            "Check your connection and try again.",
            "Vérifiez votre connexion et réessayez.",
            "Tala connexion na yo mpe meka lisusu.",
            "Angalia muunganisho wako kisha ujaribu tena."
        ),
        "maps.error.no_route": s(
            "Unable to calculate the route right now.",
            "Impossible de calculer l'itinéraire pour le moment.",
            "Ekoki te kobongisa nzela sikoyo.",
            "Haiwezi kukokotoa njia sasa."
        ),
        "destination.search_new": s(
            "Search new destination",
            "Rechercher une nouvelle destination",
            "Luka destination ya sika",
            "Tafuta unakoenda mpya"
        ),

        // Permissions
        "permissions.title": s("Enable access", "Activer l’accès", "Fungola accès", "Wezesha ufikiaji"),
        "permissions.intro": s(
            "To get you a ride safely and quickly, Vuum needs a few permissions on your phone.",
            "Pour vous déplacer en toute sécurité, Vuum a besoin de quelques autorisations.",
            "Mpo na kozwa voyage na malamu, Vuum esengeli ba permission moko na téléphone.",
            "Ili kukupatia safari salama na haraka, Vuum inahitaji ruhusa chache kwenye simu yako."
        ),
        "permissions.location": s("Location", "Localisation", "Localisation", "Eneo"),
        "permissions.location_detail": s(
            "Vuum uses your location to find your pickup point and show nearby drivers.",
            "Vuum utilise votre localisation pour trouver votre point de prise en charge et afficher les chauffeurs à proximité.",
            "Vuum esaleli localisation na yo mpo na koluka esika ya kozwa yo mpe monisa ba chauffeur pene.",
            "Vuum hutumia eneo lako kupata mahali pa kuchukuliwa na kuonyesha madereva karibu."
        ),
        "permissions.notifications": s("Notifications", "Notifications", "Ba notification", "Arifa"),
        "permissions.notifications_detail": s(
            "Get driver arrival, trip and safety updates.",
            "Recevez les arrivées chauffeur, trajets et alertes de sécurité.",
            "Zwa ba arrivée ya chauffeur, ba voyage mpe ba alerte ya libateli.",
            "Pata arifa za kuwasili kwa dereva, safari, na usalama."
        ),
        "permissions.microphone": s("Microphone (later)", "Microphone (plus tard)", "Microphone (na nsima)", "Maikrofoni (baadaye)"),
        "permissions.microphone_detail": s(
            "Safety recording is available only during an active trip — we’ll ask if you turn it on.",
            "L’enregistrement de sécurité n’est disponible que pendant un trajet actif — nous demanderons si vous l’activez.",
            "Enregistrement ya libateli ezali kaka na voyage active — tokotuna soki ofungoli yango.",
            "Rekodi ya usalama inapatikana tu wakati wa safari amilifu — tutauliza ukiiwasha."
        ),
        "permissions.camera": s("Camera", "Caméra", "Caméra", "Kamera"),
        "permissions.camera_detail": s(
            "Profile photos and optional safety features.",
            "Photos de profil et fonctions de sécurité optionnelles.",
            "Ba photo ya profil mpe ba fonction ya libateli.",
            "Picha za wasifu na vipengele vya usalama hiari."
        ),
        "permissions.motion": s("Motion", "Mouvement", "Motion", "Mwendo"),
        "permissions.motion_detail": s(
            "Helps refine pickup accuracy while you are on the move.",
            "Améliore la précision du point de prise en charge en déplacement.",
            "Esalisa accuracy ya esika ya kozwa soki otamboli.",
            "Inasaidia usahihi wa kuchukuliwa unaposonga."
        ),
        "permissions.change_anytime": s(
            "You can change these anytime in Settings.",
            "Vous pouvez modifier cela à tout moment dans Réglages.",
            "Okoki kobongola yango ntango nyonso na Paramètres.",
            "Unaweza kubadilisha hivi wakati wowote katika Mipangilio."
        ),

        // Safety
        "safety.title": s("Safety", "Sécurité", "Libateli", "Usalama"),
        "safety.sos": s("SOS · Get emergency help", "SOS · Aide d’urgence", "SOS · Aide ya urgence", "SOS · Pata msaada wa dharura"),
        "safety.help_requested": s("Help already requested", "Aide déjà demandée", "Aide esengi deja", "Msaada umeombwa tayari"),
        "safety.request_help": s("Request emergency help", "Demander une aide d’urgence", "Senga aide ya urgence", "Omba msaada wa dharura"),
        "safety.request_help_confirm": s("Request emergency help?", "Demander une aide d’urgence ?", "Senga aide ya urgence ?", "Omba msaada wa dharura?"),
        "safety.request_help_now": s("Request help now", "Demander de l’aide maintenant", "Senga aide sika", "Omba msaada sasa"),
        "safety.request_help_body": s(
            "Vuum Safety will be notified with your trip details and will try to reach you immediately.",
            "Vuum Safety sera informé avec les détails du trajet et tentera de vous joindre immédiatement.",
            "Vuum Safety ekosepela na ba détails ya voyage mpe ekoluka yo noki.",
            "Vuum Safety itaarifiwa na maelezo ya safari yako na itajaribu kukufikia mara moja."
        ),
        "safety.emergency_requested": s("Emergency help requested", "Aide d’urgence demandée", "Aide ya urgence esengi", "Msaada wa dharura umeombwa"),
        "safety.emergency_detail": s(
            "Vuum Safety is contacting you. Stay on the line if they call.",
            "Vuum Safety vous contacte. Restez en ligne s’ils appellent.",
            "Vuum Safety ezali kokutana na yo. Bika na ligne soki babengi.",
            "Vuum Safety inawasiliana nawe. Kaa kwenye simu wakitapiga."
        ),
        "safety.share_trip": s("Share live trip link", "Partager le lien du trajet", "Partager lien ya voyage", "Shiriki kiungo cha safari"),
        "safety.share_subject": s("My Vuum trip", "Mon trajet Vuum", "Voyage na ngai na Vuum", "Safari yangu ya Vuum"),
        "safety.share_message": s("Follow my live trip on Vuum", "Suivez mon trajet en direct sur Vuum", "Talela voyage na ngai na Vuum", "Fuatilia safari yangu moja kwa moja kwenye Vuum"),
        "safety.recording_notice": s(
            "Recording trip audio · your driver is notified",
            "Enregistrement audio · le chauffeur est informé",
            "Enregistrement audio · chauffeur azali koyeba",
            "Inarekodi sauti · dereva aarifiwa"
        ),
        "safety.record_audio": s("Record audio", "Enregistrer l’audio", "Enregistrer audio", "Rekodi sauti"),
        "safety.stop_recording": s("Stop recording", "Arrêter l’enregistrement", "Teika enregistrement", "Acha kurekodi"),
        "safety.audio_footer": s(
            "Audio is recorded on this device only. Your driver is notified while recording is on. Deleted after the trip unless you report an incident.",
            "L’audio est enregistré uniquement sur cet appareil. Le chauffeur est informé pendant l’enregistrement. Supprimé après le trajet sauf incident signalé.",
            "Audio ebombami kaka na téléphone oyo. Chauffeur azali koyeba. Elongolami nsima ya voyage soki otalisi incident te.",
            "Sauti inarekodiwa kwenye kifaa hiki pekee. Dereva aarifiwa wakati wa kurekodi. Inafutwa baada ya safari isipokuwa uripoti tukio."
        ),

        // Legal
        "legal.about": s("About", "À propos", "Mpo na", "Kuhusu"),
        "legal.app": s("App", "Application", "App", "Programu"),
        "legal.version": s("Version", "Version", "Version", "Toleo"),
        "legal.build": s("Build", "Build", "Build", "Build"),
        "legal.section": s("Legal", "Mentions légales", "Legal", "Kisheria"),
        "legal.terms": s("Terms of service", "Conditions d’utilisation", "Ba Conditions", "Masharti ya huduma"),
        "legal.privacy": s("Privacy policy", "Politique de confidentialité", "Politique ya privacy", "Sera ya faragha"),
        "legal.guidelines": s("Community guidelines", "Règles de la communauté", "Ba règles ya communauté", "Mwongozo wa jamii"),
        "legal.licenses": s("Open-source licenses", "Licences open source", "Ba licence open source", "Leseni za chanzo wazi"),
        "legal.operator_section": s("Operator", "Opérateur", "Opérateur", "Opereta"),
        "legal.operator_name": s("Operator", "Opérateur", "Opérateur", "Opereta"),
        "legal.markets": s("Markets", "Marchés", "Ba marché", "Masoko"),
        "legal.markets_value": s("DRC · Kenya", "RDC · Kenya", "RDC · Kenya", "DRC · Kenya"),
        "legal.diagnostics": s("Diagnostics", "Diagnostics", "Diagnostics", "Utambuzi"),
        "legal.diagnostics_unlocked": s("Diagnostics unlocked", "Diagnostics débloqués", "Diagnostics efungwami", "Utambuzi umefunguliwa"),
        "legal.diagnostics_unlocked_msg": s(
            "Internal tools are available from this screen.",
            "Les outils internes sont disponibles depuis cet écran.",
            "Ba outil ya interne ezali awa.",
            "Zana za ndani zinapatikana kwenye skrini hii."
        ),

        // Map surface (unavailable / no live tiles)
        "map.unavailable_title": s(
            "Map unavailable",
            "Carte indisponible",
            "Carte eza te",
            "Ramani haipatikani"
        ),
        "map.unavailable_detail": s(
            "You can still search and book. The map will appear when it’s available.",
            "Vous pouvez toujours chercher et réserver. La carte s’affichera dès qu’elle sera disponible.",
            "Okoki kaka ko chercher mpe ko book. Carte ekomonisa soki ezali.",
            "Bado unaweza kutafuta na kuagiza. Ramani itaonekana itakapopatikana."
        ),
        "map.a11y_home": s(
            "Map showing your current area",
            "Carte de votre zone actuelle",
            "Carte ya zone na yo",
            "Ramani inayoonyesha eneo lako la sasa"
        ),
        "map.a11y_preview": s(
            "Map showing pickup and destination",
            "Carte du départ et de la destination",
            "Carte ya départ mpe destination",
            "Ramani ya kuchukuliwa na unakoenda"
        ),
        "map.a11y_matching": s(
            "Map showing nearby vehicles while matching a driver",
            "Carte des véhicules proches pendant la recherche d’un chauffeur",
            "Carte ya ba véhicules pene tango koluka chauffeur",
            "Ramani ya magari karibu wakati wa kutafuta dereva"
        ),
        "map.a11y_approach": s(
            "Map showing your driver approaching pickup",
            "Carte du chauffeur qui approche du point de prise en charge",
            "Carte ya chauffeur azali koyaka na pickup",
            "Ramani ya dereva anayekaribia mahali pa kuchukuliwa"
        ),
        "map.a11y_active": s(
            "Map showing your active trip route",
            "Carte de l’itinéraire de votre course",
            "Carte ya route ya voyage na yo",
            "Ramani ya njia ya safari yako"
        ),
        "map.a11y_completed": s(
            "Map showing completed trip",
            "Carte du trajet terminé",
            "Carte ya voyage oyo esili",
            "Ramani ya safari iliyokamilika"
        ),

        // Maps / Places / Route rider errors (GoogleAPIError + route UX — no demo / key copy)
        "maps.error_unavailable": s(
            "Maps aren’t available right now.",
            "La carte n’est pas disponible pour le moment.",
            "Carte eza te sika oyo.",
            "Ramani haipatikani kwa sasa."
        ),
        "maps.error_busy": s(
            "We’re busy right now. Try again in a moment.",
            "Nous sommes saturés. Réessayez dans un instant.",
            "Ezali na ba demandes mingi. Meka lisusu noki.",
            "Tuko na shughuli nyingi. Jaribu tena baadaye kidogo."
        ),
        "maps.error_timeout": s(
            "That took too long. Try again.",
            "Cela a pris trop de temps. Réessayez.",
            "Etikala mingi. Meka lisusu.",
            "Imechukua muda mrefu. Jaribu tena."
        ),
        "maps.error_offline": s(
            "Check your connection and try again.",
            "Vérifiez votre connexion et réessayez.",
            "Tala connexion na yo mpe meka lisusu.",
            "Angalia muunganisho wako kisha jaribu tena."
        ),
        "maps.error_generic": s(
            "We couldn’t complete that. Try again.",
            "Impossible de terminer. Réessayez.",
            "Tokoki kosilisa. Meka lisusu.",
            "Hatukuweza kukamilisha. Jaribu tena."
        ),
        "maps.error_no_route": s(
            "Unable to calculate the route right now.",
            "Impossible de calculer l’itinéraire pour le moment.",
            "Tokoki ko calculer route sika oyo.",
            "Haiwezekani kukokotoa njia kwa sasa."
        ),
        "places.error_unavailable": s(
            "Place search isn’t available right now.",
            "La recherche de lieux n’est pas disponible pour le moment.",
            "Boluki ya ba lieux eza te sika oyo.",
            "Utafutaji wa mahali haupatikani kwa sasa."
        ),
        "places.error_offline": s(
            "Couldn’t search places. Check your connection.",
            "Impossible de rechercher des lieux. Vérifiez votre connexion.",
            "Tokoki ko chercher ba lieux. Tala connexion.",
            "Hatukuweza kutafuta mahali. Angalia muunganisho."
        ),
        "places.error_generic": s(
            "Couldn’t find that place. Try another search.",
            "Lieu introuvable. Essayez une autre recherche.",
            "Tokoki kokuta esika wana. Meka boluki mosusu.",
            "Mahali hapakupatikana. Jaribu utafutaji mwingine."
        ),
        "places.error_no_results": s(
            "No places match your search.",
            "Aucun lieu ne correspond à votre recherche.",
            "Esika eza te oyo elandi boluki na yo.",
            "Hakuna mahali yanayolingana na utafutaji wako."
        ),
        "route.error_unable": s(
            "Unable to calculate the route right now.",
            "Impossible de calculer l’itinéraire pour le moment.",
            "Tokoki ko calculer route sika oyo.",
            "Haiwezekani kukokotoa njia kwa sasa."
        ),
        "route.deviation_title": s(
            "Route update",
            "Mise à jour d’itinéraire",
            "Mise à jour ya route",
            "Sasisho la njia"
        ),
        "route.deviation_notice": s(
            "Your driver appears to be off the planned route. You can share your live trip with a trusted contact.",
            "Votre chauffeur semble s’éloigner de l’itinéraire prévu. Vous pouvez partager votre course en direct avec un contact de confiance.",
            "Chauffeur na yo azali kobima na route oyo eza planned. Okoki ko partager voyage na contact ya confiance.",
            "Dereva wako anaonekana ametoka kwenye njia iliyopangwa. Unaweza kushiriki safari yako moja kwa moja na anwani unayeimaini."
        ),
        "route.deviation_body": s(
            "Your trip is taking a different path than planned. Share your live location if you want someone to follow along.",
            "Votre course emprunte un autre chemin que prévu. Partagez votre position en direct si vous souhaitez être suivi.",
            "Voyage na yo ezali na nzela mosusu. Partager localisation na yo soki olingi moto alanda yo.",
            "Safari yako inachukua njia tofauti na iliyopangwa. Shiriki eneo lako moja kwa moja ikiwa unataka mtu afuatilie."
        ),

        // Empty / error / offline (Agent 34)
        "status.connecting": s("Connecting…", "Connexion…", "Ezali kokoma…", "Inaunganisha…"),
        "status.retrying": s("Trying again…", "Nouvelle tentative…", "Toluka lisusu…", "Inajaribu tena…"),
        "status.retry": s("Retry", "Réessayer", "Meka lisusu", "Jaribu tena"),
        "status.try_again": s("Try again", "Réessayer", "Meka lisusu", "Jaribu tena"),
        "status.offline_title": s("You're offline", "Vous êtes hors ligne", "Ozali offline", "Haujaunganishwa"),
        "status.offline_detail": s(
            "Check your connection. Saved trips and payments stay available on this device.",
            "Vérifiez votre connexion. Voyages et paiements enregistrés restent disponibles sur cet appareil.",
            "Tala connexion. Ba voyages mpe paiements eza na téléphone.",
            "Angalia muunganisho. Safari na malipo yaliyohifadhiwa yanapatikana kwenye kifaa hiki."
        ),
        "status.weak_network_title": s("Slow connection", "Connexion lente", "Connexion eza malembe", "Muunganisho wa polepole"),
        "status.weak_network_detail": s(
            "Some updates may take longer. You can keep booking.",
            "Certaines mises à jour peuvent être plus lentes. Vous pouvez continuer à réserver.",
            "Ba mises à jour ekokoka malembe. Okoki kokoba ko réserver.",
            "Sasisho zingine zinaweza kuchukua muda. Bado unaweza kuagiza."
        ),
        "status.error_title": s("Something went wrong", "Une erreur s'est produite", "Erreur esalemi", "Hitilafu imetokea"),
        "status.error_detail": s(
            "We couldn't load this right now. Try again in a moment.",
            "Impossible de charger pour le moment. Réessayez dans un instant.",
            "Tokoki ko charger sika oyo. Meka lisusu noki.",
            "Hatukuweza kupakia sasa. Jaribu tena baadaye kidogo."
        ),
        "status.empty_trips_action": s("Book a ride", "Réserver une course", "Book voyage", "Agiza safari"),
        "status.empty_upcoming_title": s("No upcoming rides", "Aucune course à venir", "Voyage ya liboso te", "Hakuna safari zijazo"),
        "status.empty_upcoming_detail": s(
            "Reserved pickups will show here. Schedule a ride from Services.",
            "Les courses réservées apparaîtront ici. Planifiez depuis Services.",
            "Ba voyages oyo eza reserved ekosala awa. Schedule na Services.",
            "Mahudhurio yaliyohifadhiwa yataonekana hapa. Panga kutoka Huduma."
        ),
        "status.empty_notifications_title": s("No notifications", "Aucune notification", "Notification te", "Hakuna arifa"),
        "status.empty_notifications_detail": s(
            "Trip updates and offers will show up here.",
            "Les mises à jour de course et les offres apparaîtront ici.",
            "Ba mises à jour ya voyage mpe ba offres ekosala awa.",
            "Sasisho za safari na ofa zitaonekana hapa."
        ),
        "status.empty_places_title": s("No favorites yet", "Aucun favori", "Favori te", "Hakuna vipendwa bado"),
        "status.empty_places_detail": s(
            "Save places you visit often for faster booking.",
            "Enregistrez les lieux que vous fréquentez pour réserver plus vite.",
            "Bomba ba lieux oyo okendaka mingi po booking eza noki.",
            "Hifadhi mahali unayotembelea mara nyingi kwa kuagiza haraka."
        ),
        "status.empty_contacts_title": s("No trusted contacts yet", "Aucun contact de confiance", "Contact ya confiance te", "Hakuna anwani za kuaminika bado"),
        "status.empty_contacts_detail": s(
            "Add someone who can follow your trip when you share your ride.",
            "Ajoutez quelqu'un qui peut suivre votre course lorsque vous la partagez.",
            "Bakisa moto oyo akoki kolanda voyage na yo tango o partager.",
            "Ongeza mtu anayeweza kufuatilia safari yako unaposhiriki."
        ),
        "status.empty_support_title": s("No support messages yet", "Aucun message d'assistance", "Message ya support te", "Hakuna ujumbe wa usaidizi bado"),
        "status.empty_support_detail": s(
            "When you contact help, your messages appear here.",
            "Lorsque vous contactez l'aide, vos messages apparaissent ici.",
            "Tango o contactera aide, ba messages na yo ekosala awa.",
            "Unapowasiliana na usaidizi, ujumbe wako unaonekana hapa."
        ),
        "status.empty_referrals_title": s("No invites yet", "Aucune invitation", "Invitation te", "Hakuna mialiko bado"),
        "status.empty_referrals_detail": s(
            "Share your code so friends can ride and you both earn a reward.",
            "Partagez votre code pour que vos amis voyagent et que vous gagniez tous les deux.",
            "Partager code na yo po ba amis bakenda voyage mpe bobongisa.",
            "Shiriki msimbo wako ili marafiki wasafiri na nyote mpate zawadi."
        ),
        "status.empty_corporate_title": s("No company trips yet", "Aucun trajet d'entreprise", "Voyage ya société te", "Hakuna safari za kampuni bado"),
        "status.empty_corporate_detail": s(
            "Work rides billed to your company will appear here.",
            "Les courses professionnelles facturées à votre entreprise apparaîtront ici.",
            "Ba voyages ya mosala oyo eza na société ekosala awa.",
            "Safari za kazi zinazotozwa kampuni yako zitaonekana hapa."
        ),
        "status.empty_payments_title": s("Add a payment method", "Ajoutez un moyen de paiement", "Bakisa moyen ya paiement", "Ongeza njia ya malipo"),
        "status.empty_payments_detail": s(
            "Link Mobile Money or a card so checkout is ready when your trip ends.",
            "Liez Mobile Money ou une carte pour payer facilement en fin de course.",
            "Linker Mobile Money to carte po paiement eza prêt na nsuka ya voyage.",
            "Unganisha Mobile Money au kadi ili malipo yawe tayari safari ikimalizika."
        ),
        "status.linking_payment": s(
            "Connecting to your wallet…",
            "Connexion à votre portefeuille…",
            "Ezali kokoma na portefeuille…",
            "Inaunganisha na pochi yako…"
        ),
    ]
}
