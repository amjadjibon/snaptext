import SnapTextKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(RecognitionSettings.Key.fast) private var fast = false
    @AppStorage(RecognitionSettings.Key.languageCorrection) private var languageCorrection = true
    @AppStorage(RecognitionSettings.Key.languages) private var storedLanguages = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Recognition", selection: $fast) {
                        Text("Accurate").tag(false)
                        Text("Fast").tag(true)
                    }
                    Toggle("Language Correction", isOn: $languageCorrection)
                } footer: {
                    Text("Turn off language correction for codes, serial numbers, and other text that isn't words.")
                }

                Section {
                    NavigationLink {
                        LanguagesView(stored: $storedLanguages, level: fast ? .fast : .accurate)
                    } label: {
                        LabeledContent("Languages", value: languagesSummary)
                    }
                } footer: {
                    Text("Hints for the recognizer, in priority order. Leave empty to use the default.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var languagesSummary: String {
        let languages = RecognitionSettings.decodeLanguages(storedLanguages)
        return languages.isEmpty ? "Automatic" : languages.joined(separator: ", ")
    }
}

private struct LanguagesView: View {
    @Binding var stored: String
    let level: RecognitionLevel

    private var selected: [String] {
        RecognitionSettings.decodeLanguages(stored)
    }

    var body: some View {
        List(OCRService.supportedLanguages(level: level), id: \.self) { code in
            Button {
                toggle(code)
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(Locale.current.localizedString(forIdentifier: code) ?? code)
                        Text(code).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let index = selected.firstIndex(of: code) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(.tint))
                    }
                }
            }
            .foregroundStyle(.primary)
            .accessibilityAddTraits(selected.contains(code) ? .isSelected : [])
        }
        .navigationTitle("Languages")
        .toolbar {
            Button("Clear") { stored = "" }
                .disabled(selected.isEmpty)
        }
    }

    private func toggle(_ code: String) {
        var languages = selected
        if let index = languages.firstIndex(of: code) {
            languages.remove(at: index)
        } else {
            languages.append(code)
        }
        stored = RecognitionSettings.encodeLanguages(languages)
    }
}
