import SwiftUI

/// The colors Nook borrows from the world around it, named once here so views never write a hex of their own:
/// each chat app's skin (so a WhatsApp chat reads green and a Telegram chat blue at a glance), the colors people get in
/// a chat, and the colors of calendar events that bring none of their own.
///
/// Only the accent of each app is taken from the app; the bubbles, the wallpaper and the layout stay Nook's own, so a
/// chat feels familiar without imitating the app. Everything here is for the dark surfaces Nook draws on.
enum NookPalette {
    /// Settings › Appearance › "App colors": each chat app in its own colors. Off, every chat uses Nook's neutral look.
    /// Kept in sync by `AppSettings.appColors`, as `NookTheme.accentHex` is.
    static var appColorsEnabled = true

    /// The colors people's initials and names get in a chat: bright enough to tell eight people apart on the dark canvas,
    /// soft enough to sit beside text.
    static let people: [Color] = [
        Color(hex: 0x6CC3F5), Color(hex: 0xF59E6C), Color(hex: 0xB48CF2), Color(hex: 0x7ED69B),
        Color(hex: 0xF27AA6), Color(hex: 0xF2CF66), Color(hex: 0x5FD0C4), Color(hex: 0x8C9EF2),
    ]

    /// Calendar events whose calendar brings no color (an ICS feed, Cal.com), in the order calendars are met.
    static let events: [Color] = [
        Color(hex: 0x7C9CF5), Color(hex: 0x5ED6A6), Color(hex: 0xF2A65A), Color(hex: 0xE57AA8),
        Color(hex: 0xA48CF2), Color(hex: 0x5CC8E8), Color(hex: 0xE5C95C), Color(hex: 0xEF7B73),
    ]

    /// A stable color for a name (a calendar, a person) out of `palette`.
    static func color(for name: String, in palette: [Color]) -> Color {
        guard !palette.isEmpty else { return NookTheme.textSecondary }
        // FNV-1a: the same name gets the same color on every launch (Swift's own hash is seeded per run).
        var hash: UInt32 = 2_166_136_261
        for byte in name.lowercased().utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return palette[Int(hash % UInt32(palette.count))]
    }

    /// The color of an event's calendar: its own when the calendar has one, else one from `events` by its name.
    static func eventColor(hex: UInt32?, calendar: String) -> Color {
        if let hex { return Color(hex: hex) }
        return color(for: calendar, in: events)
    }
}

/// How a chat from one app looks in Nook: its accent (the badge with what is new, the send button, the app's mark in
/// the header), the fill of your own bubbles and theirs, a faint wash behind the messages, and the color of "read".
struct ChatSkin: Equatable {
    let id: String
    /// The app's own color.
    let accent: Color
    /// Text and symbols on an `accent` fill.
    let onAccent: Color
    /// Your own message.
    let mine: Color
    /// Their message.
    let theirs: Color
    /// The faint color that washes in from the top of the chat; clear for none.
    let wallpaper: Color
    /// Two ticks once a message is read.
    let readTick: Color

    /// Nook's own look: what every chat has with "App colors" off, and what an app Nook has no colors for gets.
    static let nook = ChatSkin(id: "nook", accent: NookTheme.mint, onAccent: NookTheme.ink,
                               mine: NookTheme.mint.opacity(0.13), theirs: NookTheme.smoke,
                               wallpaper: .clear, readTick: NookTheme.blue)

    /// The skin of an app by its source id ("whatsapp"); `.nook` for one without colors or with "App colors" off.
    static func of(_ app: String) -> ChatSkin {
        guard NookPalette.appColorsEnabled else { return .nook }
        return skins[app.lowercased()] ?? .nook
    }

    /// Whether `app` has colors of its own (Settings shows these as swatches).
    static func hasOwn(_ app: String) -> Bool { skins[app.lowercased()] != nil }

    private static func skin(_ id: String, accent: UInt32, mine: UInt32, theirs: UInt32 = 0x232628,
                             wallpaper: UInt32? = nil, read: UInt32 = 0x6CC3F5, darkText: Bool = false) -> ChatSkin {
        ChatSkin(id: id, accent: Color(hex: accent), onAccent: darkText ? NookTheme.ink : .white,
                 mine: Color(hex: mine), theirs: Color(hex: theirs),
                 wallpaper: Color(hex: wallpaper ?? accent, opacity: 0.07), readTick: Color(hex: read))
    }

    private static let skins: [String: ChatSkin] = {
        let all = [
            skin("whatsapp", accent: 0x25D366, mine: 0x0F5A44, theirs: 0x1E2A30, wallpaper: 0x1F8F5F, read: 0x53BDEB, darkText: true),
            skin("telegram", accent: 0x2AABEE, mine: 0x2A5179, theirs: 0x1D2835),
            skin("messages", accent: 0x0A84FF, mine: 0x1667E0, theirs: 0x2A2A2D, read: 0xD6D6D6),
            skin("messenger", accent: 0x3D7BFF, mine: 0x5446E0, theirs: 0x2B2B2E, wallpaper: 0x7A5CFF),
            skin("instagram", accent: 0xE4407A, mine: 0x6D3BD6, theirs: 0x262628, wallpaper: 0xC13584),
            skin("signal", accent: 0x3A76F0, mine: 0x2B57BF, theirs: 0x28292D),
            skin("slack", accent: 0xC77DD1, mine: 0x40214A, theirs: 0x222529, wallpaper: 0x611F69),
            skin("discord", accent: 0x5865F2, mine: 0x3A43A3, theirs: 0x2B2D31),
            skin("teams", accent: 0x7B83EB, mine: 0x41458C, theirs: 0x292A30),
            skin("googlechat", accent: 0x1EA362, mine: 0x15573A, theirs: 0x26292B),
            skin("snapchat", accent: 0xFFFC00, mine: 0x46420F, theirs: 0x26262A, wallpaper: 0xBFB800, darkText: true),
            skin("viber", accent: 0x7360F2, mine: 0x45399B, theirs: 0x28272E),
            skin("wechat", accent: 0x07C160, mine: 0x1B6B40, theirs: 0x262826, darkText: true),
            skin("line", accent: 0x06C755, mine: 0x1A6B3B, theirs: 0x25282A, darkText: true),
            skin("skype", accent: 0x00AFF0, mine: 0x0F5B80, theirs: 0x25292D),
            skin("element", accent: 0x0DBD8B, mine: 0x10604A, theirs: 0x24292A, darkText: true),
            skin("threema", accent: 0x05A63F, mine: 0x1D5A33, theirs: 0x25292A),
            skin("wire", accent: 0x2D8CF0, mine: 0x194A85, theirs: 0x25282D),
            skin("linkedin", accent: 0x3A8DDE, mine: 0x0D4C8A, theirs: 0x26292D),
            skin("x", accent: 0x1D9BF0, mine: 0x1A5F9E, theirs: 0x24272B),
        ]
        return Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()
}
