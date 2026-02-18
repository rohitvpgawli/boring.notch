//
//  PomodoroView.swift
//  boringNotch
//
//  Created by Cascade on 2025-02-17.
//

import Defaults
import SwiftUI

struct PomodoroView: View {
    @ObservedObject var pomodoroManager = PomodoroManager.shared

    var body: some View {
        VStack(spacing: 8) {
            Text("Focus")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.green)

            HStack(spacing: 12) {
                Button {
                    pomodoroManager.decrementDuration()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(canAdjust ? 0.8 : 0.3))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canAdjust)

                Text(timeDisplay)
                    .font(.system(size: 48, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: pomodoroManager.remainingSeconds)

                Button {
                    pomodoroManager.incrementDuration()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(canAdjust ? 0.8 : 0.3))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canAdjust)
            }

            actionButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var canAdjust: Bool {
        pomodoroManager.state == .idle || pomodoroManager.state == .finished
    }

    private var timeDisplay: String {
        String(format: "%d:%02d", pomodoroManager.displayMinutes, pomodoroManager.displaySeconds)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch pomodoroManager.state {
        case .idle:
            Button {
                pomodoroManager.start()
            } label: {
                HStack(spacing: 4) {
                    Text("Start Focus")
                    Image(systemName: "arrow.right")
                }
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.green)
            }
            .buttonStyle(PlainButtonStyle())

        case .running:
            HStack(spacing: 16) {
                Button {
                    pomodoroManager.pause()
                } label: {
                    Text("Pause")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    pomodoroManager.reset()
                } label: {
                    Text("Reset")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }

        case .paused:
            HStack(spacing: 16) {
                Button {
                    pomodoroManager.resume()
                } label: {
                    HStack(spacing: 4) {
                        Text("Resume")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    pomodoroManager.reset()
                } label: {
                    Text("Reset")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }

        case .finished:
            VStack(spacing: 4) {
                Text("Done!")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.green)
                Button {
                    pomodoroManager.reset()
                } label: {
                    Text("Restart")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
