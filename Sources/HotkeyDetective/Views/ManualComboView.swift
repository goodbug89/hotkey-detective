import SwiftUI
import Engine

struct ManualComboView: View {
    var onProbe: (KeyCombo) -> Void
    @State private var mods: Modifiers = [.command]
    @State private var keyCode: UInt16 = 21

    private let keys = KeyCodeNames.table.sorted { $0.value < $1.value }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("⌃", isOn: binding(.control)); Toggle("⌥", isOn: binding(.option))
                Toggle("⇧", isOn: binding(.shift)); Toggle("⌘", isOn: binding(.command))
            }
            .toggleStyle(.button)
            Picker(L.t("probe.manual.key"), selection: $keyCode) {
                ForEach(keys, id: \.key) { Text($0.value).tag($0.key) }
            }
            Button(L.t("probe.manual.lookUp", KeyCombo(keyCode: keyCode, modifiers: mods).display)) {
                onProbe(KeyCombo(keyCode: keyCode, modifiers: mods))
            }
            .disabled(mods.isEmpty)
        }
    }

    private func binding(_ m: Modifiers) -> Binding<Bool> {
        Binding(get: { mods.contains(m) }, set: { if $0 { mods.insert(m) } else { mods.remove(m) } })
    }
}
