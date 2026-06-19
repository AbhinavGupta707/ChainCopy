import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        TabView {
            Form {
                Toggle("Capture clipboard changes", isOn: $store.isCaptureEnabled)

                Picker("Separator", selection: $store.separator) {
                    Text("New Line").tag("\n")
                    Text("Blank Line").tag("\n\n")
                    Text("Space").tag(" ")
                }

                Stepper(value: $store.maxItemCount, in: 20...500, step: 20) {
                    Text("Keep \(store.maxItemCount) items")
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "switch.2")
            }

            Form {
                LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "com.abhinavgupta.ChainCopy")
                LabeledContent("Minimum macOS", value: "14.0")
                LabeledContent("Distribution", value: "Direct download")
                LabeledContent("License provider", value: "Not configured")
            }
            .formStyle(.grouped)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 460, height: 280)
        .padding(20)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(store: ClipboardStore(items: PreviewData.clips))
    }
}
