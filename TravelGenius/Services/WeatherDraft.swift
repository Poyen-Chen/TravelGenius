import Foundation
import Observation

/// Owns cancellation, timeout and preview freezing independently from the provider.
@MainActor @Observable
final class WeatherDraft {
    private(set) var request: WeatherRequest?
    private(set) var result: PackingWeather?
    private(set) var loading = false
    private var revision = UUID()
    private var worker: Task<Void, Never>?
    private var deadline: Task<Void, Never>?

    func begin(_ query: WeatherRequest?,
               debounce: Duration = .milliseconds(300), timeout: Duration = .seconds(10),
               fetch: @escaping @MainActor (WeatherRequest) async throws -> PackingWeather,
               fallback: @escaping @MainActor (WeatherRequest, WeatherFailure) -> PackingWeather) {
        guard query != request || (query != nil && result == nil && !loading) else { return }
        cancel()
        request = query
        result = nil
        guard let query else { return }
        loading = true
        let token = revision
        worker = Task {
            do {
                try await Task.sleep(for: debounce)
                let value = try await fetch(query)
                guard !Task.isCancelled, revision == token, request == query else { return }
                result = value; loading = false; deadline?.cancel()
            } catch {
                guard !Task.isCancelled, revision == token else { return }
                result = fallback(query, .unavailable); loading = false; deadline?.cancel()
            }
        }
        // Separate task: UI never waits for an SDK call that ignores cancellation.
        deadline = Task {
            do { try await Task.sleep(for: timeout) } catch { return }
            guard revision == token, loading else { return }
            useFallback(fallback(query, .timeout))
        }
    }

    func useFallback(_ value: PackingWeather) {
        cancel()
        request = value.request; result = value
    }
    func cancel() {
        revision = UUID(); worker?.cancel(); deadline?.cancel(); loading = false
    }
}
