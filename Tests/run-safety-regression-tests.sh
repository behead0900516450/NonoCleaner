#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
OUTPUT="$PROJECT_DIR/.build/safety-classifier-regression"
MODULE_CACHE="$PROJECT_DIR/.build/ModuleCache"

mkdir -p "$PROJECT_DIR/.build" "$MODULE_CACHE"
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" swiftc \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macosx15.0 \
  -module-cache-path "$MODULE_CACHE" \
  "$PROJECT_DIR/Sources/NonoCleanerApp/Models/CleanerItem.swift" \
  "$PROJECT_DIR/Sources/NonoCleanerApp/Services/SafetyClassifier.swift" \
  "$PROJECT_DIR/Tests/SafetyClassifierRegressionMain.swift" \
  -o "$OUTPUT"

"$OUTPUT"
