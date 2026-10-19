import WidgetKit
import SwiftUI

struct Entry: TimelineEntry { let date: Date; let now: Now }

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, now: Now(title: "Song Name", artist: "Artist")) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, now: NowPlaying.current()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // iOS decides the real refresh rate; this just asks for a minute.
        completion(Timeline(entries: [Entry(date: .now, now: NowPlaying.current())],
                            policy: .after(.now.addingTimeInterval(60))))
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) var family
    let now: Now

    var art: some View {
        Color.clear.aspectRatio(1, contentMode: .fit)
            .overlay {
                if let a = now.art { Image(uiImage: a).resizable().scaledToFill() }
                else { Color.white.opacity(0.15) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .frame(maxWidth: .infinity)
    }
    var title: some View {
        Text(now.title).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
    }
    var artist: some View {
        Text(now.artist).font(.system(size: 14, weight: .thin)).foregroundStyle(Color(white: 0.85)).lineLimit(1)
    }

    var body: some View {
        Group {
            if family == .systemMedium {
                HStack(spacing: 14) {
                    art
                    VStack(alignment: .leading, spacing: 2) { title; artist }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    art
                    title
                    artist
                }
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                Color.black
                if let a = now.art { Image(uiImage: a).resizable().scaledToFill().blur(radius: 40).opacity(0.45) }
            }
        }
    }
}

@main
struct NowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NowPlaying", provider: Provider()) { WidgetView(now: $0.now) }
            .configurationDisplayName("Now Playing")
            .description("Artwork, song and artist from Apple Music.")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}
