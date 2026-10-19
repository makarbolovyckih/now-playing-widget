import WidgetKit
import SwiftUI
import AppIntents

// Fallback list used when app-to-widget sync isn't available: pick apps from a dropdown in Edit Widget.
struct AppChoice: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "App"
    static var defaultQuery = AppChoiceQuery()
    var id: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

struct AppChoiceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AppChoice] {
        identifiers.map { AppChoice(id: $0) }
    }
    func suggestedEntities() async throws -> [AppChoice] {
        Catalog.apps.map { AppChoice(id: $0.name) }
    }
}

struct LinksIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Apps"
    static var description = IntentDescription("Pick the apps to show.")

    @Parameter(title: "App 1") var a1: AppChoice?
    @Parameter(title: "App 2") var a2: AppChoice?
    @Parameter(title: "App 3") var a3: AppChoice?
    @Parameter(title: "App 4") var a4: AppChoice?
    @Parameter(title: "App 5") var a5: AppChoice?
    @Parameter(title: "App 6") var a6: AppChoice?
    @Parameter(title: "App 7") var a7: AppChoice?
    @Parameter(title: "App 8") var a8: AppChoice?
    @Parameter(title: "App 9") var a9: AppChoice?
    @Parameter(title: "App 10") var a10: AppChoice?
}

// System URLs (and https): OpenURLIntent. Other apps' custom schemes go through LaunchIntent instead.
@available(iOS 18.0, *)
struct OpenLinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open"
    @Parameter(title: "URL") var url: URL
    init() {}
    init(url: URL) { self.url = url }
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(url))
    }
}

struct LinkEntry: TimelineEntry {
    let date: Date
    let items: [LinkItem]
    var bg: String = "000000"
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LinkEntry {
        let sample = Catalog.apps.filter { Catalog.defaults.contains($0.name) }.map { LinkItem(name: $0.name, url: $0.url) }
        return LinkEntry(date: .now, items: sample, bg: "000000")
    }
    func snapshot(for c: LinksIntent, in context: Context) async -> LinkEntry { entry(c) }
    func timeline(for c: LinksIntent, in context: Context) async -> Timeline<LinkEntry> {
        Timeline(entries: [entry(c)], policy: .never)
    }

    private func entry(_ c: LinksIntent) -> LinkEntry {
        var items = Store.load()   // list edited inside the app
        if items.isEmpty {
            let picks = [c.a1, c.a2, c.a3, c.a4, c.a5, c.a6, c.a7, c.a8, c.a9, c.a10]
                .compactMap { $0 }
                .compactMap { p in Catalog.apps.first { $0.name == p.id } }
            let apps = picks.isEmpty ? Catalog.apps.filter { Catalog.defaults.contains($0.name) } : picks
            items = apps.map { LinkItem(name: $0.name, url: $0.url) }
        }
        return LinkEntry(date: .now, items: items, bg: Store.bgHex)
    }
}

struct BlankWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: LinkEntry

    // default branch covers the iOS 27 extra-large portrait family
    var size: CGFloat {
        switch family {
        case .systemSmall: return 15
        case .systemMedium: return 18
        case .systemLarge: return 24
        default: return 30
        }
    }

    var body: some View {
        VStack(spacing: size * 0.7) {
            ForEach(entry.items) { item in tap(item) }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { Color(hex: entry.bg) }
    }

    @ViewBuilder func tap(_ item: LinkItem) -> some View {
        if let url = item.link {
            if !Catalog.isSystem(url) {
                Button(intent: LaunchIntent(url: url)) { label(item.name) }.buttonStyle(.plain)
            } else if #available(iOS 18, *) {
                Button(intent: OpenLinkIntent(url: url)) { label(item.name) }.buttonStyle(.plain)
            } else {
                Link(destination: url) { label(item.name) }
            }
        } else {
            label(item.name)
        }
    }

    func label(_ s: String) -> some View {
        Text(s)
            .font(.system(size: size, weight: .light))
            .foregroundStyle(hexLuminance(entry.bg) > 0.5 ? Color.black : Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

struct BlankWidget: Widget {
    static var families: [WidgetFamily] {
        var f: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        if #available(iOS 27, *) { f.append(.systemExtraLargePortrait) }
        return f
    }

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "BlankWidget", intent: LinksIntent.self, provider: Provider()) {
            BlankWidgetView(entry: $0)
        }
        .configurationDisplayName("Blank")
        .description("Text-only app launcher.")
        .supportedFamilies(Self.families)
    }
}

// A separate widget that ONLY offers the iOS 27 4x6 size, so it gets its own entry in the widget gallery.
@available(iOS 27.0, *)
struct BlankXLWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "BlankXLOnly", intent: LinksIntent.self, provider: Provider()) {
            BlankWidgetView(entry: $0)
        }
        .configurationDisplayName("Blank XL")
        .description("Full-page 4x6 text launcher.")
        .supportedFamilies([.systemExtraLargePortrait])
    }
}

@main
struct BlankWidgetBundle: WidgetBundle {
    var body: some Widget {
        BlankWidget()
        if #available(iOS 27, *) { BlankXLWidget() }
    }
}
