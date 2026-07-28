import Foundation

public extension Notification.Name {
    static let alarmDidFire = Notification.Name("com.moove.alarmDidFire")
    static let alarmMissionCompleted = Notification.Name("com.moove.alarmMissionCompleted")
    static let stepCountUpdated = Notification.Name("com.moove.stepCountUpdated")
    static let shakeDetected = Notification.Name("com.moove.shakeDetected")
    static let subscriptionStatusChanged = Notification.Name("com.moove.subscriptionStatusChanged")
}
