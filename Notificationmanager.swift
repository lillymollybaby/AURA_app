import SwiftUI
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted { print("Notifications granted") }
        }
    }

    func scheduleDinnerReminder() {
        let content = UNMutableNotificationContent()
        content.title = "🍽️ Время ужина!"
        content.body = "Ты ещё не залогировал ужин. Посмотри что рекомендует AURA на сегодня."
        content.sound = .default

        var components = DateComponents()
        components.hour = 18
        components.minute = 30

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "dinner_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func sendMovieLoggedNotification(movieTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "🎬 \(movieTitle) залогирован!"
        content.body = "Открой Cinema → слова из фильма уже готовы для изучения"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "movie_logged_\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func sendWordStreakNotification(streak: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🔥 Streak \(streak) дней!"
        content.body = "Не забудь выучить слова сегодня чтобы не потерять streak"
        content.sound = .default
        content.badge = 1

        var components = DateComponents()
        components.hour = 20
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "streak_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func sendCalorieReminderNotification(remaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "⚡ Осталось \(remaining) ккал"
        content.body = "Не забудь добавить ужин в дневник питания"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "calorie_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
