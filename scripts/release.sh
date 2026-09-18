#!/usr/bin/env bash
#
# Cut a snaptext release: tag, build universal artifacts, publish to GitHub.
#
#   scripts/release.sh 0.4.0             tag, build, publish (asks before publishing)
#   scripts/release.sh 0.4.0 --dry-run   build and package only; nothing leaves this machine
#   scripts/release.sh 0.4.0 --yes       skip the confirmation prompt
#   scripts/release.sh 0.4.0 --skip-tests
#
# The tag is created before the build on purpose: the version in the binary is
# stamped from git, so the artifacts must be built from the tagged commit.

set -euo pipefail

readonly BINARY="snaptext"
readonly DIST="dist"
# Each slice is built with the native build system and merged with lipo:
# `swift build --arch` routes through XCBuild, which cannot resolve the
# VersionStamp plugin.
readonly ARCHITECTURES=("arm64" "x86_64")

version=""
dry_run=false
assume_yes=false
run_tests=true
tag_created=false

die() {
    printf 'release: %s\n' "$1" >&2
    exit 1
}

log() {
    printf '\033[1m==>\033[0m %s\n' "$1"
}

usage() {
    sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'
}

cleanup() {
    local status=$?
    # Never leave a local tag behind for a release that did not ship.
    if [ "$tag_created" = true ] && { [ "$dry_run" = true ] || [ $status -ne 0 ]; }; then
        git tag -d "v${version}" >/dev/null 2>&1 || true
    fi
    return $status
}
trap cleanup EXIT

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=true ;;
        --yes | -y) assume_yes=true ;;
        --skip-tests) run_tests=false ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*) die "unknown option: $1" ;;
        *)
            [ -z "$version" ] || die "unexpected argument: $1"
            version="${1#v}"
            ;;
    esac
    shift
done

[ -n "$version" ] || {
    usage >&2
    exit 2
}

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] ||
    die "version must look like 0.4.0 or 0.4.0-beta.1, got: $version"

readonly tag="v${version}"

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || die "not a git repository"

# --- preflight ---------------------------------------------------------------

log "Checking the working tree"

[ -z "$(git status --porcelain --untracked-files=no)" ] ||
    die "working tree has uncommitted changes; commit or stash them first"

! git rev-parse -q --verify "refs/tags/${tag}" >/dev/null ||
    die "tag ${tag} already exists locally"

if [ "$dry_run" = false ]; then
    command -v gh >/dev/null || die "gh is not installed: https://cli.github.com"
    gh auth status >/dev/null 2>&1 || die "gh is not authenticated; run: gh auth login"

    git remote get-url origin >/dev/null 2>&1 || die "no 'origin' remote to publish to"

    [ -z "$(git ls-remote --tags origin "refs/tags/${tag}" 2>/dev/null)" ] ||
        die "tag ${tag} already exists on origin"

    branch="$(git branch --show-current)"
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
    [ -n "$upstream" ] || die "branch ${branch} has no upstream; run: git push -u origin ${branch}"

    git fetch --quiet origin "$branch"
    [ "$(git rev-list --count "${upstream}..HEAD")" -eq 0 ] ||
        die "branch ${branch} is ahead of ${upstream}; push it before releasing"
fi

if [ "$run_tests" = true ]; then
    log "Running tests"
    swift test
fi

# --- tag and build -----------------------------------------------------------

log "Tagging ${tag}"
git tag -a "$tag" -m "${BINARY} ${version}"
tag_created=true

rm -rf "$DIST"
mkdir -p "$DIST"
staging="$(mktemp -d)"

for arch in "${ARCHITECTURES[@]}"; do
    log "Building ${arch}"
    swift build -c release --triple "${arch}-apple-macosx"

    slice=".build/${arch}-apple-macosx/release/${BINARY}"
    [ -f "$slice" ] || die "expected a binary at ${slice}"

    # Only the host slice can be executed, so check the stamp on that one.
    if [ "$arch" = "$(uname -m)" ]; then
        stamped="$("$slice" --version)"
        case "$stamped" in
            "${BINARY} ${version} ("*) ;;
            *) die "binary reports '${stamped}', expected '${BINARY} ${version} (<commit>)'" ;;
        esac
        log "Binary reports: ${stamped}"
    fi

    cp "$slice" "${staging}/${BINARY}"
    tar -czf "${DIST}/${BINARY}-darwin-${arch}.tar.gz" -C "$staging" "$BINARY"
done

# --- package -----------------------------------------------------------------

log "Packaging a universal binary"
lipo -create -output "${staging}/${BINARY}" \
    ".build/arm64-apple-macosx/release/${BINARY}" \
    ".build/x86_64-apple-macosx/release/${BINARY}"
tar -czf "${DIST}/${BINARY}-darwin-universal.tar.gz" -C "$staging" "$BINARY"
rm -rf "$staging"

(cd "$DIST" && shasum -a 256 ./*.tar.gz > SHA256SUMS)

# --- release notes -----------------------------------------------------------

previous="$(git describe --tags --abbrev=0 "${tag}^" 2>/dev/null || true)"
range="${previous:+${previous}..}${tag}"

notes="${DIST}/notes.md"
{
    section() {
        local title="$1" pattern="$2" entries
        entries="$(git log -E --no-merges --pretty=format:'- %s' --grep="$pattern" "$range" || true)"
        [ -n "$entries" ] || return 0
        printf '### %s\n\n%s\n\n' "$title" "$entries"
    }

    section "Features" '^feat(\(.+\))?!?: '
    section "Fixes" '^fix(\(.+\))?!?: '
    section "Performance" '^perf(\(.+\))?!?: '

    printf '### Install\n\n'
    printf '```bash\n'
    printf 'tar -xzf %s-darwin-universal.tar.gz\n' "$BINARY"
    printf 'xattr -d com.apple.quarantine %s   # the binary is not notarized\n' "$BINARY"
    printf 'mv %s /usr/local/bin/\n' "$BINARY"
    printf '```\n\n'

    # shellcheck disable=SC2016  # the backticks are markdown fences
    printf '### Checksums\n\n```\n%s\n```\n' "$(cat "${DIST}/SHA256SUMS")"

    if [ -n "$previous" ]; then
        printf '\n**Full changelog**: %s...%s\n' "$previous" "$tag"
    fi
} > "$notes"

# --- confirm and publish -----------------------------------------------------

log "Artifacts in ${DIST}/"
ls -1 "$DIST"
printf '\n'
cat "$notes"
printf '\n'

if [ "$dry_run" = true ]; then
    log "Dry run: nothing pushed, tag ${tag} removed. Artifacts left in ${DIST}/"
    exit 0
fi

if [ "$assume_yes" = false ]; then
    [ -t 0 ] || die "refusing to publish without a terminal; pass --yes to confirm"
    printf 'Push %s and publish this release to %s? [y/N] ' "$tag" "$(gh repo view --json nameWithOwner -q .nameWithOwner)"
    read -r reply
    case "$reply" in
        y | Y | yes | YES) ;;
        *) die "aborted; local tag ${tag} removed" ;;
    esac
fi

log "Pushing ${tag}"
git push origin "$tag"

log "Creating the GitHub release"
gh release create "$tag" \
    "${DIST}/${BINARY}-darwin-arm64.tar.gz" \
    "${DIST}/${BINARY}-darwin-x86_64.tar.gz" \
    "${DIST}/${BINARY}-darwin-universal.tar.gz" \
    "${DIST}/SHA256SUMS" \
    --title "${BINARY} ${version}" \
    --notes-file "$notes"

log "Released ${tag}: $(gh release view "$tag" --json url -q .url)"
