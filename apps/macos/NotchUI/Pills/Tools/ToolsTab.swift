import SwiftUI

/// The Tools tab: small everyday helpers next to the notch, each a card of its own color in a two-column grid. A
/// converter, kitchen timers, the world clock, countdowns, habits, a scratch note, the clipboard history, a color picker
/// from the screen, keep awake and the battery. What they keep stays on this Mac (`ToolsStore`).
struct ToolsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelListHeader(tr("tab.tools")) { EmptyView() }
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: NookTheme.Spacing.md, alignment: .top),
                                    GridItem(.flexible(), spacing: NookTheme.Spacing.md, alignment: .top)],
                          alignment: .leading, spacing: NookTheme.Spacing.md) {
                    ConverterCard()
                    TimersCard()
                    WorldClockCard()
                    CountdownsCard()
                    HabitsCard()
                    NoteCard()
                    ClipboardCard()
                    ColorPickerCard()
                    AwakeCard()
                    BatteryCard()
                }
                .padding(.bottom, NookTheme.Spacing.lg)
            }
        }
        .padding(.horizontal, NookTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The frame every tool shares: its symbol on a tile of its color, its name, an optional action on the right, then
/// what it shows.
struct ToolCard<Content: View, Accessory: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: () -> Content

    init(_ title: String, symbol: String, tint: Color, @ViewBuilder accessory: @escaping () -> Accessory,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NookTheme.Spacing.md) {
            HStack(spacing: NookTheme.Spacing.md) {
                Image(systemName: symbol)
                    .font(NookTheme.font(12, .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: NookTheme.Radius.control, style: .continuous)
                        .fill(tint.opacity(0.15)))
                Text(title)
                    .font(NookTheme.TextStyle.title)
                    .foregroundStyle(NookTheme.paper)
                    .lineLimit(1)
                Spacer(minLength: NookTheme.Spacing.sm)
                accessory()
            }
            content()
        }
        .padding(NookTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .panelCard()
    }
}

extension ToolCard where Accessory == EmptyView {
    init(_ title: String, symbol: String, tint: Color, @ViewBuilder content: @escaping () -> Content) {
        self.init(title, symbol: symbol, tint: tint, accessory: { EmptyView() }, content: content)
    }
}

/// A small capsule button inside a tool: a preset, an action, or a chosen option in the tool's color.
struct ToolChip: View {
    let title: String
    var tint: Color = NookTheme.iris
    var selected = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NookTheme.TextStyle.label)
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(selected ? NookTheme.ink : (hovering ? NookTheme.paper : NookTheme.textStrong))
                .padding(.horizontal, NookTheme.Spacing.md)
                .frame(height: 24)
                .background(Capsule().fill(selected ? tint : (hovering ? tint.opacity(0.22) : NookTheme.smoke)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(NookTheme.hover, value: hovering)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The one-line text field the tools use: plain text on the field fill, with Return to submit.
struct ToolField: View {
    let prompt: String
    @Binding var text: String
    var onSubmit: () -> Void = {}

    var body: some View {
        TextField(prompt, text: $text)
            .textFieldStyle(.plain)
            .font(NookTheme.TextStyle.body)
            .foregroundStyle(NookTheme.paper)
            .padding(.horizontal, NookTheme.Spacing.md)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: NookTheme.Radius.control, style: .continuous).fill(NookTheme.well))
            .onSubmit(onSubmit)
    }
}

/// The tools' colors, one per tool, from the event palette so the grid reads as one set.
enum ToolTint {
    static var converter: Color { NookPalette.events[0] }
    static var timers: Color { NookPalette.events[2] }
    static var clock: Color { NookPalette.events[5] }
    static var countdowns: Color { NookPalette.events[3] }
    static var habits: Color { NookPalette.events[1] }
    static var note: Color { NookPalette.events[6] }
    static var clipboard: Color { NookPalette.events[4] }
    static var colors: Color { NookPalette.events[7] }
    static var awake: Color { NookTheme.amber }
}
