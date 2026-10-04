import AppKit
import SwiftUI
import SwayblesCore

/// Swaybles Studio: your 90 days, which charms hang, and how they look.
struct StudioView: View {
    let model: AppModel

    var body: some View {
        TabView {
            NinetyTab(model: model).tabItem { Label("My 90 days", systemImage: "calendar") }
            CharmsTab(model: model).tabItem { Label("Charms", systemImage: "sparkles") }
            LookTab(model: model).tabItem { Label("Look & feel", systemImage: "paintbrush") }
            AboutTab().tabItem { Label("About", systemImage: "heart") }
        }
        .padding(20)
        .frame(width: 560, height: 500)
    }
}

// MARK: - My 90 days

private struct NinetyTab: View {
    let model: AppModel
    @State private var goal = ""

    var body: some View {
        Form {
            Section {
                TextField("One thing for your 90 days", text: $goal, prompt: Text("e.g. finish my portfolio"))
                    .onSubmit(save)
                    .onAppear { goal = model.settings.ninety?.goal ?? "" }
                if let n = model.settings.ninety {
                    LabeledContent("Today", value: n.bannerText(on: model.now))
                    DatePicker("Started", selection: Binding(
                        get: { n.start },
                        set: { d in model.update { $0.ninety?.start = d } }),
                        in: ...Date(), displayedComponents: .date)
                    HStack {
                        Button("Save goal", action: save)
                        Spacer()
                        Button("Start a fresh 90") { model.startNinety(goal: goal) }
                    }
                } else {
                    Button("Start my 90 days") { model.startNinety(goal: goal) }
                        .buttonStyle(.borderedProminent)
                }
                Toggle("Show days left in the year instead", isOn: model.binding(\.showYearCountdown))
            } header: {
                Text("Make the most of the next 90 days")
            } footer: {
                Text("The counter is a calendar, not a streak. Days away never reset anything.")
                    .foregroundStyle(.secondary)
            }

            Section("Focus") {
                Picker("Session length", selection: model.binding(\.focusMinutes)) {
                    ForEach(FocusClock.presets, id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.segmented)
                Stepper("Charms doze after \(model.settings.idleMinutes) min away",
                        value: model.binding(\.idleMinutes), in: 2...30)
                LabeledContent("Focus wins",
                               value: "\(model.settings.wins.thisWeek(on: model.now)) this week · \(model.settings.wins.total) in total")
            }
        }
        .formStyle(.grouped)
    }

    private func save() {
        model.setGoal(goal.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

// MARK: - Charms

private struct CharmsTab: View {
    let model: AppModel
    @State private var photoTrouble = false
    @State private var photoToRemove: Charm?
    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tap a charm to hang it or take it down (up to 8).")
                    .foregroundStyle(.secondary)
                ForEach(model.catalog.packs) { pack in
                    Text(pack.name).font(.headline)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(pack.charms) { charm in
                            CharmTile(model: model, charm: charm)
                        }
                    }
                }
                if model.catalog.charms.isEmpty {
                    Text("No charms found. Run `npm run charms` in the repo, then relaunch.")
                }

                Text("My photos").font(.headline)
                if !model.photos.charms.isEmpty {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(model.photos.charms) { charm in
                            CharmTile(model: model, charm: charm)
                                .overlay(alignment: .topTrailing) {
                                    Button { photoToRemove = charm } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .gray)
                                            .padding(4)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove this photo")
                                    .accessibilityLabel("Remove \(charm.name)")
                                }
                                .contextMenu {
                                    Button("Remove from Swaybles…", role: .destructive) { photoToRemove = charm }
                                }
                        }
                    }
                }
                Button("Add a photo…", action: pickPhoto)
                Text("Your photo stays on this Mac — Swaybles frames a copy and hangs it. Tap the × on a photo to remove it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(4)
        }
        .confirmationDialog("Remove this photo?", isPresented: Binding(
            get: { photoToRemove != nil }, set: { if !$0 { photoToRemove = nil } }), presenting: photoToRemove) { charm in
            Button("Remove \(charm.name)", role: .destructive) { model.removePhoto(charm.id) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This deletes Swaybles' framed copy. The original picture isn't touched.")
        }
        .alert("That picture couldn't be read — a JPG, PNG or HEIC works best.", isPresented: $photoTrouble) {
            Button("OK") {}
        }
    }

    private func pickPhoto() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if !model.addPhoto(from: url) { photoTrouble = true }
    }
}

private struct CharmTile: View {
    let model: AppModel
    let charm: Charm

    var body: some View {
        let on = model.isOnScreen(charm.id)
        Button { model.toggle(charm.id) } label: {
            VStack(spacing: 4) {
                if let img = Thumbnails.shared.image(for: charm, in: model) {
                    Image(nsImage: img).resizable().scaledToFit().frame(height: 72)
                }
                Text(charm.name).font(.caption).lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(on ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

/// Charm images for the Studio, loaded from disk once.
private final class Thumbnails {
    static let shared = Thumbnails()
    private var cache: [String: NSImage] = [:]
    func image(for charm: Charm, in model: AppModel) -> NSImage? {
        if let i = cache[charm.id] { return i }
        let i = NSImage(contentsOf: model.imageURL(for: charm))
        cache[charm.id] = i
        return i
    }
}

// MARK: - Look & feel

private struct LookTab: View {
    let model: AppModel

    var body: some View {
        Form {
            Picker("Rope", selection: model.binding(\.rope)) {
                ForEach(RopeStyle.allCases) { Text($0.name).tag($0) }
            }
            Slider(value: model.binding(\.size), in: 0.6...1.6) { Text("Charm size") }
            Toggle("Gentle breeze", isOn: model.binding(\.breeze))
            Toggle("Sounds", isOn: model.binding(\.sound))
            Toggle("Calmer swinging", isOn: model.binding(\.calmer))
            Toggle("Hold still (no swinging)", isOn: model.binding(\.still))
            Text("Swaybles also follows System Settings → Accessibility → Display → Reduce motion.")
                .font(.caption).foregroundStyle(.secondary)
            if !model.settings.charms.isEmpty {
                Section("Rope lengths") {
                    ForEach(model.settings.charms) { placed in
                        Slider(value: Binding(
                            get: { placed.length },
                            set: { v in model.update { s in
                                if let i = s.charms.firstIndex(where: { $0.uid == placed.uid }) { s.charms[i].length = v.rounded() }
                            } }), in: 60...320) {
                            Text(model.charm(placed.charmID)?.name ?? placed.charmID)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Swaybles").font(.largeTitle.bold())
            Text("Tiny charms that swing on your screen and cheer you on. Made for ADHD brains.")
                .multilineTextAlignment(.center)
            Text("Swaybles never reads your screen, windows or keystrokes, and never connects to the internet. "
                 + "It only knows the time, the timer you start, and whether the mouse and keyboard have been idle.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("Free and open source (MIT). Charm art made with Imagine Art.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(30)
    }
}
