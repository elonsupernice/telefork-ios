import Foundation
import Observation

/// A deadline bounds the visible loading state even if a dependency ignores
/// cancellation. A late response cannot replace a newer attempt or timeout.
@MainActor
@Observable
final class MembershipPaywallLoader {
    private(set) var isLoading = true
    private(set) var snapshot: MembershipPresentationSnapshot?
    private(set) var errorMessage: String?
    @ObservationIgnored private var requestTask: Task<Void, Never>?
    @ObservationIgnored private var deadlineTask: Task<Void, Never>?
    private var attempt = UUID()

    func load(timeout: Duration = .seconds(20),
              fetch: @escaping @MainActor () async throws -> MembershipPresentationSnapshot) {
        cancel()
        let current = UUID()
        attempt = current
        isLoading = true
        snapshot = nil
        errorMessage = nil
        requestTask = Task { [weak self] in
            do {
                let result = try await fetch()
                guard let self, self.attempt == current, self.isLoading, !Task.isCancelled else { return }
                self.snapshot = result
                self.isLoading = false
                self.deadlineTask?.cancel()
            } catch {
                guard let self, self.attempt == current, self.isLoading, !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.deadlineTask?.cancel()
            }
        }
        deadlineTask = Task { [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            guard let self, self.attempt == current, self.isLoading else { return }
            self.errorMessage = String(localized: "membership.presentation.timeout")
            self.isLoading = false
            self.requestTask?.cancel()
        }
    }

    func cancel() {
        attempt = UUID()
        requestTask?.cancel()
        deadlineTask?.cancel()
        requestTask = nil
        deadlineTask = nil
        isLoading = false
    }
}
