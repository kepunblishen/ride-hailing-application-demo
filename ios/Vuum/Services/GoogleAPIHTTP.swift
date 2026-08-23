import Foundation

/// Bounded HTTPS helper for Places / Routes / Directions — exponential backoff, no key in logs.
enum GoogleAPIHTTP {
    /// Total attempts including the first try.
    static let maxAttempts = 3
    /// Base delay before the first retry (doubles each subsequent retry).
    static let baseBackoffNanoseconds: UInt64 = 300_000_000

    /// Performs `request` with capped retries for transient failures only.
    static func data(
        for request: URLRequest,
        api: GoogleAPIKind
    ) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        var lastError: GoogleAPIError = .invalidResponse
        let started = Date()

        while attempt < maxAttempts {
            attempt += 1
            if Task.isCancelled { throw GoogleAPIError.cancelled }

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw GoogleAPIError.invalidResponse
                }

                let ms = Int(Date().timeIntervalSince(started) * 1000)
                if (200..<300).contains(http.statusCode) {
                    await GoogleMapsDiagnostics.shared.record(
                        api: api,
                        httpStatus: http.statusCode,
                        durationMs: ms,
                        attemptCount: attempt,
                        error: nil
                    )
                    return (data, http)
                }

                let mapped = GoogleAPIError.mapHTTP(http.statusCode)
                lastError = mapped
                if !mapped.isRetryable || attempt >= maxAttempts {
                    await GoogleMapsDiagnostics.shared.record(
                        api: api,
                        httpStatus: http.statusCode,
                        durationMs: ms,
                        attemptCount: attempt,
                        error: mapped
                    )
                    throw mapped
                }
            } catch let apiError as GoogleAPIError {
                lastError = apiError
                if !apiError.isRetryable || attempt >= maxAttempts {
                    let ms = Int(Date().timeIntervalSince(started) * 1000)
                    await GoogleMapsDiagnostics.shared.record(
                        api: api,
                        httpStatus: nil,
                        durationMs: ms,
                        attemptCount: attempt,
                        error: apiError
                    )
                    throw apiError
                }
            } catch let urlError as URLError {
                let mapped = GoogleAPIError.mapURLError(urlError)
                lastError = mapped
                if !mapped.isRetryable || attempt >= maxAttempts {
                    let ms = Int(Date().timeIntervalSince(started) * 1000)
                    await GoogleMapsDiagnostics.shared.record(
                        api: api,
                        httpStatus: nil,
                        durationMs: ms,
                        attemptCount: attempt,
                        error: mapped
                    )
                    throw mapped
                }
            } catch is CancellationError {
                throw GoogleAPIError.cancelled
            } catch {
                let mapped = GoogleAPIError.invalidResponse
                lastError = mapped
                let ms = Int(Date().timeIntervalSince(started) * 1000)
                await GoogleMapsDiagnostics.shared.record(
                    api: api,
                    httpStatus: nil,
                    durationMs: ms,
                    attemptCount: attempt,
                    error: mapped
                )
                throw mapped
            }

            let shift = max(0, attempt - 1)
            let delay = baseBackoffNanoseconds << shift
            try await Task.sleep(nanoseconds: delay)
        }

        throw lastError
    }
}
