build:
    swift build

release:
    swift build -c release

run *args:
    swift run snaptext {{args}}

test:
    swift test

clean:
    swift package clean

install:
    swift build -c release
    cp .build/release/snaptext /usr/local/bin/snaptext

publish version *flags:
    ./scripts/release.sh {{version}} {{flags}}
