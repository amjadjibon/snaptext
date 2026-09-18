import Foundation

/// Rebuilds the page layout from Vision's bounding boxes.
///
/// Vision returns one observation per block of text with no horizontal context,
/// and walks columns top-to-bottom rather than rows left-to-right — so an
/// invoice with a right-aligned amount column arrives as one column of
/// fragments. Putting each block back at the row and column it was printed at
/// makes the output readable as the page again.
enum LayoutRenderer {
    /// A gap this many times the usual line spacing was a blank line on the page.
    private static let blankLineRatio = 1.6

    static func render(_ lines: [OCRLine]) -> String {
        guard !lines.isEmpty else { return "" }

        // One character cell, averaged over how wide each block is per character.
        // Short blocks are skipped: their padding skews the estimate.
        let cell = median(lines.filter { $0.text.count > 2 }.map { $0.box.width / Double($0.text.count) })
        let lineHeight = median(lines.map(\.box.height))

        // Boxes are all we have to place text with. Without them (or with a
        // single unmeasurable line) there is no layout to rebuild.
        guard cell > 0, lineHeight > 0 else {
            return lines.map(\.text).joined(separator: "\n")
        }

        let rows = groupIntoRows(lines, tolerance: lineHeight / 2)
        // The usual spacing between rows. Taken low in the distribution rather
        // than at the median: the blank lines being looked for are themselves
        // large gaps, and would drag a median up past their own threshold.
        let pitch = lowerQuartile(zip(rows, rows.dropFirst()).map { $0.midY - $1.midY })
        let leftMargin = lines.map(\.box.x).min() ?? 0

        var output: [String] = []
        for (index, row) in rows.enumerated() {
            if index > 0, pitch > 0, rows[index - 1].midY - row.midY > pitch * blankLineRatio {
                output.append("")
            }
            output.append(row.rendered(cell: cell, leftMargin: leftMargin))
        }

        return output.joined(separator: "\n")
    }

    private struct Row {
        var lines: [OCRLine]

        /// The vertical centre of the row, which the first line establishes.
        var midY: Double { lines[0].box.midY }

        func rendered(cell: Double, leftMargin: Double) -> String {
            var text = ""
            for line in lines.sorted(by: { $0.box.x < $1.box.x }) {
                let column = Int(((line.box.x - leftMargin) / cell).rounded())
                if text.count < column {
                    text += String(repeating: " ", count: column - text.count)
                } else if !text.isEmpty {
                    text += " "  // never run two blocks together
                }
                text += line.text
            }
            return text
        }
    }

    /// Top to bottom, collecting blocks whose centres sit within `tolerance` of
    /// the row they started.
    private static func groupIntoRows(_ lines: [OCRLine], tolerance: Double) -> [Row] {
        var rows: [Row] = []
        for line in lines.sorted(by: { $0.box.midY > $1.box.midY }) {
            if var last = rows.last, abs(last.midY - line.box.midY) <= tolerance {
                last.lines.append(line)
                rows[rows.count - 1] = last
            } else {
                rows.append(Row(lines: [line]))
            }
        }
        return rows
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.sorted()[values.count / 2]
    }

    private static func lowerQuartile(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.sorted()[values.count / 4]
    }
}
