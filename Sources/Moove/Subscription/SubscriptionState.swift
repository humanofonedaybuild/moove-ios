import Foundation

/// Coarse-grained subscription lifecycle surfaced on the paywall and settings.
///
/// `.trial` is only reported while the 7-day introductory offer is actively in
/// progress. Once the trial converts to a paid billing period the state
/// becomes `.active`. `.trialGrace` is the 24-hour soft window after an
/// expired trial. `.expired` is the hard lock. `.inactive` means no current
/// entitlement and no expired trial on this Apple ID.
enum SubscriptionState: Equatable, Sendable {
    case inactive
    case trial
    case trialGrace
    case active
    case expired
}
