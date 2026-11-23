import Foundation

/// The video call an event links to (Google Meet, Zoom, Teams, Webex, Whereby, FaceTime), found in its URL, location or
/// notes, so "Your day" can offer to join it with one click. Foundation only, so it is tested anywhere.
struct MeetingLink: Equatable, Sendable {
    enum Service: String, Equatable, Sendable, CaseIterable {
        case meet, zoom, teams, webex, whereby, facetime

        /// The name on the button ("Join Zoom").
        var title: String {
            switch self {
            case .meet: return "Google Meet"
            case .zoom: return "Zoom"
            case .teams: return "Teams"
            case .webex: return "Webex"
            case .whereby: return "Whereby"
            case .facetime: return "FaceTime"
            }
        }

        /// Whether `host` belongs to this service.
        func matches(host: String) -> Bool {
            let host = host.lowercased()
            func on(_ domain: String) -> Bool { host == domain || host.hasSuffix("." + domain) }
            switch self {
            case .meet: return host == "meet.google.com"
            case .zoom: return on("zoom.us") || on("zoomgov.com")
            case .teams: return host == "teams.microsoft.com" || host == "teams.live.com" || host == "teams.cloud.microsoft"
            case .webex: return on("webex.com")
            case .whereby: return on("whereby.com")
            case .facetime: return host == "facetime.apple.com"
            }
        }
    }

    let service: Service
    let url: URL

    /// The first video call link in `texts` (an event's URL first, then its location, then its notes); nil when none.
    static func find(in texts: [String?]) -> MeetingLink? {
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            for url in links(in: text) {
                guard let host = url.host, let service = Service.allCases.first(where: { $0.matches(host: host) }) else { continue }
                // A Zoom or Meet home page is no call: it needs a path to a meeting.
                if url.path.count <= 1 { continue }
                return MeetingLink(service: service, url: url)
            }
        }
        return nil
    }

    /// Every http(s) address in `text`, in the order they appear, without the punctuation that ends a sentence. A plain
    /// pattern rather than `NSDataDetector`, which the Linux Foundation the core tests run on does not have.
    private static func links(in text: String) -> [URL] {
        guard let pattern = try? NSRegularExpression(pattern: #"https?://[^\s<>"'()\[\]]+"#, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return pattern.matches(in: text, options: [], range: range).compactMap { match in
            guard let found = Range(match.range, in: text) else { return nil }
            var link = String(text[found])
            while let last = link.last, ".,;:!?".contains(last) { link.removeLast() }
            return URL(string: link)
        }
    }
}
