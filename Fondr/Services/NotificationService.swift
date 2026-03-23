import Foundation
import UserNotifications
import UIKit

@Observable
final class NotificationService {

    func startListening(pairId: String, partnerUid: String) {
        // Push notifications are now handled server-side via APNs.
        // No client-side Firestore listeners needed.
        // The WebSocket connection delivers real-time events when the app is in foreground.
    }

    func stopListening() {
        // No-op — no listeners to clean up
    }

    // MARK: - Scheduled Reminders

    func scheduleReminders(significantDates: [SignificantDate], calendarEvents: [CalendarEvent], anniversary: Date?) {
        let center = UNUserNotificationCenter.current()

        center.getPendingNotificationRequests { requests in
            let reminderIds = requests.filter { $0.identifier.hasPrefix("reminder-") }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: reminderIds)

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            var items: [(id: String, title: String, date: Date, type: String)] = []

            // Anniversary
            if let anniversary {
                let comps = calendar.dateComponents([.month, .day], from: anniversary)
                if let month = comps.month, let day = comps.day {
                    let year = calendar.component(.year, from: today)
                    var dc = DateComponents(year: year, month: month, day: day)
                    if let candidate = calendar.date(from: dc), calendar.startOfDay(for: candidate) >= today {
                        items.append((id: "anniversary", title: "Anniversary", date: calendar.startOfDay(for: candidate), type: "ourStory"))
                    } else {
                        dc.year = year + 1
                        if let next = calendar.date(from: dc) {
                            items.append((id: "anniversary", title: "Anniversary", date: calendar.startOfDay(for: next), type: "ourStory"))
                        }
                    }
                }
            }

            // Significant dates
            for sigDate in significantDates {
                let targetDate: Date?
                if sigDate.recurring {
                    let comps = calendar.dateComponents([.month, .day], from: sigDate.date)
                    if let month = comps.month, let day = comps.day {
                        let year = calendar.component(.year, from: today)
                        var dc = DateComponents(year: year, month: month, day: day)
                        if let candidate = calendar.date(from: dc), calendar.startOfDay(for: candidate) >= today {
                            targetDate = calendar.startOfDay(for: candidate)
                        } else {
                            dc.year = year + 1
                            targetDate = calendar.date(from: dc).map { calendar.startOfDay(for: $0) }
                        }
                    } else {
                        targetDate = nil
                    }
                } else {
                    let sigDay = calendar.startOfDay(for: sigDate.date)
                    targetDate = sigDay >= today ? sigDay : nil
                }
                if let target = targetDate {
                    items.append((id: sigDate.id, title: sigDate.title, date: target, type: "ourStory"))
                }
            }

            // Accepted calendar events
            for event in calendarEvents where event.status == .accepted {
                guard let startDate = dateFormatter.date(from: event.startDate) else { continue }
                let eventDay = calendar.startOfDay(for: startDate)
                guard eventDay >= today else { continue }
                items.append((id: event.id, title: event.title, date: eventDay, type: "event"))
            }

            // Schedule 7-day and 1-day reminders
            for item in items {
                let daysUntil = calendar.dateComponents([.day], from: today, to: item.date).day ?? 0

                if daysUntil >= 7, let triggerDate = calendar.date(byAdding: .day, value: -7, to: item.date) {
                    let triggerComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                    let content = UNMutableNotificationContent()
                    content.title = "Coming Up Next Week"
                    content.body = "\(item.title) is in 1 week"
                    content.sound = .default
                    content.userInfo = ["type": item.type]
                    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
                    let request = UNNotificationRequest(identifier: "reminder-7d-\(item.id)", content: content, trigger: trigger)
                    center.add(request)
                }

                if daysUntil >= 1, let triggerDate = calendar.date(byAdding: .day, value: -1, to: item.date) {
                    let triggerComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                    let content = UNMutableNotificationContent()
                    content.title = "Tomorrow"
                    content.body = "\(item.title) is tomorrow!"
                    content.sound = .default
                    content.userInfo = ["type": item.type]
                    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
                    let request = UNNotificationRequest(identifier: "reminder-1d-\(item.id)", content: content, trigger: trigger)
                    center.add(request)
                }
            }
        }
    }
}
