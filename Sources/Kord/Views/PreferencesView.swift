import SwiftUI

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
        .frame(width: 450, height: 300)
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

private struct DictionaryTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showFilePicker = false

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
                }

                Text("JSON file mapping words to shortcuts. Changes are detected automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                Text("Format Example:")
                    .font(.subheadline)
                Text("""
                    {
                      "timing_window_ms": 70,
                      "words": {
                        "problem": "prb",
                        "with": "wh",
                        "transaction": "txn"
                      }
                    }
                    """)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(4)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            onCompletion: { result in
                if case .success(let url) = result {
                    settings.dictionaryPath = url.path
                }
            }
        )
    }
}
