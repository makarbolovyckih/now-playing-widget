import SwiftUI
import WidgetKit
import UIKit

struct ContentView: View {
    @State private var items = Store.load()
    @State private var adding = false
    @State private var bg = Color(hex: Store.bgHex)
    @State private var message: String?
    @ObservedObject private var launch = LaunchState.shared

    var xlSupported: String {
        if #available(iOS 27, *) { return "yes" } else { return "no (needs iOS 27)" }
    }

    var toolchain: String {
        #if compiler(>=6.4)
        return "Xcode 27 or newer"
        #else
        return "older than Xcode 27 (no 4x6 widget)"
        #endif
    }

    var body: some View {
        content.overlay { if launch.hiding { Color.black.ignoresSafeArea() } }
    }

    var content: some View {
        NavigationStack {
            List {
                Section {
                    if Store.available {
                        Text("Synced with the widget. Changes show up automatically.")
                    } else {
                        Text("Sync isn't available on this install. Edit the list by long-pressing the widget > Edit Widget instead.")
                    }
                }
                .font(.footnote)

                Section("Widget apps") {
                    if items.isEmpty { Text("Tap + to add an app.").foregroundStyle(.secondary) }
                    ForEach($items) { $item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                TextField("Label", text: $item.name)
                                Text(item.url).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Test") { test(item) }.buttonStyle(.borderless)
                        }
                    }
                    .onDelete { items.remove(atOffsets: $0) }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                }

                Section("Look") {
                    ColorPicker("Widget + wallpaper color", selection: $bg, supportsOpacity: false)
                    Button("Save matching wallpaper to Photos") { saveWallpaper() }
                    Text("Set that photo as your Home Screen wallpaper so the widgets blend in. Black is the default; if you still see an outline, try a very dark gray instead.")
                        .font(.footnote)
                }

                Section("Hide the dock and borders") {
                    Text("Apps can't change the dock or the glass borders; iOS draws them. These settings are what minimize them:")
                        .font(.footnote)
                    Text("1. Turn on Dark Mode.")
                    Text("2. Long-press the Home Screen > Edit > Customize: choose Default (not Clear or Tinted) and the Large icon size.")
                    Text("3. Settings > Accessibility > Motion > Reduce Motion on.")
                    Text("4. Use the wallpaper above for the Home Screen.")
                    Text("5. Drag the apps out of the dock so it's empty.")
                    Text("A faint outline where the dock was may remain; Apple makes it mandatory.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Debug") {
                    Text("iOS \(UIDevice.current.systemVersion)")
                    Text("Running on iOS 27: \(xlSupported)")
                    Text("Built with: \(toolchain)")
                }
            }
            .navigationTitle("Blank")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $adding) { AddView { items.append($0) } }
            .onAppear { refreshLinks() }
            .onChange(of: items) { save() }
            .onChange(of: bg) { save() }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    // Keeps saved entries pointing at the newest link for apps from the menu (matched by name).
    func refreshLinks() {
        var changed = items
        for i in changed.indices {
            if let c = Catalog.apps.first(where: { $0.name == changed[i].name }) { changed[i].url = c.url }
        }
        if changed != items { items = changed }
    }

    func save() {
        Store.save(items)
        Store.bgHex = hex(bg)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func hex(_ c: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    func test(_ item: LinkItem) {
        guard let url = item.link else { message = "Not a valid URL."; return }
        UIApplication.shared.open(url) { ok in
            if !ok { message = "iOS couldn't open \(item.url). The app may not be installed, or its URL scheme differs." }
        }
    }

    func saveWallpaper() {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        let size = CGSize(width: 1290, height: 2796)
        let img = UIGraphicsImageRenderer(size: size, format: f).image { ctx in
            UIColor(bg).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        message = "Saved to Photos (if you allowed access)."
    }
}

struct AddView: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (LinkItem) -> Void

    @State private var mode = 0
    @State private var app = Catalog.apps[0]
    @State private var label = ""
    @State private var shortcut = ""
    @State private var custom = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $mode) {
                    Text("App").tag(0)
                    Text("Shortcut").tag(1)
                    Text("URL").tag(2)
                }
                .pickerStyle(.segmented)

                if mode == 0 {
                    Picker("App", selection: $app) {
                        ForEach(Catalog.apps) { Text($0.shortcut ? "\($0.name) (via Shortcut)" : $0.name).tag($0) }
                    }
                    .pickerStyle(.menu)
                    if app.shortcut {
                        Text("Apple gives \(app.name) no plain 'open' link. In the Shortcuts app, make a shortcut named exactly \"\(app.name)\" with the 'Open App' action set to \(app.name). The widget runs it.")
                            .font(.footnote)
                    }
                } else if mode == 1 {
                    TextField("Shortcut name (exact)", text: $shortcut)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Works for ANY app, including Camera: in the Shortcuts app, make a shortcut with the 'Open App' action (it lists every app on your phone), name it, and type that name here.")
                        .font(.footnote)
                } else {
                    TextField("URL, e.g. myapp://", text: $custom)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                TextField("Label on widget (optional)", text: $label)
            }
            .navigationTitle("Add")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { add() }.disabled(!valid) }
            }
        }
    }

    var valid: Bool {
        switch mode {
        case 0: return true
        case 1: return !shortcut.trimmingCharacters(in: .whitespaces).isEmpty
        default: return !custom.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    func add() {
        let name: String, url: String
        switch mode {
        case 0: name = app.name; url = app.url
        case 1: name = shortcut; url = Catalog.shortcutURL(shortcut.trimmingCharacters(in: .whitespaces))
        default: name = custom; url = custom.trimmingCharacters(in: .whitespaces)
        }
        onAdd(LinkItem(name: label.isEmpty ? name : label, url: url))
        dismiss()
    }
}
