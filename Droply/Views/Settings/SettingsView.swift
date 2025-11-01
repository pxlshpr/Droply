import SwiftUI

struct SettingsView: View {
    @AppStorage("cueVisualizationMode") private var visualizationMode: String = CueVisualizationMode.button.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(CueVisualizationMode.allCases) { mode in
                        Button {
                            visualizationMode = mode.rawValue
                        } label: {
                            HStack {
                                Label(mode.rawValue, systemImage: mode.icon)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if visualizationMode == mode.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Cue Visualization")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
