import Foundation
import StoreKit

/// Manages StoreKit 2 subscriptions for Kairo Pro.
///
/// Provides async/await product fetching, purchase flow, restore, and
/// a transaction listener for auto-renewal updates. All entitlement
/// checks are local via StoreKit 2 — no server required.
@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: - Product IDs

    static let monthlyID  = "com.apexdigital.kairo.pro.monthly"
    static let annualID   = "com.apexdigital.kairo.pro.annual"

    private static let productIDs: Set<String> = [monthlyID, annualID]

    // MARK: - Published State

    /// All available products fetched from the App Store.
    @Published var products: [Product] = []

    /// Whether the user currently has Pro access (subscription or reverse trial).
    @Published var isPro: Bool = false

    /// The currently active subscription product ID, if any.
    @Published var activeSubscriptionID: String?

    /// Loading state for UI binding.
    @Published var isLoading: Bool = false

    /// Purchase in progress.
    @Published var isPurchasing: Bool = false

    /// Error message for UI display.
    @Published var errorMessage: String?

    // MARK: - Private

    /// Handle for the transaction listener task.
    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        // Start listening for transaction updates immediately
        transactionListenerTask = listenForTransactions()

        // Check entitlement on launch
        Task {
            await fetchProducts()
            await refreshEntitlementStatus()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Fetch Products

    /// Loads available subscription products from the App Store.
    func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            // Sort so monthly comes first, annual second
            products = storeProducts.sorted { p1, _ in
                p1.id == Self.monthlyID
            }
        } catch {
            errorMessage = "Unable to load subscription options."
        }
    }

    // MARK: - Purchase

    /// Initiates a purchase for the given product.
    /// - Parameter product: The `Product` to purchase.
    /// - Returns: `true` if the purchase succeeded and Pro is now active.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                // Finish the transaction — tells StoreKit we've delivered the content.
                await transaction.finish()
                await refreshEntitlementStatus()
                return true

            case .userCancelled:
                return false

            case .pending:
                // Ask to Buy or other deferred state
                errorMessage = "Purchase is pending approval."
                return false

            @unknown default:
                errorMessage = "An unexpected error occurred."
                return false
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
            return false
        }
    }

    // MARK: - Restore Purchases

    /// Syncs transactions with the App Store to restore previous purchases.
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlementStatus()
        } catch {
            errorMessage = "Unable to restore purchases. Please try again."
        }
    }

    // MARK: - Entitlement Check

    /// Refreshes the Pro entitlement status by checking current transactions
    /// and the reverse trial window.
    func refreshEntitlementStatus() async {
        // 1. Check reverse trial (first 7 days after install)
        if isWithinReverseTrial() {
            isPro = true
            activeSubscriptionID = nil
            return
        }

        // 2. Check active StoreKit 2 entitlements
        var foundActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if Self.productIDs.contains(transaction.productID) {
                // Check it hasn't been revoked
                if transaction.revocationDate == nil {
                    foundActiveSubscription = true
                    activeSubscriptionID = transaction.productID
                    break
                }
            }
        }

        isPro = foundActiveSubscription
        if !foundActiveSubscription {
            activeSubscriptionID = nil
        }
    }

    // MARK: - Reverse Trial

    /// Whether the user is within the 7-day reverse trial period.
    func isWithinReverseTrial() -> Bool {
        let key = "kairo_install_date"
        guard let installDate = UserDefaults.standard.object(forKey: key) as? Date else {
            // No install date recorded yet — treat as new install
            UserDefaults.standard.set(Date(), forKey: key)
            return true
        }
        let trialDuration: TimeInterval = 7 * 24 * 60 * 60 // 7 days
        return Date().timeIntervalSince(installDate) < trialDuration
    }

    /// Days remaining in the reverse trial. Returns 0 if trial has expired.
    var reverseTrialDaysRemaining: Int {
        let key = "kairo_install_date"
        guard let installDate = UserDefaults.standard.object(forKey: key) as? Date else { return 7 }
        let elapsed = Date().timeIntervalSince(installDate)
        let totalTrial: TimeInterval = 7 * 24 * 60 * 60
        let remaining = totalTrial - elapsed
        return max(0, Int(ceil(remaining / (24 * 60 * 60))))
    }

    // MARK: - Subscription Info Helpers

    /// Returns the monthly product, if loaded.
    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyID }
    }

    /// Returns the annual product, if loaded.
    var annualProduct: Product? {
        products.first { $0.id == Self.annualID }
    }

    /// Human-readable subscription status for the Settings view.
    var subscriptionStatusText: String {
        if isWithinReverseTrial() {
            let days = reverseTrialDaysRemaining
            return "Pro Trial — \(days) day\(days == 1 ? "" : "s") left"
        }

        if let activeID = activeSubscriptionID {
            switch activeID {
            case Self.monthlyID: return "Pro Monthly"
            case Self.annualID:  return "Pro Annual"
            default:             return "Pro"
            }
        }

        return "Free"
    }

    // MARK: - Transaction Listener

    /// Listens for StoreKit transaction updates (renewals, revocations, refunds).
    /// Runs for the lifetime of the app.
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { break }

                if case .verified(let transaction) = result {
                    // Finish the transaction
                    await transaction.finish()
                    // Refresh entitlement on the main actor
                    await self.refreshEntitlementStatus()
                }
            }
        }
    }

    // MARK: - Verification

    /// Unwraps a verified transaction, throwing on verification failure.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
