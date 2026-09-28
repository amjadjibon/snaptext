import SnapTextKit
import SwiftUI

struct ResultView: View {
    let pages: [Page]

    @AppStorage("outputStyle") private var style: OutputStyle = .text
    @State private var copyCount = 0

    private var output: String {
        (try? Recognizer.render(pages, as: style)) ?? ""
    }

    private var lines: [OCRLine] {
        pages.flatMap(\.result.lines)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Output", selection: $style) {
                ForEach(OutputStyle.allCases, id: \.self) { style in
                    Text(OutputStyle.caseDisplayRepresentations[style]?.title ?? "")
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView([.vertical, style == .text ? [] : .horizontal]) {
                Text(output)
                    .font(style == .text ? .body : .system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }

            Text(summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                NavigationLink {
                    PagesView(pages: pages)
                } label: {
                    Label("Show Image", systemImage: "text.viewfinder")
                }
                Spacer()
                ShareLink(item: output)
                Button("Copy", systemImage: "doc.on.doc") {
                    Clipboard().writeText(output)
                    copyCount += 1
                }
            }
        }
        .sensoryFeedback(.success, trigger: copyCount)
    }

    private var summary: String {
        let lineCount = lines.count == 1 ? "1 line" : "\(lines.count) lines"
        let pageCount = pages.count > 1 ? " · \(pages.count) pages" : ""
        let average = lines.isEmpty ? 0 : lines.map(\.confidence).reduce(0, +) / Double(lines.count)
        return "\(lineCount)\(pageCount) · \(Int((average * 100).rounded()))% confidence"
    }
}

/// Every page with a box drawn round each recognized line, coloured by
/// confidence. Tapping a box copies that line.
struct PagesView: View {
    let pages: [Page]

    @State private var copiedLine: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(pages) { page in
                    Image(decorative: page.image, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .overlay { boxes(for: page.result.lines) }
                        .border(.separator)
                }
            }
            .padding()
        }
        .navigationTitle("Recognized Lines")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if let copiedLine {
                Label("Copied “\(copiedLine)”", systemImage: "checkmark.circle.fill")
                    .lineLimit(1)
                    .padding()
                    .background(.regularMaterial, in: Capsule())
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.selection, trigger: copiedLine)
    }

    private func boxes(for lines: [OCRLine]) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                // Vision's boxes are normalized with the origin at the bottom-left.
                let rect = CGRect(
                    x: line.box.x * size.width,
                    y: (1 - line.box.y - line.box.height) * size.height,
                    width: line.box.width * size.width,
                    height: line.box.height * size.height
                )
                Rectangle()
                    .fill(color(for: line.confidence).opacity(0.15))
                    .strokeBorder(color(for: line.confidence), lineWidth: 1.5)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .accessibilityLabel(line.text)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Copies this line")
                    .onTapGesture { copy(line.text) }
            }
        }
    }

    private func color(for confidence: Double) -> Color {
        switch confidence {
        case ..<0.5: return .red
        case ..<0.8: return .orange
        default: return .accentColor
        }
    }

    private func copy(_ text: String) {
        Clipboard().writeText(text)
        withAnimation { copiedLine = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { if copiedLine == text { copiedLine = nil } }
        }
    }
}
