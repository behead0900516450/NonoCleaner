#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
OUTPUT="$PROJECT_DIR/.build/productization-regression"
MODULE_CACHE="$PROJECT_DIR/.build/ModuleCache"

mkdir -p "$PROJECT_DIR/.build" "$MODULE_CACHE"
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" swiftc \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macosx15.0 \
  -module-cache-path "$MODULE_CACHE" \
  "$PROJECT_DIR/Sources/NonoCleanerApp/Models/CleanerItem.swift" \
  "$PROJECT_DIR/Sources/NonoCleanerApp/Models/ItemAgeBucket.swift" \
  "$PROJECT_DIR/Sources/NonoCleanerApp/Models/ItemSort.swift" \
  "$PROJECT_DIR/Sources/NonoCleanerApp/Models/SafeItemGroup.swift" \
  "$PROJECT_DIR/Sources/NonoCleanerApp/Models/ScanReport.swift" \
  "$PROJECT_DIR/Sources/NonoCleanerApp/Models/SourceDescription.swift" \
  "$PROJECT_DIR/Sources/NonoCleanerApp/Services/OriginKnowledge.swift" \
  "$PROJECT_DIR/Sources/NonoCleanerApp/Services/ScanReportBuilder.swift" \
  "$PROJECT_DIR/Sources/NonoCleanerApp/Utilities/Formatters.swift" \
  "$PROJECT_DIR/Tests/ProductizationRegressionMain.swift" \
  -o "$OUTPUT"

"$OUTPUT"
