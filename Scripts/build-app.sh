#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Nono Cleaner.app"
MODULE_CACHE="$PROJECT_DIR/.build/ModuleCache"

if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  SDK_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
else
  SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
fi

cd "$PROJECT_DIR"
SDKROOT="$SDK_PATH" \
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" \
SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" \
swift build -c release --disable-sandbox --sdk "$SDK_PATH" --scratch-path .build

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$PROJECT_DIR/.build/release/NonoCleaner" "$APP_DIR/Contents/MacOS/NonoCleaner"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_TW</string>
    <key>CFBundleExecutable</key>
    <string>NonoCleaner</string>
    <key>CFBundleIdentifier</key>
    <string>com.nono.cleaner</string>
    <key>CFBundleName</key>
    <string>Nono Cleaner</string>
    <key>CFBundleDisplayName</key>
    <string>Nono Cleaner</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"
echo "Built: $APP_DIR"
