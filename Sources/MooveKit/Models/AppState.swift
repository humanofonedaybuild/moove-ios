import Foundation

public enum MissionPhase: Codable, Equatable, Sendable {
    case waitingToStart
    case inProgress(stepsRemaining: Int)
    case completed
    case failed
}

public enum SubscriptionTier: String, Codable, Sendable {
    case free
    case premium
}
