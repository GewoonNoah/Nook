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
    /// Shows tomorrow instead of today: when today has nothing left, home looks ahead.
    var tomorrow = false

    var body: some View {
        // Once a minute: "in 5 min" counts down and the line on the rail moves along.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let left = tomorrow ? Self.tomorrow(events, now: now) : Self.left(events, now: now)
            if !left.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    if !tomorrow, let free = Self.freeLine(left, now: now) {
                        Text(free)
                            .font(NookTheme.TextStyle.label)
                            .foregroundStyle(NookTheme.textSecondary)
                            .padding(.horizontal, NookTheme.Spacing.lg + NookTheme.Spacing.xxs)
                            .padding(.top, NookTheme.Spacing.lg)
                    }
                    DayRail(events: left.filter { !$0.allDay }, now: tomorrow ? nil : now)
                        .padding(.horizontal, NookTheme.Spacing.lg + NookTheme.Spacing.xxs)
                        .padding(.top, NookTheme.Spacing.lg)
                        .padding(.bottom, NookTheme.Spacing.sm)
                    ForEach(Array(left.prefix(limit).enumerated()), id: \.element.id) { index, event in
                        if index > 0 { NookDivider(inset: NookTheme.Spacing.xxl + NookTheme.Spacing.sm) }
                        AgendaRow(event: event, now: now, showsSoon: !tomorrow)
                    }
                    if left.count > limit {
                        Text(tr(tomorrow ? "home.agenda.moreTomorrow" : "home.agenda.more", left.count - limit))
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

    /// Tomorrow's events, all-day ones first: what home looks ahead to once today has nothing left.
    static func tomorrow(_ events: [CalEvent], now: Date, calendar: Calendar = .current) -> [CalEvent] {
        guard let next = calendar.date(byAdding: .day, value: 1, to: now) else { return [] }
        return events
            .filter { calendar.isDate($0.start, inSameDayAs: next) }
            .sorted { ($0.allDay ? 0 : 1, $0.start) < ($1.allDay ? 0 : 1, $1.start) }
    }

    /// "Free until 14:00", "Busy until 15:30", or "Free for the rest of the day" once the last event is over; nil while
    /// nothing timed is left (only all-day events).
    static func freeLine(_ events: [CalEvent], now: Date) -> String? {
        let timed = events.filter { !$0.allDay && $0.busy }
        guard !timed.isEmpty else { return nil }
        let time = NookDates.formatter("HH:mm", locale: I18n.shared.currentLanguage.rawValue)
        if let current = timed.filter({ $0.start <= now && $0.end > now }).max(by: { $0.end < $1.end }) {
            // Back to back: busy until the end of the run of meetings, not just this one.
            var until = current.end
            for event in timed.sorted(by: { $0.start < $1.start }) where event.start <= until && event.end > until {
                until = event.end
            }
            return tr("home.agenda.busyUntil", time.string(from: until))
        }
        if let next = timed.filter({ $0.start > now }).min(by: { $0.start < $1.start }) {
            return tr("home.agenda.freeUntil", time.string(from: next.start))
        }
        return nil
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
    /// Where now is on the rail; nil for another day.
    let now: Date?

    /// From a little before the first thing (or now) to a little after the last, in whole hours, at least six of them.
    private var dayRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let anchor = now ?? events.map(\.start).min() ?? Date()
        let first = min(events.map(\.start).min() ?? anchor, anchor)
        let last = max(events.map(\.end).max() ?? anchor, anchor)
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
        let span = dayRange
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
                                .opacity(now.map { event.end <= $0 } == true ? 0.35 : 1))
                            .frame(width: max(end - start, 4))
                            .offset(x: start)
                    }
                    // Now: a short bar in Nook's color, a little taller than the track.
                    if let now {
                        Capsule()
                            .fill(NookTheme.iris)
                            .frame(width: 2, height: 14)
                            .offset(x: min(max(x(now) - 1, 0), width - 2))
                    }
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
    /// "Now" and "In 5 min": only for today.
    var showsSoon = true
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
        guard showsSoon else { return nil }
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
                // A call that starts within a quarter of an hour, or is going on: join it from here.
                if let meeting = event.meeting, showsSoon, event.end > now,
                   event.start.timeIntervalSince(now) < 15 * 60 {
                    JoinCallButton(meeting: meeting)
                } else {
                    Image(systemName: "chevron.right")
                        .font(NookTheme.font(9.5, .semibold))
                        .foregroundStyle(hovering ? NookTheme.paper : NookTheme.textTertiary)
                }
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

/// "Join" on an event whose video call is about to start: in the service's own color, it opens the call's link.
private struct JoinCallButton: View {
    let meeting: MeetingLink
    @State private var hovering = false

    var body: some View {
        let color = NookPalette.meeting(meeting.service)
        Button { NSWorkspace.shared.open(meeting.url) } label: {
            HStack(spacing: NookTheme.Spacing.xs) {
                Image(systemName: "video.fill")
                    .font(NookTheme.font(10, .semibold))
                Text(tr("home.agenda.join"))
                    .font(NookTheme.TextStyle.label)
            }
            .foregroundStyle(NookTheme.ink)
            .padding(.horizontal, NookTheme.Spacing.md)
            .frame(height: 26)
            .background(Capsule().fill(color.opacity(hovering ? 1 : 0.9)))
            .hoverLift(hovering, scale: 1.03)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(tr("home.agenda.joinHelp", meeting.service.title))
        .accessibilityLabel(tr("home.agenda.joinHelp", meeting.service.title))
    }
}

/// The idle notch's reminder of what comes next: within ten minutes of an event, a dot in its calendar's color and the
/// minutes until it starts ("8m"), with the event as its tooltip. Nothing otherwise.
struct NextEventBadge: View {
    let events: [CalEvent]

    /// How long before an event the badge appears.
    static let window: TimeInterval = 10 * 60

    static func next(_ events: [CalEvent], now: Date) -> CalEvent? {
        events
            .filter { !$0.allDay && $0.busy && $0.start > now && $0.start.timeIntervalSince(now) <= window }
            .min { $0.start < $1.start }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if let event = Self.next(events, now: context.date) {
                let minutes = max(Int((event.start.timeIntervalSince(context.date) / 60).rounded(.up)), 1)
                let line = tr("call.soon", event.title, minutes)
                HStack(spacing: NookTheme.Spacing.xs) {
                    Circle()
                        .fill(NookPalette.eventColor(hex: event.colorHex, calendar: event.calendar))
                        .frame(width: 6, height: 6)
                    Text(tr("notch.minutesShort", minutes))
                        .font(NookTheme.TextStyle.caption)
                        .monospacedDigit()
                        .foregroundStyle(NookTheme.textStrong)
                        .fixedSize()
                }
                .help(line)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(line)
            }
        }
    }
}
