import Foundation

private var passed = 0

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("❌ \(message)\n", stderr)
        exit(1)
    }
}

private func item(path: String, source: ScanSource) -> CleanerItem {
    CleanerItem(
        url: URL(fileURLWithPath: path),
        size: 1_024,
        createdAt: nil,
        modifiedAt: nil,
        source: source,
        purpose: "fixture",
        locationDescription: "fixture",
        typeDescription: "資料夾",
        safety: .review,
        isDirectory: true,
        sourceApp: source.rawValue,
        matchedRule: "fixture",
        containedFileCount: 1
    )
}

private func test(_ name: String, _ body: () -> Void) {
    body()
    passed += 1
    print("✅ \(name)")
}

@main
enum OriginKnowledgeRegressionRunner {
    static func main() {
        test("pip has clear high-confidence explanation") {
            let description = OriginKnowledge.description(for: item(
                path: "/Users/test/Library/Caches/pip",
                source: .userCache
            ))
            expect(description.sourceAppTool == "Python / pip", "pip source is incorrect")
            expect(description.confidence == .high, "pip confidence must be High")
            expect(description.deletionImpact.contains("不會移除已安裝"), "pip deletion impact is missing")
        }

        test("Codex cache is identified without claiming all data is rebuildable") {
            let description = OriginKnowledge.description(for: item(
                path: "/Users/test/Library/Caches/com.openai.codex",
                source: .codex
            ))
            expect(description.sourceAppTool.contains("Codex"), "Codex source is incorrect")
            expect(description.confidence == .high, "known OpenAI path confidence must be High")
            expect(description.regeneration.contains("無法保證"), "Codex explanation is not conservative")
        }

        test("Adobe Media Cache explains original media is preserved") {
            let description = OriginKnowledge.description(for: item(
                path: "/Users/test/Library/Application Support/Adobe/Common/Media Cache Files/audio.cfa",
                source: .adobeCache
            ))
            expect(description.sourceAppTool == "Adobe Premiere Pro", "Adobe Media Cache source is incorrect")
            expect(description.confidence == .high, "known Adobe Media Cache confidence must be High")
            expect(description.deletionImpact.contains("不會刪除原始影片"), "Adobe deletion impact is missing")
        }

        test("unknown cache uses a conservative inferred explanation") {
            let description = OriginKnowledge.description(for: item(
                path: "/Users/test/Library/Caches/FooBar",
                source: .userCache
            ))
            expect(description.confidence == .medium, "directory-name-only inference must be Medium")
            expect(description.evidence.contains("Inferred only"), "unknown cache inference basis is missing")
            expect(description.regeneration.contains("無法保證"), "unknown cache explanation must be conservative")
        }

        print("\nAll \(passed) origin knowledge regression tests passed.")
    }
}
