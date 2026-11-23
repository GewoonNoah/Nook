import SwiftUI
import AppKit

// The ten cards of the Tools tab (`ToolsTab`). Each keeps its own small state; what lasts lives in `ToolsStore` and the
// services in `Services/Tools/ToolsStore.swift`.

// MARK: 1. Converter

/// "5 km to mi": the answer as you type, offline.
struct ConverterCard: View {
    @State private var query = ""

    private var result: UnitConversion.Result? { UnitConversion.convert(query) }

    var body: some View {
        ToolCard(tr("tools.converter.title"), symbol: "arrow.left.arrow.right", tint: ToolTint.converter) {
            ToolField(prompt: tr("tools.converter.prompt"), text: $query) {
                if let result { copyWithToast(result.text) }
            }
            HStack(alignment: .firstTextBaseline) {
                Text(result?.text ?? (query.isEmpty ? tr("tools.converter.examples") : tr("tools.converter.unknown")))
                    .font(result == nil ? NookTheme.TextStyle.detail : NookTheme.rounded(20, .semibold))
                    .foregroundStyle(result == nil ? NookTheme.textTertiary : ToolTint.converter)
                    .textSelection(.enabled)
                    .lineLimit(2)
                Spacer(minLength: NookTheme.Spacing.sm)
                if let result {
                    ToolbarIconButton("doc.on.doc", tr("tools.copy")) { copyWithToast(result.text) }
                }
            }
        }
    }
}

// MARK: 2. Kitchen timers

/// Several timers at once: a name, a length, and each one counting down with a ring.
struct TimersCard: View {
    @ObservedObject private var timers = NookTimers.shared
    @State private var title = ""

