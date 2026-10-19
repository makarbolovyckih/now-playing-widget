import SwiftUI
import MediaPlayer
import WidgetKit

@main
struct NowPlayingApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @State private var now = NowPlaying.current()

    var body: some View {
        VStack(spacing: 12) {
            if let a = now.art {
                Image(uiImage: a).resizable().scaledToFit().frame(width: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            Text(now.title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(now.artist).foregroundStyle(.secondary)
            Text("Keep this app open for instant widget updates.").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding()
        .task {
            MPMediaLibrary.requestAuthorization { _ in refresh() }
            MPMusicPlayerController.systemMusicPlayer.beginGeneratingPlaybackNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange)) { _ in refresh() }
    }

    func refresh() {
        DispatchQueue.main.async {
            now = NowPlaying.current()
            NowPlaying.save(now)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
