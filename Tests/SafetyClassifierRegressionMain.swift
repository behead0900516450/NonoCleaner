import Foundation

private let referenceNow = Date(timeIntervalSince1970: 2_000_000_000)
private var passed = 0

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("❌ \(message)\n", stderr)
        exit(1)
    }
}

private func classify(
    path: String,
    rootKind: ScanRootKind = .explicitCache,
    rootSource: ScanSource = .userCache,
    modifiedAt: Date? = nil,
    protectedExtension: String? = nil,
    reviewExtension: String? = nil,
    runningApplications: Set<GuardedApplication> = []
) -> SafetyClassificationOutput {
    SafetyClassifier.classify(SafetyClassificationInput(
        url: URL(fileURLWithPath: path),
        rootKind: rootKind,
        rootSource: rootSource,
        latestModifiedAt: modifiedAt ?? referenceNow.addingTimeInterval(-2 * 60 * 60),
        protectedExtension: protectedExtension,
        reviewExtension: reviewExtension,
        runningApplications: RunningApplicationSnapshot(applications: runningApplications),
        now: referenceNow
    ))
}

private func test(_ name: String, _ body: () -> Void) {
    body()
    passed += 1
    print("✅ \(name)")
}

@main
enum SafetyClassifierRegressionRunner {
static func main() {
test("Codex and com.openai.codex classify consistently") {
    let named = classify(path: "/Users/test/Library/Caches/Codex")
    let bundled = classify(path: "/Users/test/Library/Caches/com.openai.codex")
    expect(named.source == .codex && bundled.source == .codex, "Codex source detection differs")
    expect(named.safety == .review && bundled.safety == .review, "Codex cache must be Review")
}

test("NOVIS cache is Review") {
    let result = classify(path: "/Users/test/Library/Caches/NOVIS")
    expect(result.safety == .review, "NOVIS must not be Safe")
}

test("Recent cache is guarded") {
    let result = classify(
        path: "/Users/test/Library/Caches/pip",
        modifiedAt: referenceNow.addingTimeInterval(-30 * 60)
    )
    expect(result.safety == .review, "Recent cache must be Review")
    expect(result.matchedRule.contains("Recently modified cache; excluded from automatic safe cleanup"), "Recent guard missing")
}

test("Running application cache is guarded") {
    let result = classify(
        path: "/Users/test/Library/Caches/Microsoft Edge",
        runningApplications: [.microsoftEdge]
    )
    expect(result.safety == .review, "Running app cache must be Review")
    expect(result.matchedRule.contains("目前 App 正在執行，請關閉後再清理"), "Running guard message missing")
}

test("Adobe cache MP4 does not protect parent cache") {
    let result = classify(
        path: "/Users/test/Library/Application Support/Adobe/Common/Media Cache Files/rendered-media",
        rootSource: .adobeCache,
        protectedExtension: "mp4"
    )
    expect(result.safety == .safe, "Adobe cache parent must not become Protected from contained MP4")
}

test("Downloads MP4 remains Protected") {
    let result = classify(
        path: "/Users/test/Downloads/original.mov",
        rootKind: .userFolder,
        rootSource: .downloads,
        protectedExtension: "mov"
    )
    expect(result.safety == .protected, "Downloads MOV must remain Protected")
}

test("JSON and PNG do not override missing allowlist") {
    let json = classify(path: "/Users/test/Library/Caches/pnpm", reviewExtension: "json")
    let png = classify(path: "/Users/test/Library/Caches/FooBar", reviewExtension: "png")
    let plain = classify(path: "/Users/test/Library/Caches/FooBar")
    expect(json.safety == .safe, "Allowlisted pnpm JSON cache must remain Safe")
    expect(png.safety == plain.safety && png.safety == .review, "PNG must not determine generic cache risk")
}

test("Unknown generic cache is Review") {
    let result = classify(path: "/Users/test/Library/Caches/FooBar")
    expect(result.safety == .review, "Unknown cache must not be Safe")
    expect(result.matchedRule.contains("No Safe Allowlist match"), "Missing allowlist reason")
}

test("Apple daemon cache is Review") {
    let result = classify(path: "/Users/test/Library/Caches/com.apple.PassKit")
    expect(result.safety == .review, "Apple daemon cache must not be Safe")
}

test("Unknown OpenAI cache is Review") {
    let result = classify(path: "/Users/test/Library/Caches/com.openai.sky.CUAService")
    expect(result.source == .codex, "OpenAI path must use OpenAI/Codex source rule")
    expect(result.safety == .review, "Unknown OpenAI cache must not be Safe")
}

test("pip and pnpm package caches are allowlisted") {
    let pip = classify(path: "/Users/test/Library/Caches/pip")
    let pnpm = classify(path: "/Users/test/Library/Caches/pnpm")
    expect(pip.safety == .safe && pnpm.safety == .safe, "Package caches should be Safe")
    expect(pip.matchedRule.contains("Safe Allowlist: pip package download cache"), "pip allowlist reason missing")
}

test("Development runtime caches are allowlisted") {
    let nodeGyp = classify(path: "/Users/test/Library/Caches/node-gyp")
    let homebrew = classify(path: "/Users/test/Library/Caches/Homebrew")
    let playwright = classify(path: "/Users/test/Library/Caches/ms-playwright")
    expect(nodeGyp.safety == .safe && homebrew.safety == .safe && playwright.safety == .safe, "Development runtime allowlist failed")
}

test("Verified Ollama and ChatCut updater caches are allowlisted") {
    let ollama = classify(path: "/Users/test/Library/Caches/ollama")
    let chatcut = classify(path: "/Users/test/Library/Caches/chatcut-desktop-updater")
    let model = classify(path: "/Users/test/.ollama/models")
    expect(ollama.safety == .safe && chatcut.safety == .safe, "Verified updater caches should be Safe")
    expect(model.safety == .review, "Ollama model data must never match the cache allowlist")
}

test("Adobe CFA IMS and Peak Files are allowlisted") {
    let cfa = classify(path: "/Users/test/Library/Application Support/Adobe/Common/Media Cache Files/audio.cfa", rootSource: .adobeCache)
    let ims = classify(path: "/Users/test/Library/Application Support/Adobe/Common/Media Cache Files/index.ims", rootSource: .adobeCache)
    let peak = classify(path: "/Users/test/Library/Application Support/Adobe/Common/Peak Files/audio.pek", rootSource: .adobeCache)
    expect(cfa.safety == .safe && ims.safety == .safe && peak.safety == .safe, "Adobe generated caches should be Safe")
}

test("Codex preview requires old data and closed app") {
    let path = "/private/var/folders/test/T/codex-file-preview-ABC/file.pdf"
    let old = classify(path: path, rootKind: .temporary, rootSource: .systemTemporary)
    let recent = classify(
        path: path,
        rootKind: .temporary,
        rootSource: .systemTemporary,
        modifiedAt: referenceNow.addingTimeInterval(-10 * 60)
    )
    let running = classify(
        path: path,
        rootKind: .temporary,
        rootSource: .systemTemporary,
        runningApplications: [.codex]
    )
    expect(old.safety == .safe, "Old Codex preview with app closed should be Safe")
    expect(recent.safety == .review, "Recent Codex preview must be Review")
    expect(running.safety == .review, "Codex preview while app runs must be Review")
}

print("\nAll \(passed) safety classification regression tests passed.")
}
}
