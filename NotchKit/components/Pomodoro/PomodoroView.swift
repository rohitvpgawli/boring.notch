//
//  PomodoroView.swift
//  NotchKit
//
//  Created by Cascade on 2025-02-17.
//

import Defaults
import SwiftUI

struct PomodoroView: View {
    @ObservedObject var pomodoroManager = PomodoroManager.shared
    @State private var isBlinking: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Text(pomodoroManager.state == .finished ? "Time's Up!" : pomodoroManager.sneakPeekTaskTitle)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(pomodoroManager.state == .finished ? .red : .green)

            TextField("What are you working on?", text: Binding(
                get: { pomodoroManager.taskTitle },
                set: { pomodoroManager.updateTaskTitle($0) }
            ))
            .textFieldStyle(.plain)
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .disabled(!canAdjust)
            .opacity(canAdjust ? 1 : 0.7)


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
                    .foregroundColor(pomodoroManager.state == .finished ? .red : .white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: pomodoroManager.remainingSeconds)
                    .opacity(pomodoroManager.state == .finished ? (isBlinking ? 0.3 : 1.0) : 1.0)

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
        .onChange(of: pomodoroManager.state) { _, newState in
            if newState == .finished {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isBlinking = true
                }
            } else {
                withAnimation(.default) {
                    isBlinking = false
                }
            }
        }
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
                    .foregroundColor(.red)
                    .opacity(isBlinking ? 0.3 : 1.0)
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
