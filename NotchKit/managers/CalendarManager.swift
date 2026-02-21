//
//  CalendarManager.swift
//  NotchKit
//
//  Created by Harsh Vardhan  Goswami  on 08/09/24.
//

import Defaults
import EventKit
import SwiftUI

// MARK: - CalendarManager

@MainActor
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    @Published var currentWeekStartDate: Date
    @Published var events: [EventModel] = []
    @Published var allCalendars: [CalendarModel] = []
    @Published var eventCalendars: [CalendarModel] = []
    @Published var reminderLists: [CalendarModel] = []
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var reminderAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    private var selectedCalendars: [CalendarModel] = []
    private let calendarService = CalendarService()
    private var reminderPreviewTask: Task<Void, Never>?
    private var lastShownReminderID: String?

    private var eventStoreChangedObserver: NSObjectProtocol?

    private init() {
        self.currentWeekStartDate = CalendarManager.startOfDay(Date())
        setupEventStoreChangedObserver()
        Task {
            await reloadCalendarAndReminderLists()
            await refreshUpcomingReminderPreview()
        }
        startReminderPreviewLoop()
    }

    deinit {
        reminderPreviewTask?.cancel()
        if let observer = eventStoreChangedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupEventStoreChangedObserver() {
        eventStoreChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.reloadCalendarAndReminderLists()
                await self?.refreshUpcomingReminderPreview()
            }
        }
    }

    @MainActor
    func reloadCalendarAndReminderLists() async {
        let all = await calendarService.calendars()
        self.eventCalendars = all.filter { !$0.isReminder }
        self.reminderLists = all.filter { $0.isReminder }
        self.allCalendars = all // for legacy compatibility, can be removed if not needed
        updateSelectedCalendars()
    }

    func checkCalendarAuthorization() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        DispatchQueue.main.async {
            print("📅 Current calendar authorization status: \(status)")
            self.calendarAuthorizationStatus = status
        }

        switch status {
        case .notDetermined:
            guard let granted = try? await calendarService.requestAccess(to: .event) else {
                self.calendarAuthorizationStatus = .notDetermined
                return
            }
            self.calendarAuthorizationStatus = granted ? .fullAccess : .denied
            if granted {
                await reloadCalendarAndReminderLists()
                events = await calendarService.events(
                    from: currentWeekStartDate,
                    to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
                    calendars: selectedCalendars.map { $0.id })
            }
        case .restricted, .denied:
            NSLog("Calendar access denied or restricted")
        case .fullAccess:
            NSLog("Full access")
            await reloadCalendarAndReminderLists()
            await refreshUpcomingReminderPreview()
            events = await calendarService.events(
                from: currentWeekStartDate,
                to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
                calendars: selectedCalendars.map { $0.id })
        case .writeOnly:
            NSLog("Write only")
        @unknown default:
            print("Unknown authorization status")
        }
    }
    
    func checkReminderAuthorization() async {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        DispatchQueue.main.async {
            print("📅 Current reminder authorization status: \(status)")
            self.reminderAuthorizationStatus = status
        }

        switch status {
        case .notDetermined:
            guard let granted = try? await calendarService.requestAccess(to: .reminder) else {
                self.reminderAuthorizationStatus = .notDetermined
                return
            }
            self.reminderAuthorizationStatus = granted ? .fullAccess : .denied
            if granted {
                await reloadCalendarAndReminderLists()
                await refreshUpcomingReminderPreview()
            }
        case .restricted, .denied:
            NSLog("Reminder access denied or restricted")
        case .fullAccess:
            NSLog("Full access")
            await reloadCalendarAndReminderLists()
            await refreshUpcomingReminderPreview()
        case .writeOnly:
            NSLog("Write only")
        @unknown default:
            print("Unknown authorization status")
        }
    }
        

    func updateSelectedCalendars() {
        // Populate selectedCalendarIDs based on Defaults calendar selection state
        switch Defaults[.calendarSelectionState] {
        case .all:
            selectedCalendarIDs = Set(allCalendars.map { $0.id })
        case .selected(let identifiers):
            selectedCalendarIDs = identifiers
        }

        // Update the local calendar objects that correspond to the selected ids
        selectedCalendars = allCalendars.filter { selectedCalendarIDs.contains($0.id) }

        Task {
            await refreshUpcomingReminderPreview()
        }
    }

    func getCalendarSelected(_ calendar: CalendarModel) -> Bool {
        return selectedCalendarIDs.contains(calendar.id)
    }

    func setCalendarSelected(_ calendar: CalendarModel, isSelected: Bool) async {
        var selectionState = Defaults[.calendarSelectionState]

        switch selectionState {
        case .all:
            if !isSelected {
                let identifiers = Set(allCalendars.map { $0.id }).subtracting([calendar.id])
                selectionState = .selected(identifiers)
            }

        case .selected(var identifiers):
            if isSelected {
                identifiers.insert(calendar.id)
            } else {
                identifiers.remove(calendar.id)
            }

            selectionState =
                identifiers.isEmpty
                ? .all : identifiers.count == allCalendars.count ? .all : .selected(identifiers)  // if empty, select all
        }

        Defaults[.calendarSelectionState] = selectionState
        updateSelectedCalendars()
        await updateEvents()
    }

    static func startOfDay(_ date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }

    func updateCurrentDate(_ date: Date) async {
        currentWeekStartDate = Calendar.current.startOfDay(for: date)
        await updateEvents()
    }

    private func updateEvents() async {
        let calendarIDs = selectedCalendars.map { $0.id }
        let eventsResult = await calendarService.events(
            from: currentWeekStartDate,
            to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
            calendars: calendarIDs
        )
        self.events = eventsResult
    }
    
    func setReminderCompleted(reminderID: String, completed: Bool) async {
        await calendarService.setReminderCompleted(reminderID: reminderID, completed: completed)
        // Refresh events after updating
        events = await calendarService.events(
            from: currentWeekStartDate,
            to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
            calendars: selectedCalendars.map { $0.id })
        await refreshUpcomingReminderPreview()
    }

    private func startReminderPreviewLoop() {
        reminderPreviewTask?.cancel()
        reminderPreviewTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self = self else { return }
                await self.refreshUpcomingReminderPreview()
            }
        }
    }

    private func refreshUpcomingReminderPreview() async {
        guard Defaults[.showCalendar] else { return }

        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        guard reminderStatus == .fullAccess else {
            lastShownReminderID = nil
            return
        }

        let now = Date()
        guard let end = Calendar.current.date(byAdding: .minute, value: 30, to: now) else { return }

        let reminderCalendarIDs = selectedCalendars
            .filter(\.isReminder)
            .map(\.id)

        let upcoming = await calendarService.events(from: now, to: end, calendars: reminderCalendarIDs)
            .filter { event in
                guard event.type.isReminder else { return false }
                if case .reminder(let completed) = event.type {
                    return !completed
                }
                return false
            }
            .sorted { $0.start < $1.start }
            .first

        guard let reminder = upcoming else {
            lastShownReminderID = nil
            return
        }

        guard reminder.id != lastShownReminderID else { return }

        lastShownReminderID = reminder.id

        let minutesUntil = max(0, Int(ceil(reminder.start.timeIntervalSince(now) / 60)))
        let subtitle = minutesUntil <= 1 ? "Due soon" : "Due in \(minutesUntil)m"

        NotchKitViewCoordinator.shared.toggleSneakPeek(
            status: true,
            type: .reminder,
            duration: 4.0,
            icon: "checklist",
            text: "\(subtitle): \(reminder.title)"
        )
    }
}

