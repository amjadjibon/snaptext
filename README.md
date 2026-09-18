# SnapText

A fast, local-first macOS CLI for extracting text from images, screenshots, and the clipboard using Apple's Vision framework.

> OCR anything on your Mac without uploading it anywhere.

```text
$ snaptext region --copy --verbose

Select an area of the screen...
✓ Recognized 12 lines
✓ Copied to clipboard
```

No cloud, no API key, no per-image cost — Vision runs entirely on-device.

## Install

```bash
swift build -c release
cp .build/release/snaptext /usr/local/bin/    # or /opt/homebrew/bin/
```

Requires macOS 14 or later. `snaptext screenshot` and `snaptext region` need Screen
Recording permission for your terminal (System Settings → Privacy & Security → Screen Recording).

## Usage

```bash
snaptext <image>            # OCR an image file
snaptext file <image>       # same, explicit form
snaptext clipboard          # OCR the image on the clipboard
snaptext screenshot         # capture the whole screen, then OCR it
snaptext region             # select a screen region, then OCR it
```

Any format `NSImage` reads works: PNG, JPEG, TIFF, HEIC, and friends.

### Options

| Option | Effect |
|---|---|
| `--copy`, `-c` | also copy the recognized text to the clipboard |
| `--json` | print JSON with per-line confidence instead of plain text |
| `--language <code>`, `-l` | recognition language hint; repeat for several |
| `--fast` | favour speed over accuracy |
| `--accurate` | favour accuracy over speed (default) |
| `--no-correction` | disable Vision's language correction |
| `--verbose`, `-v` | progress and error detail on stderr |
| `-h`, `--help` / `--version` | help / version |

### Examples

```bash
snaptext receipt.png --copy
snaptext receipt.png --json
snaptext receipt.png --language en-US --language bn-BD
snaptext screenshot.png --fast
```

The best trick is region capture straight to the clipboard, ready for ⌘V:

```bash
snaptext region --copy
```

## Unix-friendly

Text goes to stdout, diagnostics to stderr, so it pipes:

```bash
snaptext invoice.png | grep -i total
snaptext screenshot.png > text.txt
snaptext receipt.png | grep Total | awk '{print $2}'
```

### JSON

```bash
snaptext receipt.png --json
```

```json
{
  "lines" : [
    { "confidence" : 1, "text" : "Invoice #1024" },
    { "confidence" : 1, "text" : "Total RM42.50" }
  ],
  "text" : "Invoice #1024\nTotal RM42.50"
}
```

### Exit codes

| Code | Meaning |
|---|---|
| `0` | success |
| `1` | OCR/runtime failure, including `no text detected` |
| `2` | invalid CLI arguments |
| `3` | image could not be loaded |
| `4` | screenshot cancelled or failed |

## Development

```bash
swift build          # or: just build
swift test           # or: just test
swift run snaptext ~/Desktop/image.png
```

Layout:

```text
Sources/SnapText/        thin executable entry point
Sources/SnapTextKit/     CLI, OCR, Image, Capture, Clipboard, Output
Tests/SnapTextKitTests/  parser, formatter, loader, and OCR tests
```

The OCR tests render their own images, so there are no binary fixtures to maintain.

## License

MIT — see [LICENSE](LICENSE).
