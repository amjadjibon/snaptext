import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

struct ContentView: View {
    @State private var model = ScanModel()
    @State private var showsScanner = false
    @State private var showsFileImporter = false
    @State private var showsSettings = false
    @State private var photoSelection: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            Group {
                if model.pages.isEmpty {
                    sources
                } else {
                    ResultView(pages: model.pages)
                }
            }
            .navigationTitle("SnapText")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { showsSettings = true }
                }
                if !model.pages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New", systemImage: "plus") { model.reset() }
                    }
                }
            }
            .overlay {
                if model.isWorking {
                    ProgressView("Recognizing…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .fullScreenCover(isPresented: $showsScanner) {
            DocumentScanner { result in
                showsScanner = false
                switch result {
                case .success(let images) where !images.isEmpty:
                    model.recognize(images: images)
                case .success:
                    break  // cancelled
                case .failure(let error):
                    model.errorMessage = Recognizer.message(for: error)
                }
            }
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            do {
                model.recognize(data: try result.get().map(Self.readSecurityScoped))
            } catch {
                model.errorMessage = Recognizer.message(for: error)
            }
        }
        .onChange(of: photoSelection) { _, items in
            guard !items.isEmpty else { return }
            photoSelection = []
            Task {
                do {
                    let data = try await Self.loadData(items)
                    model.recognize(data: data)
                } catch {
                    model.errorMessage = Recognizer.message(for: error)
                }
            }
        }
        .dropDestination(for: Data.self) { items, _ in
            model.recognize(data: items)
            return !items.isEmpty
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
        }
        .alert(
            "Couldn't Read the Text",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            ),
            presenting: model.errorMessage
        ) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
    }

    private var sources: some View {
        List {
            Section {
                if VNDocumentCameraViewController.isSupported {
                    Button {
                        showsScanner = true
                    } label: {
                        Label("Scan Document", systemImage: "doc.viewfinder")
                    }
                }
                PhotosPicker(
                    selection: $photoSelection,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    Label("Choose Photos", systemImage: "photo.on.rectangle")
                }
                Button {
                    showsFileImporter = true
                } label: {
                    Label("Import from Files", systemImage: "folder")
                }
                Button {
                    model.pasteImage()
                } label: {
                    Label("Paste Image", systemImage: "doc.on.clipboard")
                }
            } footer: {
                Text("Text is recognized on your device. Nothing is uploaded.")
            }
        }
        .disabled(model.isWorking)
    }

    private static func loadData(_ items: [PhotosPickerItem]) async throws -> [Data] {
        var data: [Data] = []
        for item in items {
            if let bytes = try await item.loadTransferable(type: Data.self) {
                data.append(bytes)
            }
        }
        return data
    }

    /// Files picked outside the sandbox are only readable inside a security scope.
    private static func readSecurityScoped(_ url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try Data(contentsOf: url)
    }
}

#Preview {
    ContentView()
}
