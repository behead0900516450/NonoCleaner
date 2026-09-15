# Nono Cleaner

A transparent macOS cleaner that explains what files are before deleting them.

Nono Cleaner is a native SwiftUI utility. It scans selected local folders, explains the likely origin and purpose of each result, and leaves the final decision to the user. It does not automatically delete files.

## Why Nono Cleaner

Many cleaner applications start with a single number: how much storage can be removed. Nono Cleaner starts with context:

- What is this?
- Where did it come from?
- Why does it exist?
- What happens if I delete it?
- Can it be regenerated?

Origin detection and safety classification are intentionally conservative. When the app cannot establish that an item is reproducible, it requires review instead of presenting the item as low risk.

## Features

- Low-risk cleanup
- Review-required items
- Protected work files
- Source and origin explanations with confidence levels
- Large-file discovery
- Time-based organization
- Source grouping for low-risk items
- Sorting by name, modification date, size, and risk
- Trash-only deletion
- Running-app guard
- Recent-modification guard
- macOS protected-path awareness
- In-app normal and full debug scan reports

## Safety Model

Nono Cleaner uses three user-facing safety levels:

- **Low Risk**: Matches an explicit allowlist or a highly trusted reproducible-cache rule. Low Risk does not mean zero impact; deleting an item may trigger a cache rebuild or a future download.
- **Review**: The item may be disposable, but its purpose or impact is not certain enough for low-risk cleanup. The user must inspect it.
- **Protected**: Likely user work or an important project format, such as original video, Premiere projects, Photoshop documents, or Lightroom catalogs. These items are excluded from one-click cleanup.

Nothing is deleted automatically. Every cleanup action requires user confirmation and moves files to the macOS Trash rather than permanently deleting them.

## Screenshots

Screenshot placeholders and the required capture list are in [`docs/screenshots/`](docs/screenshots/). Real screenshots are intentionally not included yet so private filenames and local paths are not published accidentally.

## Requirements

- macOS 13 Ventura or later
- Apple Silicon Mac
- Xcode 15 or compatible Swift command-line tools when building from source

Intel Macs have not been validated for this beta.

## Installation

Public beta builds are not available yet. The first downloadable beta will be published after release validation.

> This beta build may trigger macOS Gatekeeper warnings until Developer ID signing and notarization are completed.

Nono Cleaner does not recommend bypassing macOS security protections. Until signed and notarized builds are published, developers can inspect the source and build locally:

```sh
./Scripts/build-app.sh
```

The local development build is created at `build/Nono Cleaner.app` and uses ad-hoc signing.

## Privacy

The current codebase has:

- Local scanning only
- No file uploads
- No telemetry or analytics
- No account requirement
- No server component

Scan reports remain in memory unless the user explicitly chooses **Export…** and selects a destination. Reports can contain filenames and local paths; review them before sharing.

## Current Beta Scope

The beta scans enabled portions of:

- `~/Downloads`
- `~/Desktop`
- `~/Library/Caches`
- The current user's temporary directory
- Accessible temporary data under `/private/var/folders`
- Adobe Media Cache
- Adobe Media Cache Files
- Adobe Peak Files

macOS-protected locations are safely skipped. The app does not attempt to bypass system privacy controls.

## Known Limitations

- Some macOS-protected folders cannot be scanned.
- Origin detection is rule-based and may report Medium or Unknown confidence.
- The beta currently focuses on Apple Silicon.
- Not all third-party caches are classified as Low Risk.
- Developer ID signing and notarization are not yet configured.

## Contributing

Useful contributions include:

- Reproducible bug reports
- Identification of unknown cache or source locations
- Safety misclassification reports

Before attaching a scan report, remove or mask private filenames, usernames, folder names, and local paths. Do not post credentials or confidential project information.

Issue templates are available for bugs, cache identification, and classification problems.

## Development

Open `Package.swift` in Xcode and run the `NonoCleaner` scheme, or build from the command line:

```sh
swift build
```

The project has no third-party package dependencies at this time.

## License

Nono Cleaner is source-available.

You may inspect, study, modify, and use the code for personal and non-commercial purposes.

Commercial redistribution, resale, rebranding, or incorporation into commercial cleaner products requires explicit permission. See the [Nono Cleaner Source-Available Beta License](LICENSE) for the complete terms. This license is not OSI-approved.

---

## 繁體中文

Nono Cleaner 是一款透明、保守的 macOS 原生清理工具。它不只顯示可能釋放的空間，也嘗試說明每個項目是什麼、從哪裡來、為什麼存在，以及刪除後可能發生什麼。

### 核心功能

- 低風險、需要確認與保護項目三層分類
- 來源、用途、刪除影響與判斷信心說明
- 大型檔案與時間整理
- 低風險來源群組
- 依名稱、日期、大小與風險排序
- App 執行中與近期修改保護
- 一般與完整除錯掃描報告

### 安全與隱私

低風險不代表完全沒有影響；某些快取刪除後需要重建或重新下載。Nono Cleaner 不會自動刪除檔案，每次清理都需要使用者確認，並只會移到 macOS 垃圾桶。

目前程式碼只在本機掃描，沒有檔案上傳、遙測、帳號或伺服器元件。macOS 保護的路徑會安全略過。掃描報告可能包含私人檔名與路徑，分享前請先檢查並遮蔽。

### Beta 限制

- 目前以 Apple Silicon Mac 為主
- 來源判斷由規則完成，可能顯示「可能」或「未知」
- 並非所有第三方快取都會被分類為低風險
- 尚未完成 Developer ID 簽章與 notarization

### License

Nono Cleaner 採用 source-available 授權。你可以為個人非商業用途查看、學習、修改與使用程式碼。商業重新分發、販售、改名重新包裝，或整合到商業清理工具前，必須先取得明確授權。完整條款請參閱 [LICENSE](LICENSE)。這份授權未獲 OSI 認可。
