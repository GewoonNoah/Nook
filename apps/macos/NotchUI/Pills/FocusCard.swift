import SwiftUI

/// "Focus" on Nook's home: start a stretch of focused work in one click (25, 50 or 90 minutes), then a ring in Nook's
/// color counts it down with the time left in the middle, with "+5 min" and "Stop" beside it. When the time is up Nook
/// celebrates it next to the notch (`AppModel.startFocus`).
struct FocusCard: View {
    @ObservedObject var timer: FocusTimer = .shared
    @EnvironmentObject private var app: AppModel

    var body: some View {
        Group {
            if let session = timer.session {
                running(session)
            } else {
                idle
            }
        }
        .padding(.horizontal, NookTheme.Spacing.lg + NookTheme.Spacing.xxs)
        .padding(.vertical, NookTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
        .animation(NookTheme.reveal, value: timer.session)
    }

    private var idle: some View {
        HStack(spacing: NookTheme.Spacing.md) {
            Image(systemName: "timer")
                .font(NookTheme.font(13, .semibold))
                .foregroundStyle(NookTheme.iris)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: NookTheme.Radius.control, style: .continuous)
                    .fill(NookTheme.iris.opacity(0.14)))
            VStack(alignment: .leading, spacing: NookTheme.Spacing.xxs) {
                Text(tr("focus.title"))
                    .font(NookTheme.TextStyle.strong)
                    .foregroundStyle(NookTheme.paper)
                Text(tr("focus.hint"))
                    .font(NookTheme.TextStyle.detail)
                    .foregroundStyle(NookTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: NookTheme.Spacing.sm)
            ForEach(FocusSession.presets, id: \.self) { minutes in
                FocusChip(title: tr("focus.minutes", minutes)) { app.startFocus(minutes: minutes) }
            }
        }
    }

    private func running(_ session: FocusSession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            HStack(spacing: NookTheme.Spacing.lg) {
                FocusRing(progress: session.progress(at: now))
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: NookTheme.Spacing.xxs) {
                    Text(FocusSession.clock(session.remaining(at: now)))
                        .font(NookTheme.rounded(20, .semibold))
                        .monospacedDigit()
                        .foregroundStyle(NookTheme.paper)
                        .contentTransition(.numericText(countsDown: true))
                    Text(tr("focus.until", NookDates.formatter("HH:mm", locale: I18n.shared.currentLanguage.rawValue)
                        .string(from: session.ends)))
                        .font(NookTheme.TextStyle.detail)
                        .foregroundStyle(NookTheme.textSecondary)
                }
                Spacer(minLength: NookTheme.Spacing.sm)
                FocusChip(title: tr("focus.extend")) { timer.extend() }
                FocusChip(title: tr("focus.stop"), muted: true) { timer.stop() }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(tr("focus.left", FocusSession.clock(session.remaining(at: now))))
        }
    }
}

/// The countdown as a ring: Nook's color for what is behind you, a faint track for what is left.
private struct FocusRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(NookTheme.smoke, lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(AngularGradient(colors: [NookTheme.iris.opacity(0.55), NookTheme.iris], center: .center),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(NookTheme.reveal, value: progress)
            Image(systemName: "brain.head.profile")
                .font(NookTheme.font(13, .medium))
                .foregroundStyle(NookTheme.iris)
        }
        .accessibilityHidden(true)
    }
}

/// A small capsule button on the Focus card: a length to start, "+5 min" or "Stop".
private struct FocusChip: View {
    let title: String
    var muted = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NookTheme.TextStyle.label)
                .monospacedDigit()
                .foregroundStyle(muted ? NookTheme.textSecondary : (hovering ? NookTheme.onIris : NookTheme.textStrong))
                .padding(.horizontal, NookTheme.Spacing.md)
                .frame(height: 26)
                .background(Capsule().fill(muted ? (hovering ? NookTheme.smoke : Color.clear)
                                           : (hovering ? NookTheme.iris : NookTheme.smoke)))
                .contentShape(Capsule())
                .hoverLift(hovering, scale: 1.03)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(NookTheme.hover, value: hovering)
        .accessibilityLabel(title)
    }
}
