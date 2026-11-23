import SwiftUI
import AppKit

/// "Your day" on Nook's home: what is left of today's calendar at a glance. A rail across the day shows every event as a
/// block in its calendar's color with a line where now is, and under it the next few events, each with its calendar's
/// color down its side, its time and where it is. The event going on now says so; the next one says how soon it starts.
/// A click on an event opens Calendar at it. Nothing shows when today has nothing left.
struct AgendaStrip: View {
    let events: [CalEvent]
    /// How many events are listed under the rail; the rest are counted.
    var limit = 3

    var body: some View {
        // Once a minute: "in 5 min" counts down and the line on the rail moves along.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let left = Self.left(events, now: now)
            if !left.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    DayRail(events: left.filter { !$0.allDay }, now: now)
                        .padding(.horizontal, NookTheme.Spacing.lg + NookTheme.Spacing.xxs)
                        .padding(.top, NookTheme.Spacing.lg)
                        .padding(.bottom, NookTheme.Spacing.sm)
                    ForEach(Array(left.prefix(limit).enumerated()), id: \.element.id) { index, event in
                        if index > 0 { NookDivider(inset: NookTheme.Spacing.xxl + NookTheme.Spacing.sm) }
                        AgendaRow(event: event, now: now)
                    }
                    if left.count > limit {
                        Text(tr("home.agenda.more", left.count - limit))
                            .font(NookTheme.TextStyle.caption)
                            .foregroundStyle(NookTheme.textTertiary)
                            .padding(.horizontal, NookTheme.Spacing.lg + NookTheme.Spacing.xxs)
                            .padding(.bottom, NookTheme.Spacing.md)
                    }
                }
                .panelCard()
            }
        }
    }

    /// Today's events that have not ended yet: all-day ones first, then by start.
    static func left(_ events: [CalEvent], now: Date, calendar: Calendar = .current) -> [CalEvent] {
        events
            .filter { calendar.isDate($0.start, inSameDayAs: now) || ($0.start < now && $0.end > now) }
            .filter { $0.end > now }
            .sorted { ($0.allDay ? 0 : 1, $0.start) < ($1.allDay ? 0 : 1, $1.start) }
    }

    /// Opens Calendar on the event's day.
    static func open(_ event: CalEvent) {
        // Calendar's own scheme opens it at a date given as seconds since 2001.
        let url = URL(string: "ical://?date=\(Int(event.start.timeIntervalSinceReferenceDate))")
        if let url, NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
            NSWorkspace.shared.open(url)
        } else if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

/// The day as a thin track from the first hour with something in it to the last, each event a block in its calendar's
/// color, the hours marked underneath, and Nook's color where now is.
private struct DayRail: View {
    let events: [CalEvent]
    let now: Date

    /// From a little before the first thing (or now) to a little after the last, in whole hours, at least six of them.
    private var span: (start: Date, end: Date) {
        let calendar = Calendar.current
        let first = min(events.map(\.start).min() ?? now, now)
        let last = max(events.map(\.end).max() ?? now, now)
        let start = calendar.dateInterval(of: .hour, for: first)?.start ?? first
        var end = calendar.dateInterval(of: .hour, for: last)?.end ?? last
        if end.timeIntervalSince(start) < 6 * 3600 { end = start.addingTimeInterval(6 * 3600) }
        return (start, end)
    }

