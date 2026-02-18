//
//  PomodoroManager.swift
//  boringNotch
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
    @Published var selectedMinutes: Int = Defaults[.pomodoroDuration]

    static let availableDurations = [5, 10, 15, 20, 25, 30, 45, 60]

    private var timerCancellable: AnyCancellable?

    private init() {
        remainingSeconds = selectedMinutes * 60
    }

    var displayMinutes: Int {
        remainingSeconds / 60
    }

    var displaySeconds: Int {
        remainingSeconds % 60
    }

    var progress: Double {
        let total = Double(selectedMinutes * 60)
        guard total > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / total)
    }

    func incrementDuration() {
        guard state == .idle || state == .finished else { return }
        if let currentIndex = Self.availableDurations.firstIndex(of: selectedMinutes),
           currentIndex < Self.availableDurations.count - 1 {
            selectedMinutes = Self.availableDurations[currentIndex + 1]
        } else if !Self.availableDurations.contains(selectedMinutes) {
            selectedMinutes = Self.availableDurations.last ?? 60
        }
        remainingSeconds = selectedMinutes * 60
        Defaults[.pomodoroDuration] = selectedMinutes
    }

    func decrementDuration() {
        guard state == .idle || state == .finished else { return }
        if let currentIndex = Self.availableDurations.firstIndex(of: selectedMinutes),
           currentIndex > 0 {
            selectedMinutes = Self.availableDurations[currentIndex - 1]
        } else if !Self.availableDurations.contains(selectedMinutes) {
            selectedMinutes = Self.availableDurations.first ?? 5
        }
        remainingSeconds = selectedMinutes * 60
        Defaults[.pomodoroDuration] = selectedMinutes
    }

    func start() {
        if state == .finished || state == .idle {
            remainingSeconds = selectedMinutes * 60
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
        remainingSeconds = selectedMinutes * 60
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
        // Play system beep repeatedly (3 times) to alert the user
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                NSSound.beep()
            }
        }
    }
}

extension Notification.Name {
    static let pomodoroTimerFinished = Notification.Name("pomodoroTimerFinished")
}
