import Foundation
import UniformTypeIdentifiers

struct FileScanner: Sendable {
    private struct ScanRoot {
        let url: URL
        let source: ScanSource
        let purpose: String
        let location: String
        let kind: ScanRootKind
    }

    private struct ContentSummary {
        var bytes: Int64 = 0
        var fileCount = 0
        var protectedMatch: String?
        var reviewMatch: String?
        var latestModifiedAt: Date?
        var symbolicLinksSkipped = 0
        var inaccessiblePaths: [String] = []
        var permissionDeniedPaths: [String] = []
        var errors: [String] = []
    }

    private static let protectedExtensions: Set<String> = [
        "mov", "mp4", "m4v", "avi", "mxf", "r3d", "braw", "ari", "crm",
        "prproj", "aep", "aepx", "psd", "psb", "lrcat", "lrcat-data",
        "fcpxml", "fcpbundle", "logicx", "band", "blend", "c4d"
    ]

    private static let reviewExtensions: Set<String> = [
        "pdf", "xls", "xlsx", "csv", "numbers", "doc", "docx", "pages",
        "ppt", "pptx", "key", "zip", "7z", "rar", "tar", "gz", "dmg",
        "heic", "tif", "tiff", "ai", "eps", "txt", "md", "xml"
    ]

    private static let classificationRules = [
        "Source and cache-root rules are evaluated before contained file extensions",
        "ChatGPT/Codex file-preview allowlist -> Safe base risk",
        "Other ChatGPT/Codex cache or temporary data -> Review",
        "NOVIS cache or temporary data -> Review until explicitly allowlisted",
        "Generic ~/Library/Caches item without a Safe Allowlist match -> Review",
        "Only named package, browser, Adobe media, runtime, temporary, or verified updater caches may receive Safe base risk",
        "Apple system and daemon caches -> Review / excluded from one-click safe cleanup",
        "All com.openai.* cache/temp paths use the OpenAI/Codex rule before generic cache rules",
        "Downloads/Desktop protected work-file extension -> Protected",
        "Unclassified temporary protected work-file extension -> Protected",
        "Safe cache/temp modified less than one hour ago -> Review",
        "Safe cache for a detected running app -> Review",
        "JSON/PNG/JPG inside a cache do not independently raise its risk"
    ]

    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .creationDateKey,
        .contentModificationDateKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey
    ]

    func scan(options: ScanOptions) async -> ScanReport {
        let runningApplications = await RunningApplicationSnapshot.capture()
        let worker = Task.detached(priority: .userInitiated) {
            Self.performScan(options: options, runningApplications: runningApplications)
        }
        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func performScan(
        options: ScanOptions,
        runningApplications: RunningApplicationSnapshot
    ) -> ScanReport {
        let startedAt = Date()
        let fileManager = FileManager.default
        var diagnostics = ScanDiagnostics(appliedRules: classificationRules)
        let roots = scanRoots(options: options, fileManager: fileManager, diagnostics: &diagnostics)
        var seenPaths = Set<String>()
        var results: [CleanerItem] = []

        scanLoop: for root in roots {
            if Task.isCancelled { diagnostics.wasInterrupted = true; break }
            diagnostics.scannedPaths.append(root.url.path)
            let children: [URL]
            do {
                children = try fileManager.contentsOfDirectory(
                    at: root.url,
                    includingPropertiesForKeys: Array(resourceKeys),
                    options: []
                )
            } catch {
                record(error: error, path: root.url.path, diagnostics: &diagnostics)
                continue
            }

            for child in children {
                if Task.isCancelled { diagnostics.wasInterrupted = true; break scanLoop }
                guard seenPaths.insert(normalizedPath(for: child)).inserted else { continue }
                do {
                    let values = try child.resourceValues(forKeys: resourceKeys)
                    if values.isSymbolicLink == true {
                        diagnostics.symbolicLinksSkipped += 1
                        continue
                    }
                    let (item, summary) = makeItem(
                        at: child,
                        values: values,
                        root: root,
                        fileManager: fileManager,
                        runningApplications: runningApplications,
                        now: startedAt
                    )
                    merge(summary: summary, into: &diagnostics)
                    results.append(item)
                    if Task.isCancelled {
                        diagnostics.wasInterrupted = true
                        break scanLoop
                    }
                } catch {
                    record(error: error, path: child.path, diagnostics: &diagnostics)
                }
            }
        }

        let sorted = results.sorted {
            $0.safety == $1.safety ? $0.size > $1.size : $0.safety < $1.safety
        }
        diagnostics.scannedPaths = unique(diagnostics.scannedPaths)
        diagnostics.inaccessiblePaths = unique(diagnostics.inaccessiblePaths)
        diagnostics.permissionDeniedPaths = unique(diagnostics.permissionDeniedPaths)
        diagnostics.errors = unique(diagnostics.errors)
        diagnostics.unclassifiedItemCount = sorted.filter { $0.source == .unknown }.count
        return ScanReport(
            scannedAt: startedAt,
            duration: Date().timeIntervalSince(startedAt),
            items: sorted,
            diagnostics: diagnostics
        )
    }

    private static func scanRoots(
        options: ScanOptions,
        fileManager: FileManager,
        diagnostics: inout ScanDiagnostics
    ) -> [ScanRoot] {
        let home = fileManager.homeDirectoryForCurrentUser
        var roots: [ScanRoot] = []
        if options.scanDownloads {
            roots.append(ScanRoot(url: home.appendingPathComponent("Downloads", isDirectory: true), source: .downloads, purpose: "使用者下載的檔案", location: "Downloads", kind: .userFolder))
        }
        if options.scanDesktop {
            roots.append(ScanRoot(url: home.appendingPathComponent("Desktop", isDirectory: true), source: .desktop, purpose: "桌面上的檔案", location: "Desktop", kind: .userFolder))
        }
        if options.scanUserCaches {
            roots.append(ScanRoot(url: home.appendingPathComponent("Library/Caches", isDirectory: true), source: .userCache, purpose: "應用程式可重新產生的快取", location: "~/Library/Caches", kind: .explicitCache))
        }
        if options.scanSystemTemporary {
            roots.append(ScanRoot(url: fileManager.temporaryDirectory, source: .systemTemporary, purpose: "macOS 暫存資料", location: "macOS Temporary Folder", kind: .temporary))
        }
        if options.scanAdobeCaches {
            var adobeLocations = [
                "Library/Application Support/Adobe/Common/Media Cache",
                "Library/Application Support/Adobe/Common/Media Cache Files",
                "Library/Application Support/Adobe/Common/Peak Files"
            ]
            // ~/Library/Caches is already aggregated by its direct children. Only add
            // Adobe's nested root when the general user-cache scan is disabled.
            if !options.scanUserCaches {
                adobeLocations.insert("Library/Caches/Adobe", at: 0)
            }
            roots += adobeLocations.map {
                ScanRoot(url: home.appendingPathComponent($0, isDirectory: true), source: .adobeCache, purpose: "Adobe / Premiere 可重新產生的媒體快取", location: $0.replacingOccurrences(of: "Library", with: "~/Library", options: .anchored), kind: .explicitCache)
            }
        }
        return roots
    }

    private static func makeItem(
        at url: URL,
        values: URLResourceValues,
        root: ScanRoot,
        fileManager: FileManager,
        runningApplications: RunningApplicationSnapshot,
        now: Date
    ) -> (CleanerItem, ContentSummary) {
        let isDirectory = values.isDirectory == true
        let summary = contentSummary(at: url, values: values, fileManager: fileManager)
        let isCodexPreview = SafetyClassifier.isCodexPreviewPath(url.path)
        let classification = SafetyClassifier.classify(SafetyClassificationInput(
            url: url,
            rootKind: root.kind,
            rootSource: root.source,
            latestModifiedAt: summary.latestModifiedAt ?? values.contentModificationDate,
            protectedExtension: summary.protectedMatch,
            reviewExtension: summary.reviewMatch,
            runningApplications: runningApplications,
            now: now
        ))
        let source = classification.source
        let purpose: String
        if isCodexPreview {
            purpose = "檔案預覽暫存副本"
        } else if source == .codex {
            purpose = "ChatGPT / Codex 快取或暫存資料"
        } else if source == .adobeCache {
            purpose = "Adobe / Premiere 可重新產生的媒體快取"
        } else {
            purpose = root.purpose
        }
        let item = CleanerItem(
            url: url,
            size: summary.bytes,
            createdAt: values.creationDate,
            modifiedAt: summary.latestModifiedAt ?? values.contentModificationDate,
            source: source,
            purpose: purpose,
            locationDescription: root.location,
            typeDescription: fileTypeDescription(for: url, isDirectory: isDirectory),
            safety: classification.safety,
            isDirectory: isDirectory,
            sourceApp: sourceApp(for: url, source: source),
            matchedRule: classification.matchedRule,
            containedFileCount: summary.fileCount
        )
        return (item, summary)
    }

    private static func contentSummary(at url: URL, values: URLResourceValues, fileManager: FileManager) -> ContentSummary {
        if values.isDirectory != true {
            let ext = url.pathExtension.lowercased()
            return ContentSummary(
                bytes: Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0),
                fileCount: 1,
                protectedMatch: protectedExtensions.contains(ext) ? ext : nil,
                reviewMatch: reviewExtensions.contains(ext) ? ext : nil,
                latestModifiedAt: values.contentModificationDate
            )
        }

        var summary = ContentSummary()
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [],
            errorHandler: { path, error in
                summary.inaccessiblePaths.append(path.path)
                summary.errors.append("\(path.path): \(error.localizedDescription)")
                if isPermissionDenied(error) { summary.permissionDeniedPaths.append(path.path) }
                return true
            }
        ) else {
            summary.inaccessiblePaths.append(url.path)
            summary.errors.append("\(url.path): Unable to create directory enumerator")
            return summary
        }

        while let child = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            do {
                let childValues = try child.resourceValues(forKeys: resourceKeys)
                if childValues.isSymbolicLink == true {
                    summary.symbolicLinksSkipped += 1
                    enumerator.skipDescendants()
                } else if childValues.isRegularFile == true {
                    summary.fileCount += 1
                    summary.bytes += Int64(childValues.totalFileAllocatedSize ?? childValues.fileAllocatedSize ?? 0)
                    let ext = child.pathExtension.lowercased()
                    if summary.protectedMatch == nil, protectedExtensions.contains(ext) { summary.protectedMatch = ext }
                    if summary.reviewMatch == nil, reviewExtensions.contains(ext) { summary.reviewMatch = ext }
                }
                if let modified = childValues.contentModificationDate,
                   summary.latestModifiedAt == nil || modified > summary.latestModifiedAt! {
                    summary.latestModifiedAt = modified
                }
            } catch {
                summary.inaccessiblePaths.append(child.path)
                summary.errors.append("\(child.path): \(error.localizedDescription)")
                if isPermissionDenied(error) { summary.permissionDeniedPaths.append(child.path) }
            }
        }
        return summary
    }

    private static func sourceApp(for url: URL, source: ScanSource) -> String {
        switch source {
        case .codex: return "ChatGPT / Codex"
        case .adobeCache: return "Adobe / Premiere"
        case .systemTemporary: return "macOS / Unknown process"
        case .downloads, .desktop: return "User"
        case .userCache: return url.lastPathComponent
        case .unknown: return "Unknown"
        }
    }

    private static func merge(summary: ContentSummary, into diagnostics: inout ScanDiagnostics) {
        diagnostics.symbolicLinksSkipped += summary.symbolicLinksSkipped
        diagnostics.inaccessiblePaths += summary.inaccessiblePaths
        diagnostics.permissionDeniedPaths += summary.permissionDeniedPaths
        diagnostics.errors += summary.errors
    }

    private static func record(error: Error, path: String, diagnostics: inout ScanDiagnostics) {
        diagnostics.inaccessiblePaths.append(path)
        diagnostics.errors.append("\(path): \(error.localizedDescription)")
        if isPermissionDenied(error) { diagnostics.permissionDeniedPaths.append(path) }
    }

    private static func isPermissionDenied(_ error: Error) -> Bool {
        let value = error as NSError
        let cocoaDenied = value.domain == NSCocoaErrorDomain && value.code == NSFileReadNoPermissionError
        let posixDenied = value.domain == NSPOSIXErrorDomain && (value.code == 1 || value.code == 13)
        return cocoaDenied || posixDenied
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func fileTypeDescription(for url: URL, isDirectory: Bool) -> String {
        if isDirectory { return "資料夾" }
        let ext = url.pathExtension
        guard !ext.isEmpty else { return "檔案" }
        return UTType(filenameExtension: ext)?.localizedDescription ?? "\(ext.uppercased()) 檔案"
    }

    private static func normalizedPath(for url: URL) -> String {
        let path = url.standardizedFileURL.path
        return path.hasPrefix("/private/var/") ? String(path.dropFirst("/private".count)) : path
    }
}