    private static let hour: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        return formatter
    }()

    var body: some View {
        let span = span
        let length = span.end.timeIntervalSince(span.start)
        let marks = hourMarks(span)
        VStack(spacing: NookTheme.Spacing.xs) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let x: (Date) -> CGFloat = { CGFloat($0.timeIntervalSince(span.start) / length) * width }
                ZStack(alignment: .leading) {
                    Capsule().fill(NookTheme.smoke)
                    ForEach(events) { event in
                        let start = max(x(event.start), 0), end = min(x(event.end), width)
                        Capsule()
                            .fill(NookPalette.eventColor(hex: event.colorHex, calendar: event.calendar)
                                .opacity(event.end <= now ? 0.35 : 1))
                            .frame(width: max(end - start, 4))
                            .offset(x: start)
                    }
                    // Now: a short bar in Nook's color, a little taller than the track.
                    Capsule()
                        .fill(NookTheme.iris)
                        .frame(width: 2, height: 14)
                        .offset(x: min(max(x(now) - 1, 0), width - 2))
                }
                .frame(height: 8)
                .frame(maxHeight: .infinity)
            }
            .frame(height: 14)
            HStack {
                ForEach(marks, id: \.self) { mark in
                    Text(Self.hour.string(from: mark))
                        .font(NookTheme.TextStyle.caption)
                        .monospacedDigit()
                        .foregroundStyle(NookTheme.textTertiary)
                    if mark != marks.last { Spacer(minLength: 0) }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// Four or five evenly spaced hours along the rail, the first and last at its ends.
    private func hourMarks(_ span: (start: Date, end: Date)) -> [Date] {
        let hours = max(Int(span.end.timeIntervalSince(span.start) / 3600), 1)
        let step = max(Int((Double(hours) / 4).rounded(.up)), 1)
        return stride(from: 0, through: hours, by: step).map { span.start.addingTimeInterval(Double($0) * 3600) }
    }
}

/// One event under the rail: its calendar's color down its side, its time, its title, and where it is or which calendar
/// it is in.
private struct AgendaRow: View {
    let event: CalEvent
    let now: Date
    @State private var hovering = false

    private static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var color: Color { NookPalette.eventColor(hex: event.colorHex, calendar: event.calendar) }
    private var ongoing: Bool { event.start <= now && event.end > now }

    private var when: String {
        if event.allDay { return tr("home.agenda.allDay") }
        return Self.time.string(from: event.start) + "–" + Self.time.string(from: event.end)
    }

    /// "Now", or how soon it starts when that is within the hour.
    private var soon: String? {
        if ongoing && !event.allDay { return tr("home.agenda.now") }
        let minutes = Int(event.start.timeIntervalSince(now) / 60)
        if minutes >= 0 && minutes < 60 { return tr("home.agenda.inMinutes", max(minutes, 1)) }
        return nil
    }

    var body: some View {
        Button { AgendaStrip.open(event) } label: {
            HStack(spacing: NookTheme.Spacing.lg) {
                RoundedRectangle(cornerRadius: NookTheme.Radius.chip / 2, style: .continuous)
                    .fill(color)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: NookTheme.Spacing.xxs) {
                    HStack(spacing: NookTheme.Spacing.sm) {
                        Text(event.title)
                            .font(NookTheme.TextStyle.strong)
                            .foregroundStyle(NookTheme.paper)
                            .lineLimit(1)
                        if let soon {
                            Text(soon)
                                .font(NookTheme.TextStyle.caption)
                                .foregroundStyle(color)
                                .padding(.horizontal, NookTheme.Spacing.sm)
                                .padding(.vertical, NookTheme.Spacing.xxs)
                                .background(Capsule().fill(color.opacity(0.16)))
                                .fixedSize()
                        }
                    }
                    HStack(spacing: NookTheme.Spacing.xs) {
                        Text(when)
                            .monospacedDigit()
                        let place = event.location.isEmpty ? event.calendar : event.location
                        if !place.isEmpty {
                            Text("·").accessibilityHidden(true)
                            Text(place).lineLimit(1)
                        }
                    }
                    .font(NookTheme.TextStyle.detail)
                    .foregroundStyle(NookTheme.textSecondary)
                }
                Spacer(minLength: NookTheme.Spacing.md)
                Image(systemName: "chevron.right")
                    .font(NookTheme.font(9.5, .semibold))
                    .foregroundStyle(hovering ? NookTheme.paper : NookTheme.textTertiary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, NookTheme.Spacing.lg + NookTheme.Spacing.xxs)
            .padding(.vertical, NookTheme.Spacing.md + NookTheme.Spacing.xxs)
            .background(hovering ? NookTheme.rowHover : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(NookTheme.hover, value: hovering)
        .help(tr("home.agenda.open"))
        .accessibilityLabel("\(event.title), \(when)" + (soon.map { ", \($0)" } ?? ""))
    }
}
