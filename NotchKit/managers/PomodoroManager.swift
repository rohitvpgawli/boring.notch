//
//  PomodoroManager.swift
//  NotchKit
//
//  Created by Cascade on 2025-02-17.
//

import AppKit
import Combine
import Defaults
import Foundation

enum PomodoroState {
    case idle
    case running
    case paused
    case finished
}

@MainActor
class PomodoroManager: ObservableObject {
    static let shared = PomodoroManager()

    @Published var state: PomodoroState = .idle
    @Published var remainingSeconds: Int = 25 * 60
    @Published var selectedDurationSeconds: Int = Defaults[.pomodoroDuration]

    // Durations in seconds: 30s, 1m, 2m, 5m, 10m, 15m, 20m, 25m, 30m, 45m, 60m
    static let availableDurations: [Int] = [30, 60, 120, 300, 600, 900, 1200, 1500, 1800, 2700, 3600]

    private var timerCancellable: AnyCancellable?

    private init() {
        remainingSeconds = selectedDurationSeconds
    }

    var displayMinutes: Int {
        remainingSeconds / 60
    }

    var displaySeconds: Int {
        remainingSeconds % 60
    }

    var progress: Double {
        let total = Double(selectedDurationSeconds)
        guard total > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / total)
    }

    var durationLabel: String {
        if selectedDurationSeconds < 60 {
            return "\(selectedDurationSeconds)s"
        } else {
            return "\(selectedDurationSeconds / 60)m"
        }
    }

    func incrementDuration() {
        guard state == .idle || state == .finished else { return }
        if let currentIndex = Self.availableDurations.firstIndex(of: selectedDurationSeconds),
           currentIndex < Self.availableDurations.count - 1 {
            selectedDurationSeconds = Self.availableDurations[currentIndex + 1]
        } else if !Self.availableDurations.contains(selectedDurationSeconds) {
            selectedDurationSeconds = Self.availableDurations.last ?? 3600
        }
        remainingSeconds = selectedDurationSeconds
        Defaults[.pomodoroDuration] = selectedDurationSeconds
    }

    func decrementDuration() {
        guard state == .idle || state == .finished else { return }
        if let currentIndex = Self.availableDurations.firstIndex(of: selectedDurationSeconds),
           currentIndex > 0 {
            selectedDurationSeconds = Self.availableDurations[currentIndex - 1]
        } else if !Self.availableDurations.contains(selectedDurationSeconds) {
            selectedDurationSeconds = Self.availableDurations.first ?? 30
        }
        remainingSeconds = selectedDurationSeconds
        Defaults[.pomodoroDuration] = selectedDurationSeconds
    }

    func start() {
        if state == .finished || state == .idle {
            remainingSeconds = selectedDurationSeconds
        }
        state = .running
        startTimer()
    }

    func pause() {
        state = .paused
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func resume() {
        state = .running
        startTimer()
    }

    func reset() {
        state = .idle
        timerCancellable?.cancel()
        timerCancellable = nil
        remainingSeconds = selectedDurationSeconds
    }

    private func startTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
    }

    private func tick() {
        guard state == .running else { return }

        if remainingSeconds > 0 {
            remainingSeconds -= 1
        }

        if remainingSeconds <= 0 {
            timerCancellable?.cancel()
            timerCancellable = nil
            state = .finished
            playCompletionSound()
            NotificationCenter.default.post(name: .pomodoroTimerFinished, object: nil)
        }
    }

    private func playCompletionSound() {
        // Play system beep repeatedly (5 times) to clearly alert the user
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                NSSound.beep()
            }
        }
    }
}

extension Notification.Name {
    static let pomodoroTimerFinished = Notification.Name("pomodoroTimerFinished")
}
