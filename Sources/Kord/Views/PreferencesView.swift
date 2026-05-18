import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            DictionaryTab()
                .tabItem { Label("Dictionary", systemImage: "book") }
            ChordTesterView()
                .tabItem { Label("Chord Tester", systemImage: "keyboard") }
        }
        .frame(width: 580, height: 560)
        .padding()
    }
}

private struct GeneralTab: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Toggle("Enable Kord", isOn: $settings.isEnabled)

            VStack(alignment: .leading) {
                Text("Timing Window: \(settings.timingWindowMs) ms")
                Slider(
                    value: Binding(
                        get: { Double(settings.timingWindowMs) },
                        set: { settings.timingWindowMs = Int($0) }
                    ),
                    in: 30...150,
                    step: 5
                )
                Text("How long after the first keydown new keys may join the chord.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GroupBox("Status") {
                HStack {
                    Circle()
                        .fill(appState.isAccessibilityGranted ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(appState.isAccessibilityGranted ? "Accessibility: Granted" : "Accessibility: Not Granted")
                }

                if !appState.isAccessibilityGranted {
                    Button("Request Access") {
                        _ = EventTapManager.checkAccessibility()
                    }
                }
            }
        }
        .padding()
    }
}

private struct EditableWordRow: Identifiable {
    let id: UUID
    var word: String
    var shortcut: String

    init(id: UUID = UUID(), word: String = "", shortcut: String = "") {
        self.id = id
        self.word = word
        self.shortcut = shortcut
    }
}

private struct DictionaryTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showFilePicker = false
    @State private var rows: [EditableWordRow] = []
    @State private var fileTimingMs: Int = 70
    @State private var search: String = ""
    @State private var loadError: String?
    @State private var saveError: String?

    private var visibleRowIDs: [UUID] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return rows.map(\.id)
        }
        return rows
            .filter {
                $0.word.localizedCaseInsensitiveContains(query)
                    || $0.shortcut.localizedCaseInsensitiveContains(query)
            }
            .map(\.id)
    }

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dictionary File")
                    .font(.headline)

                HStack {
                    TextField("Path", text: $settings.dictionaryPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        showFilePicker = true
                    }
                    Button("Reload") {
                        loadFromDisk()
                        if loadError == nil {
                            settings.requestEngineDictionaryReloadFromDisk()
                        }
                    }
                }

                Text("Edit entries below. Save writes JSON to this path; the engine reloads automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let loadError {
                    Text(loadError)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Divider()

                HStack {
                    TextField("Search words or shortcuts", text: $search)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        let word = search.trimmingCharacters(in: .whitespacesAndNewlines)
                        rows.insert(EditableWordRow(word: word), at: 0)
                    } label: {
                        Label("Add Entry", systemImage: "plus.circle.fill")
                    }
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(visibleRowIDs, id: \.self) { id in
                            if let idx = rows.firstIndex(where: { $0.id == id }) {
                                HStack(alignment: .firstTextBaseline) {
                                    TextField("Word", text: $rows[idx].word)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("Shortcut", text: $rows[idx].shortcut)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(maxWidth: 160)
                                    Button {
                                        rows.remove(at: idx)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Remove entry")
                                }
                            }
                        }
                    }
                }
                .frame(minHeight: 220)

                HStack {
                    Spacer()

                    if let saveError {
                        Text(saveError)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }

                    Button("Save") {
                        persist()
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                }
            }
        }
        .padding()
        .onAppear { loadFromDisk() }
        .onChange(of: settings.dictionaryPath) { _, _ in
            loadFromDisk()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json, .yaml],
            onCompletion: { result in
                if case .success(let url) = result {
                    settings.dictionaryPath = url.path
                }
            }
        )
    }

    private func loadFromDisk() {
        saveError = nil
        let resolved = ((settings.dictionaryPath as NSString).expandingTildeInPath as NSString).standardizingPath
        do {
            if FileManager.default.fileExists(atPath: resolved) {
                let loaded = try DictionaryDiskIO.load(path: settings.dictionaryPath)
                fileTimingMs = loaded.timingWindowMs
                rows = loaded.entries.map { EditableWordRow(word: $0.word, shortcut: $0.shortcut) }
            } else {
                fileTimingMs = settings.timingWindowMs
                rows = []
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
            rows = []
        }
    }

    private func persist() {
        saveError = nil
        do {
            try DictionaryDiskIO.save(
                path: settings.dictionaryPath,
                timingWindowMs: fileTimingMs,
                rows: rows.map { ($0.word, $0.shortcut) }
            )
            settings.requestEngineDictionaryReloadFromDisk()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
