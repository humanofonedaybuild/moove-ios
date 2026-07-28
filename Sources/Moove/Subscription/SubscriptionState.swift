import Foundation

/// Coarse-grained subscription lifecycle surfaced on the paywall and settings.
///
/// `.trial` is only reported while the 7-day introductory offer is actively in
/// progress. Once the trial converts to a paid billing period the state
/// becomes `.active`. `.inactive` means no current entitlement.
enum SubscriptionState: Equatable, Sendable {
    case inactive
    case trial
    case active
}
