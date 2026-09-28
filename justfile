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

# Generate the iOS app's Xcode project and open it.
ios:
    cd iOS && xcodegen generate && open SnapText.xcodeproj

# Run the iOS app's tests on a simulator, e.g. `just ios-test "iPhone 17 Pro"`.
ios-test device="iPhone 17 Pro":
    cd iOS && xcodegen generate && xcodebuild test -project SnapText.xcodeproj -scheme SnapTextApp \
        -destination "platform=iOS Simulator,name={{device}}" -skipPackagePluginValidation -quiet
