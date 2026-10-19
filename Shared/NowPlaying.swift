import MediaPlayer
import UIKit

struct Now {
    var title = "Nothing playing"
    var artist = ""
    var art: UIImage?
}

enum NowPlaying {
    static let group = "group.com.nowplaying.widget"
    static var dir: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) }

    // Straight from the Music player (works in the app; the widget tries it too).
    static func live() -> Now? {
        guard let i = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem else { return nil }
        return Now(title: i.title ?? "Unknown", artist: i.artist ?? "",
                   art: i.artwork?.image(at: CGSize(width: 600, height: 600)))
    }

    // App writes, widget reads: fallback when the widget can't read the player itself.
    static func save(_ n: Now) {
        guard let d = dir else { return }
        try? JSONEncoder().encode([n.title, n.artist]).write(to: d.appendingPathComponent("t.json"))
        let a = d.appendingPathComponent("a.jpg")
        if let j = n.art?.jpegData(compressionQuality: 0.8) { try? j.write(to: a) } else { try? FileManager.default.removeItem(at: a) }
    }

    static func saved() -> Now? {
        guard let d = dir,
              let data = try? Data(contentsOf: d.appendingPathComponent("t.json")),
              let t = try? JSONDecoder().decode([String].self, from: data), t.count == 2 else { return nil }
        return Now(title: t[0], artist: t[1], art: UIImage(contentsOfFile: d.appendingPathComponent("a.jpg").path))
    }

    static func current() -> Now { live() ?? saved() ?? Now() }
}