    var body: some View {
        ToolCard(tr("tools.timers.title"), symbol: "timer", tint: ToolTint.timers) {
            ToolField(prompt: tr("tools.timers.prompt"), text: $title)
            HStack(spacing: NookTheme.Spacing.xs) {
                ForEach(NookTimers.presets, id: \.self) { minutes in
                    ToolChip(title: tr("focus.minutes", minutes), tint: ToolTint.timers) {
                        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        timers.start(minutes: minutes, title: name.isEmpty ? tr("tools.timers.default") : name)
                        title = ""
                    }
                }
            }
            if !timers.running.isEmpty {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: NookTheme.Spacing.sm) {
                        ForEach(timers.running) { timer in
                            HStack(spacing: NookTheme.Spacing.md) {
                                ProgressRing(progress: timer.session.progress(at: context.date), tint: ToolTint.timers)
                                    .frame(width: 20, height: 20)
                                Text(timer.title)
                                    .font(NookTheme.TextStyle.strong)
                                    .foregroundStyle(NookTheme.paper)
                                    .lineLimit(1)
                                Spacer(minLength: NookTheme.Spacing.sm)
                                Text(FocusSession.clock(timer.session.remaining(at: context.date)))
                                    .font(NookTheme.rounded(14, .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(ToolTint.timers)
                                ToolbarIconButton("xmark", tr("tools.timers.stop")) { timers.stop(timer.id) }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// A thin ring that fills with `progress`, in a tool's color.
struct ProgressRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle().stroke(NookTheme.smoke, lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}

// MARK: 3. World clock

struct WorldClockCard: View {
    @ObservedObject private var store = ToolsStore.shared

    private var language: String { I18n.shared.currentLanguage.rawValue }

    var body: some View {
        ToolCard(tr("tools.clock.title"), symbol: "globe", tint: ToolTint.clock, accessory: {
            Menu {
                ForEach(WorldCity.suggestions.filter { !store.cities.contains($0) }) { city in
                    Button(city.name) { store.cities.append(city) }
                }
            } label: {
                Image(systemName: "plus")
                    .font(NookTheme.font(11, .semibold))
                    .foregroundStyle(NookTheme.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .composerMenu()
            .help(tr("tools.clock.add"))
            .accessibilityLabel(tr("tools.clock.add"))
        }) {
            if store.cities.isEmpty {
                ListEmptyNote(tr("tools.clock.empty"))
            } else {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    VStack(spacing: NookTheme.Spacing.sm) {
                        ForEach(store.cities) { city in
                            row(city, now: context.date)
                                .contextMenu {
                                    Button(tr("tools.remove"), role: .destructive) { store.cities.removeAll { $0 == city } }
                                }
                        }
                    }
                }
            }
        }
    }

    private func row(_ city: WorldCity, now: Date) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: language)
        formatter.timeZone = city.timeZone
        let day = city.isDaytime(at: now)
        return HStack(spacing: NookTheme.Spacing.md) {
            Image(systemName: day ? "sun.max.fill" : "moon.fill")
                .font(NookTheme.font(11, .medium))
                .foregroundStyle(day ? NookTheme.amber : NookTheme.blue)
                .frame(width: 16)
            Text(city.name)
                .font(NookTheme.TextStyle.strong)
                .foregroundStyle(NookTheme.paper)
                .lineLimit(1)
            Text(city.offset(from: .current, at: now))
                .font(NookTheme.TextStyle.caption)
                .foregroundStyle(NookTheme.textTertiary)
            Spacer(minLength: NookTheme.Spacing.sm)
            Text(formatter.string(from: now))
                .font(NookTheme.rounded(15, .semibold))
                .monospacedDigit()
                .foregroundStyle(NookTheme.textStrong)
        }
    }
}

// MARK: 4. Countdowns

struct CountdownsCard: View {
    @ObservedObject private var store = ToolsStore.shared
    @State private var title = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    var body: some View {
        ToolCard(tr("tools.countdowns.title"), symbol: "hourglass", tint: ToolTint.countdowns) {
            ForEach(store.countdowns.sorted { $0.date < $1.date }) { countdown in
                let left = countdown.daysLeft(at: Date())
                HStack(spacing: NookTheme.Spacing.md) {
                    Circle()
                        .fill(NookPalette.color(for: countdown.title, in: NookPalette.events))
                        .frame(width: 8, height: 8)
                    Text(countdown.title)
                        .font(NookTheme.TextStyle.strong)
                        .foregroundStyle(NookTheme.paper)
                        .lineLimit(1)
                    Spacer(minLength: NookTheme.Spacing.sm)
                    Text(left == 0 ? tr("tools.countdowns.today")
                         : left > 0 ? tr("tools.countdowns.days", left) : tr("tools.countdowns.ago", -left))
                        .font(NookTheme.TextStyle.label)
                        .monospacedDigit()
                        .foregroundStyle(left >= 0 ? ToolTint.countdowns : NookTheme.textTertiary)
                }
                .contextMenu {
                    Button(tr("tools.remove"), role: .destructive) { store.countdowns.removeAll { $0.id == countdown.id } }
                }
            }
            HStack(spacing: NookTheme.Spacing.sm) {
                ToolField(prompt: tr("tools.countdowns.prompt"), text: $title, onSubmit: add)
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .fixedSize()
                ToolbarIconButton("plus", tr("tools.countdowns.add"), enabled: !title.trimmingCharacters(in: .whitespaces).isEmpty,
                                  add)
            }
        }
    }

    private func add() {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        store.countdowns.append(Countdown(title: name, date: date))
        title = ""
    }
}

// MARK: 5. Habits

struct HabitsCard: View {
    @ObservedObject private var store = ToolsStore.shared
    @State private var title = ""

    var body: some View {
        ToolCard(tr("tools.habits.title"), symbol: "checkmark.seal.fill", tint: ToolTint.habits) {
            ForEach(store.habits) { habit in
                HabitRow(habit: habit) { toggle(habit) }
                    .contextMenu {
                        Button(tr("tools.remove"), role: .destructive) { store.habits.removeAll { $0.id == habit.id } }
                    }
            }
            ToolField(prompt: tr("tools.habits.prompt"), text: $title) {
                let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                store.habits.append(Habit(title: name))
                title = ""
            }
        }
    }

    private func toggle(_ habit: Habit) {
        guard let index = store.habits.firstIndex(where: { $0.id == habit.id }) else { return }
        withAnimation(NookTheme.hover) { store.habits[index].toggle(on: Date()) }
    }
}

private struct HabitRow: View {
    let habit: Habit
    let toggle: () -> Void

    var body: some View {
        let now = Date()
        let done = habit.isDone(on: now)
        let streak = habit.streak(at: now)
        HStack(spacing: NookTheme.Spacing.md) {
            Button(action: toggle) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(NookTheme.font(16, .medium))
                    .foregroundStyle(done ? ToolTint.habits : NookTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(habit.title)
            .accessibilityAddTraits(done ? .isSelected : [])
            Text(habit.title)
                .font(NookTheme.TextStyle.strong)
                .foregroundStyle(done ? NookTheme.paper : NookTheme.textStrong)
                .lineLimit(1)
            Spacer(minLength: NookTheme.Spacing.sm)
            // The last week as dots, today last.
            HStack(spacing: NookTheme.Spacing.xxs) {
                ForEach(Array(habit.lastDays(7, at: now).enumerated()), id: \.offset) { _, day in
                    Circle()
                        .fill(day ? ToolTint.habits : NookTheme.smoke)
                        .frame(width: 5, height: 5)
                }
            }
            .accessibilityHidden(true)
            if streak > 0 {
                HStack(spacing: NookTheme.Spacing.xxs) {
                    Image(systemName: "flame.fill").font(NookTheme.font(10, .semibold))
                    Text("\(streak)").font(NookTheme.rounded(12, .semibold)).monospacedDigit()
                }
                .foregroundStyle(NookTheme.music)
                .help(tr("tools.habits.streak", streak))
                .accessibilityLabel(tr("tools.habits.streak", streak))
            }
        }
    }
}

// MARK: 6. Scratch note

struct NoteCard: View {
    @ObservedObject private var store = ToolsStore.shared

    var body: some View {
        ToolCard(tr("tools.note.title"), symbol: "note.text", tint: ToolTint.note, accessory: {
            HStack(spacing: NookTheme.Spacing.xxs) {
                ToolbarIconButton("doc.on.doc", tr("tools.copy"), enabled: !store.note.isEmpty) { copyWithToast(store.note) }
                ToolbarIconButton("trash", tr("tools.note.clear"), enabled: !store.note.isEmpty) { store.note = "" }
            }
        }) {
            ZStack(alignment: .topLeading) {
                if store.note.isEmpty {
                    Text(tr("tools.note.prompt"))
                        .font(NookTheme.TextStyle.body)
                        .foregroundStyle(NookTheme.textTertiary)
                        .padding(.horizontal, NookTheme.Spacing.xs + 1)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $store.note)
                    .font(NookTheme.TextStyle.body)
                    .foregroundStyle(NookTheme.paper)
                    .scrollContentBackground(.hidden)
            }
            .frame(height: 110)
            .padding(NookTheme.Spacing.sm)
            .background(RoundedRectangle(cornerRadius: NookTheme.Radius.control, style: .continuous).fill(NookTheme.well))
        }
    }
}

// MARK: 7. Clipboard history

struct ClipboardCard: View {
    @ObservedObject private var history = ClipboardHistory.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ToolCard(tr("tools.clipboard.title"), symbol: "doc.on.clipboard", tint: ToolTint.clipboard, accessory: {
            ToolbarIconButton("trash", tr("tools.clipboard.clear"), enabled: !history.items.isEmpty) { history.clear() }
        }) {
            if !settings.clipboardHistory {
                ListEmptyNote(tr("tools.clipboard.off"))
            } else if history.items.isEmpty {
                ListEmptyNote(tr("tools.clipboard.empty"))
            } else {
                VStack(spacing: NookTheme.Spacing.xxs) {
                    ForEach(history.items.prefix(6), id: \.self) { text in
                        ClipboardRow(text: text) { history.copy(text); ToastCenter.shared.success(tr("tools.copied")) }
                            .contextMenu {
                                Button(tr("tools.remove"), role: .destructive) { history.remove(text) }
                            }
                    }
                }
            }
        }
    }
}

private struct ClipboardRow: View {
    let text: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: NookTheme.Spacing.sm) {
                Text(text.replacingOccurrences(of: "\n", with: " ⏎ "))
                    .font(NookTheme.TextStyle.detail)
                    .foregroundStyle(hovering ? NookTheme.paper : NookTheme.textStrong)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: NookTheme.Spacing.xs)
                Image(systemName: "doc.on.doc")
                    .font(NookTheme.font(10, .medium))
                    .foregroundStyle(NookTheme.textTertiary)
                    .opacity(hovering ? 1 : 0)
            }
            .padding(.horizontal, NookTheme.Spacing.sm)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: NookTheme.Radius.chip, style: .continuous)
                .fill(hovering ? NookTheme.rowHover : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(tr("tools.clipboard.copyAgain"))
    }
}

// MARK: 8. Color picker

struct ColorPickerCard: View {
    @ObservedObject private var store = ToolsStore.shared

    var body: some View {
        ToolCard(tr("tools.colors.title"), symbol: "eyedropper.halffull", tint: ToolTint.colors) {
            HStack(spacing: NookTheme.Spacing.sm) {
                ToolChip(title: tr("tools.colors.pick"), tint: ToolTint.colors, selected: true, action: pick)
                Text(tr("tools.colors.hint"))
                    .font(NookTheme.TextStyle.detail)
                    .foregroundStyle(NookTheme.textTertiary)
                    .lineLimit(2)
            }
            if !store.colors.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: NookTheme.Spacing.xs), count: 6),
                          spacing: NookTheme.Spacing.xs) {
                    ForEach(store.colors, id: \.self) { hex in
                        Button { copyWithToast(hex) } label: {
                            VStack(spacing: NookTheme.Spacing.xxs) {
                                RoundedRectangle(cornerRadius: NookTheme.Radius.chip, style: .continuous)
                                    .fill(Color(hexString: hex) ?? NookTheme.smoke)
                                    .frame(height: 22)
                                Text(hex)
                                    .font(NookTheme.mono(9.5))
                                    .foregroundStyle(NookTheme.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .help(tr("tools.copy"))
                    }
                }
            }
        }
    }

    /// The system's magnifier over the screen; the color clicked is copied as "#RRGGBB" and kept.
    private func pick() {
        NSColorSampler().show { color in
            guard let color else { return }
            let hex = String(format: "#%06X", color.nookHex)
            Task { @MainActor in
                ToolsStore.shared.addColor(hex)
                copyWithToast(hex)
            }
        }
    }
}

// MARK: 9. Keep awake

struct AwakeCard: View {
    @ObservedObject private var awake = AwakeHold.shared

    private var status: String {
        guard let until = awake.until else { return tr("tools.awake.off") }
        if until == .distantFuture { return tr("tools.awake.untilStopped") }
        let time = NookDates.formatter("HH:mm", locale: I18n.shared.currentLanguage.rawValue).string(from: until)
        return tr("tools.awake.until", time)
    }

    var body: some View {
        ToolCard(tr("tools.awake.title"), symbol: awake.isOn ? "cup.and.saucer.fill" : "cup.and.saucer",
                 tint: ToolTint.awake) {
            Text(status)
                .font(NookTheme.TextStyle.detail)
                .foregroundStyle(awake.isOn ? ToolTint.awake : NookTheme.textSecondary)
            HStack(spacing: NookTheme.Spacing.xs) {
                ToolChip(title: tr("tools.awake.hours", 1), tint: ToolTint.awake) { awake.start(minutes: 60) }
                ToolChip(title: tr("tools.awake.hours", 3), tint: ToolTint.awake) { awake.start(minutes: 180) }
                ToolChip(title: tr("tools.awake.always"), tint: ToolTint.awake,
                         selected: awake.until == .distantFuture) { awake.start(minutes: nil) }
                if awake.isOn {
                    ToolChip(title: tr("tools.awake.stop"), tint: NookTheme.coral) { awake.stop() }
                }
            }
        }
    }
}

// MARK: 10. Battery

struct BatteryCard: View {
    @ObservedObject private var battery = BatteryWatch.shared

    private func tint(_ level: Int) -> Color {
        level <= 20 ? NookTheme.coral : (level <= 50 ? NookTheme.amber : NookTheme.mint)
    }

    var body: some View {
        ToolCard(tr("tools.battery.title"), symbol: battery.onPower ? "battery.100.bolt" : "battery.75",
                 tint: battery.level.map(tint) ?? NookTheme.mint) {
            if let level = battery.level {
                HStack(alignment: .firstTextBaseline, spacing: NookTheme.Spacing.sm) {
                    Text(verbatim: "\(level)%")
                        .font(NookTheme.rounded(22, .semibold))
                        .monospacedDigit()
                        .foregroundStyle(tint(level))
                    Text(battery.onPower ? tr("tools.battery.charging") : tr("tools.battery.onBattery"))
                        .font(NookTheme.TextStyle.detail)
                        .foregroundStyle(NookTheme.textSecondary)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(NookTheme.smoke)
                        Capsule()
                            .fill(LinearGradient(colors: [tint(level).opacity(0.7), tint(level)], startPoint: .leading,
                                                 endPoint: .trailing))
                            .frame(width: geometry.size.width * CGFloat(level) / 100)
                    }
                }
                .frame(height: 8)
                .accessibilityHidden(true)
            } else {
                ListEmptyNote(tr("tools.battery.none"))
            }
        }
    }
}

// MARK: Shared

/// Copies `text` and says so with a toast.
@MainActor
func copyWithToast(_ text: String) {
    Pasteboard.copy(text)
    ToastCenter.shared.success(tr("tools.copied"))
}
