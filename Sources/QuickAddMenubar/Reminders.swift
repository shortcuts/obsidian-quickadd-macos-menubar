import EventKit

/// Creates one reminder. iCloud sync then delivers its alert to the user's other devices.
enum Reminders {
  private static let store = EKEventStore()

  struct Failure: LocalizedError {
    let errorDescription: String?
  }

  static func add(
    title: String, url: URL, due: Date, list: String, completion: @escaping (Error?) -> Void
  ) {
    let done: (Bool, Error?) -> Void = { granted, error in
      guard granted else {
        return completion(
          error
            ?? Failure(
              errorDescription:
                "Reminders access is denied. Allow it in System Settings → Privacy & Security → Reminders."
            ))
      }
      completion(save(title: title, url: url, due: due, list: list))
    }
    if #available(macOS 14.0, *) {
      store.requestFullAccessToReminders(completion: done)
    } else {
      store.requestAccess(to: .reminder, completion: done)
    }
  }

  private static func save(title: String, url: URL, due: Date, list: String) -> Error? {
    do {
      let calendar = try findOrCreate(list: list)
      let reminder = EKReminder(eventStore: store)
      reminder.title = title
      reminder.url = url
      reminder.calendar = calendar
      reminder.dueDateComponents = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute], from: due)
      reminder.addAlarm(EKAlarm(absoluteDate: due))
      try store.save(reminder, commit: true)
      return nil
    } catch {
      return error
    }
  }

  private static func findOrCreate(list: String) throws -> EKCalendar {
    let lists = store.calendars(for: .reminder)
    if let found = lists.first(where: { $0.title == list && $0.allowsContentModifications }) {
      return found
    }
    // A new list must live in the account that syncs, so it follows the default list.
    guard let source = store.defaultCalendarForNewReminders()?.source else {
      throw Failure(errorDescription: "No Reminders account found to create the list \"\(list)\".")
    }
    let created = EKCalendar(for: .reminder, eventStore: store)
    created.title = list
    created.source = source
    try store.saveCalendar(created, commit: true)
    return created
  }
}
