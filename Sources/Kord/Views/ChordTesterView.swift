import SwiftUI
import Combine

struct ChordTesterView: View {
    @EnvironmentObject var appState: AppState
    @State private var detectedChords: [ChordEntry] = []

    struct ChordEntry: Identifiable {
        let id = UUID()
        let keys: String
        let expansion: String?
        let timestamp: Date
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chord Tester")
                .font(.headline)

            Text("Press key combinations to test chord detection. This helps identify keyboard ghosting issues.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            if detectedChords.isEmpty {
                Text("No chords detected yet. Start typing chords...")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(detectedChords) { entry in
                    HStack {
                        Text(entry.keys)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                        Spacer()
                        if let expansion = entry.expansion {
                            Text("→ \(expansion)")
                                .foregroundColor(.green)
                        } else {
                            Text("(no match)")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Clear") {
                    detectedChords.removeAll()
                }
            }
        }
        .padding()
        .onReceive(appState.$lastExpansion.dropFirst()) { expansion in
            let entry = ChordEntry(keys: "chord", expansion: expansion, timestamp: Date())
            detectedChords.insert(entry, at: 0)
            if detectedChords.count > 50 {
                detectedChords.removeLast()
            }
        }
    }
}
