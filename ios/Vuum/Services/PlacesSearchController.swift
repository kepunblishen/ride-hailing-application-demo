import Foundation
import UIKit

/// Shared destination-search plumbing: session tokens, debounce, cancellation, resolve errors.
/// Product copy never mentions catalog/fallback/credentials — riders only see search results or short errors.
@MainActor
final class PlacesSearchController: ObservableObject {
    @Published private(set) var suggestions: [PlacesSearchService.PlaceSuggestion] = []
    /// True while a debounced autocomplete is outstanding.
    @Published private(set) var isQueryPending = false
    @Published private(set) var isResolving = false
    /// Short rider-facing message (resolve failure, etc.). Never explains internals.
    @Published var statusMessage: String?
    /// True when the last remote failure can be retried (transient).
    @Published private(set) var canRetry = false

    private var searchTask: Task<Void, Never>?
    /// Monotonic generation — older autocomplete completions must not overwrite newer ones.
    private var queryGeneration = 0
    private var lastSubmittedQuery = ""
    private var lastBias: GeoPoint?
    private var lastMarket: AppLocale.Market = .drc
    private var lastPlaceFilter: ((Place) -> Bool) = { _ in true }
    private var backgroundObserver: NSObjectProtocol?

    init() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.cancelInFlightQueryPreservingSession()
            }
        }
    }

    deinit {
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
    }

    func beginSession() {
        PlacesSearchService.beginSession()
    }

    func abandonSession() {
        searchTask?.cancel()
        invalidateInFlightSearch()
        PlacesSearchService.abandonSession()
        resetResults()
        canRetry = false
    }

    /// Call from search `onDisappear` — cancels in-flight work and drops the session token.
    func tearDown() {
        abandonSession()
        statusMessage = nil
        canRetry = false
    }

    func resetResults() {
        searchTask?.cancel()
        invalidateInFlightSearch()
        suggestions = []
        isQueryPending = false
        lastSubmittedQuery = ""
    }

    /// Background: cancel Places HTTP; keep session token + suggestions so resume does not re-query.
    func cancelInFlightQueryPreservingSession() {
        searchTask?.cancel()
        searchTask = nil
        isQueryPending = false
        queryGeneration += 1
    }

    /// Debounced autocomplete (~300 ms). Cancels prior work; ignores stale completions.
    func scheduleSearch(
        _ raw: String,
        bias: GeoPoint?,
        market: AppLocale.Market,
        isPlaceAvailable: @escaping (Place) -> Bool = { _ in true }
    ) {
        searchTask?.cancel()
        statusMessage = nil
        canRetry = false

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        lastSubmittedQuery = trimmed
        lastBias = bias
        lastMarket = market
        lastPlaceFilter = isPlaceAvailable
        guard !trimmed.isEmpty else {
            invalidateInFlightSearch()
            suggestions = []
            isQueryPending = false
            return
        }

        isQueryPending = true
        queryGeneration += 1
        let generation = queryGeneration
        let submittedQuery = trimmed

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(PlacesSearchService.recommendedDebounceMilliseconds))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            guard generation == self.queryGeneration,
                  submittedQuery == self.lastSubmittedQuery
            else { return }

            let outcome = await PlacesSearchService.autocompleteOutcome(
                query: submittedQuery,
                bias: bias,
                market: market
            )
            // Stale-response ignore: a newer keystroke or clear must win even if this HTTP finishes later.
            guard !Task.isCancelled else { return }
            guard generation == self.queryGeneration,
                  submittedQuery == self.lastSubmittedQuery
            else { return }

            let filtered = outcome.suggestions.filter { suggestion in
                if let place = suggestion.place {
                    return isPlaceAvailable(place)
                }
                return true
            }
            self.suggestions = filtered
            self.isQueryPending = false

            if outcome.source == .localAfterRemoteFailure, let error = outcome.remoteError {
                self.statusMessage = error.riderMessage
                self.canRetry = error.isRetryable
            }
        }
    }

    /// Re-runs the last query after a transient Places failure.
    func retryLastSearch() {
        guard canRetry, !lastSubmittedQuery.isEmpty else { return }
        scheduleSearch(
            lastSubmittedQuery,
            bias: lastBias,
            market: lastMarket,
            isPlaceAvailable: lastPlaceFilter
        )
    }

    /// Resolves a remote or local suggestion. On failure sets `statusMessage` (product-safe).
    func resolve(_ suggestion: PlacesSearchService.PlaceSuggestion) async -> Place? {
        isResolving = true
        statusMessage = nil
        canRetry = false
        defer { isResolving = false }

        let place = await PlacesSearchService.resolve(suggestion)
        if place == nil {
            if let mapped = GoogleMapsDiagnostics.shared.lastRiderMessage {
                statusMessage = mapped
            } else {
                statusMessage = L10n.Places.errorGeneric
            }
            canRetry = false
        }
        return place
    }

    /// After a successful selection, start a fresh billing session for the next query.
    func beginSessionAfterSelection() {
        PlacesSearchService.beginSession()
        resetResults()
    }

    /// Bumps generation so any in-flight autocomplete completion is discarded.
    private func invalidateInFlightSearch() {
        queryGeneration += 1
        searchTask = nil
    }
}
