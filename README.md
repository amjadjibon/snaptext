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
| `--copy`, `-c` | also copy the printed text to the clipboard |
| `--layout` | keep the printed layout: rows, columns, blank lines |
| `--json` | print JSON with per-line confidence and bounding box |
| `--language <code>`, `-l` | recognition language hint; repeat for several |
| `--fast` | favour speed over accuracy |
| `--accurate` | favour accuracy over speed (default) |
| `--no-correction` | disable Vision's language correction |
| `--verbose`, `-v` | progress and error detail on stderr |
| `-h`, `--help` / `--version` | help / version |

### Examples

```bash
snaptext receipt.png --copy
snaptext invoice.png --layout
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

### Layout

By default each block Vision finds gets its own line, in Vision's reading order —
which walks columns top to bottom, so a two-column invoice arrives as a pile of
fragments. `--layout` puts every block back at the row and column it was printed
at, using the bounding boxes:

```bash
snaptext invoice.png --layout
```

```text
ACME Supply Co.                    Invoice #A-2291

Bill to: Northwind Ltd             Date: 2026-03-04

   Widget, 40mm x 120                     $340.00
   Freight                                 $28.50

   Subtotal                               $368.50
   Sales tax (8.25%)                       $30.40
   Amount due                             $398.90
```

Rows are grouped by vertical overlap, the character cell is estimated from how
wide each block is per character, and a gap wider than the usual line spacing
becomes a blank line. Monospaced pages come back almost exactly; proportional
type lines up column by column but drifts within a line.

Drawn rules — the `-----` separator above — are not text, so Vision returns no
box for them and they cannot be restored. Their blank row survives.

### JSON

```bash
snaptext receipt.png --json
```

```json
{
  "lines" : [
    {
      "box" : { "height" : 0.03, "width" : 0.28, "x" : 0.08, "y" : 0.78 },
      "confidence" : 1,
      "text" : "Invoice #1024"
    }
  ],
  "text" : "Invoice #1024\nTotal RM42.50"
}
```

`box` is in Vision's normalized coordinates: 0…1, origin bottom-left. It is what
`--layout` reads.

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
Plugins/VersionStamp/    stamps the version from git at build time
Tests/SnapTextKitTests/  parser, formatter, loader, and OCR tests
```

The OCR tests render their own images, so there are no binary fixtures to maintain.

### Versioning

There is no version constant to bump — the git tag is the source of truth. A build
plugin stamps `--version` from the nearest tag, the number of commits since it, and
the short commit hash:

```bash
$ snaptext --version
snaptext 0.3.0 (663d663)      # built at the tag
snaptext 0.3.0+2 (a1b2c3d)    # two commits past it
```

Builds made outside a
git checkout (a source tarball) fall back to `fallbackVersion` in
`Plugins/VersionStamp/VersionStamp.swift` and print no commit.

### Releasing

```bash
just publish 0.4.0 --dry-run   # build and package only; nothing leaves your machine
just publish 0.4.0             # tag, build, publish (asks before it pushes)
```

`scripts/release.sh` checks the tree is clean and the tag is free, runs the tests,
tags, builds an arm64 and an x86_64 binary, merges them with `lipo`, and publishes
`snaptext-darwin-{arm64,x86_64,universal}.tar.gz` plus `SHA256SUMS` to GitHub
Releases, with notes gathered from the conventional commits since the last tag. If
anything fails before publishing, the local tag is removed again.

Slices are built one triple at a time rather than with `swift build --arch`: that
flag routes through XCBuild, which cannot resolve the VersionStamp plugin.

Released binaries are not notarized, so they carry a quarantine flag on download —
the install instructions in the generated notes say how to clear it. Homebrew
formulae download with `curl`, which does not set that flag, so a tapped install
needs no `xattr` — that is the reason for a formula here rather than a cask, since
casks do quarantine what they download.

### Homebrew tap

A tap is just a GitHub repository named `homebrew-<something>` with formulae in
`Formula/`. Create it once — a shared tap for several tools, or one per project:

```bash
gh repo create amjadjibon/homebrew-tap --public \
    --description "Homebrew formulae for amjadjibon's tools"
```

Then pass it to every release:

```bash
just publish 0.4.0 --tap amjadjibon/homebrew-tap
```

The script writes `dist/snaptext.rb` from the checksums it just computed and, after
the GitHub release exists, commits it to the tap as `Formula/snaptext.rb`. Users
install with:

```bash
brew install amjadjibon/tap/snaptext     # brew expands this to the homebrew-tap repo
```

Both repositories have to be public: Homebrew downloads release assets
unauthenticated, so a private release 404s no matter who runs `brew install`.

The formula points at the universal tarball rather than building from source:
`--version` is stamped from the git checkout, which a Homebrew source build does not
have, so a source formula would report `0.0.0`. One universal binary also means no
`on_arm`/`on_intel` branches to keep in sync.

Without `--tap` the formula is still written to `dist/` and nothing is pushed.

## License

MIT — see [LICENSE](LICENSE).
