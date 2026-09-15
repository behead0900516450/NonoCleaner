import Foundation

enum OriginKnowledge {
    static func description(for item: CleanerItem) -> SourceDescription {
        let path = item.url.path.lowercased()
        let components = pathComponents(item.url.path)
        let ext = item.url.pathExtension.lowercased()
        let isCachePath = path.contains("/library/caches/")
        let isAdobeContext = item.source == .adobeCache || path.contains("/adobe/") || path.contains("premiere")

        if isCachePath && components.contains("pip") { return pip }
        if isCachePath && components.contains("pnpm") { return pnpm }
        if isCachePath && components.contains("node-gyp") { return nodeGyp }
        if isCachePath && components.contains("homebrew") { return homebrew }
        if isCachePath && (components.contains("ms-playwright") || components.contains("playwright")) { return playwright }

        if isCodexPreview(path) { return codexPreview }
        if item.source == .codex || components.contains(where: isOpenAIComponent) { return codex }

        if path.contains("/media cache files/") || components.contains("media cache files") ||
            (isAdobeContext && (ext == "cfa" || ext == "ims")) {
            return adobeMediaCache
        }
        if path.contains("/peak files/") || components.contains("peak files") || (isAdobeContext && ext == "pek") {
            return adobePeakFiles
        }
        if components.contains(where: { $0.hasPrefix("adobe camera raw") || $0 == "camera raw" }) {
            return adobeCameraRaw
        }
        if item.source == .adobeCache || path.contains("premiere") { return adobePremiere }

        if components.contains("microsoft edge") || components.contains(where: { $0.hasPrefix("com.microsoft.edgemac") }) {
            return microsoftEdge
        }
        if path.contains("/library/caches/ollama") { return ollamaUpdater }
        if components.contains("chatcut-desktop-updater") { return chatcutUpdater }
        if components.contains("novis") { return novis }
        if components.contains(where: { $0 == "notion" || $0 == "notion.id" || $0.hasPrefix("notion-updater") }) {
            return notion
        }
        if components.contains(where: isAppleComponent) { return appleSystemCache }

        switch item.source {
        case .downloads:
            return userFile(location: "Downloads")
        case .desktop:
            return userFile(location: "Desktop")
        case .systemTemporary:
            return unknownTemporary
        case .userCache:
            return inferredApplicationCache(name: item.name)
        case .adobeCache:
            return adobePremiere
        case .codex:
            return codex
        case .unknown:
            return unknown
        }
    }

    private static let pip = SourceDescription(
        sourceAppTool: "Python / pip",
        sourceType: "開發工具套件下載快取",
        overview: "這是 Python 的 pip 套件管理工具所建立的下載快取。它用來避免重複下載已取得的套件。",
        purpose: "暫存 pip 下載的 Python 套件與 HTTP 回應。",
        creationReason: "執行 pip install、建立 Python 環境或安裝專案依賴時產生。",
        commonContents: ["HTTP download cache", "wheel packages", "downloaded package archives"],
        usageContext: "Codex 建立 Python 專案、Terminal 安裝套件或建立 virtual environment 時可能使用。",
        deletionImpact: "不會移除已安裝的 Python 套件；未來再安裝時可能需要重新下載。",
        regeneration: "會，pip 需要時會重新下載。",
        mayReappear: "會，下次使用 pip 後可能再出現。",
        confidence: .high,
        evidence: "Known path ~/Library/Caches/pip"
    )

    private static let pnpm = SourceDescription(
        sourceAppTool: "Node.js / pnpm",
        sourceType: "開發工具套件快取",
        overview: "這是 pnpm 為 Node.js 套件建立的本機快取。它能加快之後的專案安裝。",
        purpose: "保留套件內容、metadata 與下載驗證資料。",
        creationReason: "執行 pnpm install、pnpm add 或建立 Node.js 專案時產生。",
        commonContents: ["package content store", "metadata", "lockfile verification data"],
        usageContext: "開發 JavaScript / TypeScript 專案或 Codex 安裝 npm 依賴時會用到。",
        deletionImpact: "不會刪除專案原始碼；之後安裝依賴可能需重新下載。",
        regeneration: "會，pnpm 需要時會重建。",
        mayReappear: "會，再次使用 pnpm 後會逐漸累積。",
        confidence: .high,
        evidence: "Known path ~/Library/Caches/pnpm"
    )

    private static let nodeGyp = SourceDescription(
        sourceAppTool: "Node.js / node-gyp",
        sourceType: "開發工具編譯快取",
        overview: "這是 node-gyp 編譯 Node.js 原生模組時使用的下載與建置快取。",
        purpose: "保留 Node.js headers 與原生模組建置資料。",
        creationReason: "安裝含 C/C++ 原生模組的 npm/pnpm 套件時產生。",
        commonContents: ["Node.js headers", "build metadata", "install version markers"],
        usageContext: "安裝需要本機編譯的 Node.js 依賴時使用。",
        deletionImpact: "不會刪除專案；下次編譯可能需重新下載 headers。",
        regeneration: "會。",
        mayReappear: "會，下次 node-gyp 建置時可能再出現。",
        confidence: .high,
        evidence: "Known path ~/Library/Caches/node-gyp"
    )

    private static let homebrew = SourceDescription(
        sourceAppTool: "Homebrew",
        sourceType: "開發工具下載快取",
        overview: "這是 Homebrew 安裝 macOS 軟體與命令列工具時保留的下載快取。",
        purpose: "暫存 formula、cask 與已下載安裝檔。",
        creationReason: "執行 brew install、brew upgrade 或 Homebrew 更新時產生。",
        commonContents: ["downloaded archives", "bottles", "cask installers"],
        usageContext: "透過 Terminal 安裝或更新工具時使用。",
        deletionImpact: "不會移除已安裝的軟體；再安裝時可能需重新下載。",
        regeneration: "會。",
        mayReappear: "會，Homebrew 下次下載時會再建立。",
        confidence: .high,
        evidence: "Known path ~/Library/Caches/Homebrew"
    )

    private static let playwright = SourceDescription(
        sourceAppTool: "Microsoft Playwright",
        sourceType: "開發與瀏覽器測試 runtime cache",
        overview: "這是 Playwright 自動化瀏覽器測試用的瀏覽器與 runtime 副本。",
        purpose: "保留 Chromium、Firefox、WebKit 或 FFmpeg runtime。",
        creationReason: "安裝 Playwright 或首次執行瀏覽器自動化時下載。",
        commonContents: ["Chromium runtime", "headless browser", "FFmpeg runtime"],
        usageContext: "網站測試、截圖、爬取或瀏覽器自動化時使用。",
        deletionImpact: "不會刪除專案；下次執行可能需重新下載大型瀏覽器 runtime。",
        regeneration: "會。",
        mayReappear: "會，Playwright 需要對應版本時會再下載。",
        confidence: .high,
        evidence: "Known path ~/Library/Caches/ms-playwright or Playwright runtime directory"
    )

    private static let codexPreview = SourceDescription(
        sourceAppTool: "ChatGPT / Codex",
        sourceType: "檔案預覽暫存副本",
        overview: "這是 ChatGPT / Codex 為了讓 macOS 開啟或預覽產出檔案而建立的本機暫存副本。",
        purpose: "提供 PDF、文件、圖片或其他產出檔的本機預覽。",
        creationReason: "從 ChatGPT / Codex 開啟、預覽或交付檔案時產生。",
        commonContents: ["PDF preview copies", "document previews", "generated-file previews"],
        usageContext: "使用者點開 AI 產出的檔案，交由 Finder 或其他 macOS App 預覽時使用。",
        deletionImpact: "只移除這台 Mac 的預覽副本；不代表刪除 ChatGPT 對話中的原始內容。",
        regeneration: "需要時會重新建立。",
        mayReappear: "會，再次預覽檔案時可能出現。",
        confidence: .high,
        evidence: "Known temporary path pattern codex-file-preview-*"
    )

    private static let codex = SourceDescription(
        sourceAppTool: "ChatGPT / Codex / OpenAI tool",
        sourceType: "AI 工具快取或暫存資料",
        overview: "這個項目的路徑明確與 OpenAI、ChatGPT 或 Codex 有關。除非符合明確預覽規則，Nono Cleaner 不會假設所有內容都可直接清理。",
        purpose: "可能是 App 快取、下載中繼檔、工具執行暫存或產出副本。",
        creationReason: "使用 ChatGPT / Codex 開啟檔案、執行工具或處理本機資料時產生。",
        commonContents: ["application cache", "temporary downloads", "tool working files"],
        usageContext: "ChatGPT / Codex 仍在執行任務、顯示檔案或操作工作區時可能使用。",
        deletionImpact: "可能造成預覽或本機任務資料需重建；請先關閉相關 App 並確認內容。",
        regeneration: "部分會，但未命中 file-preview 規則時無法保證全部可重建。",
        mayReappear: "可能，再次使用相關功能時可能出現。",
        confidence: .high,
        evidence: "Known OpenAI/Codex path or bundle identifier"
    )

    private static let microsoftEdge = SourceDescription(
        sourceAppTool: "Microsoft Edge",
        sourceType: "瀏覽器快取",
        overview: "這是 Microsoft Edge 為網頁、圖片與網路資源建立的本機快取。",
        purpose: "加快網頁載入，減少重複下載。",
        creationReason: "瀏覽網頁、播放線上媒體或下載網站資源時產生。",
        commonContents: ["web resource cache", "images", "browser network cache"],
        usageContext: "Edge 開啟網頁或背景運作時可能正在使用。",
        deletionImpact: "不會刪除書籤；部分網頁之後會重新下載，首次開啟可能較慢。",
        regeneration: "會。",
        mayReappear: "會，繼續瀏覽網頁就會逐漸建立。",
        confidence: .high,
        evidence: "Known Microsoft Edge cache path or bundle identifier"
    )

    private static let adobeMediaCache = SourceDescription(
        sourceAppTool: "Adobe Premiere Pro",
        sourceType: "專業影音媒體快取",
        overview: "這是 Adobe Premiere Pro 為影片與音訊建立的暫存資料。它不是原始影片，也不是 Premiere Project。",
        purpose: "加快媒體分析、解碼、音訊 conform 與時間軸播放。",
        creationReason: "Premiere 匯入、分析或播放媒體時自動建立。",
        commonContents: [".cfa conformed audio", ".ims media index", "media cache files"],
        usageContext: "打開 Premiere 專案、匯入素材、建立 waveform 或播放時間軸時使用。",
        deletionImpact: "不會刪除原始影片或 Premiere Project；重開專案時可能需重新分析音訊與產生 waveform。",
        regeneration: "會，Premiere 需要時會重建。",
        mayReappear: "會，再次使用對應媒體時會出現。",
        confidence: .high,
        evidence: "Known Adobe Media Cache Files path or .cfa/.ims cache extension"
    )

    private static let adobePeakFiles = SourceDescription(
        sourceAppTool: "Adobe Premiere Pro",
        sourceType: "音訊波形快取",
        overview: "這是 Premiere Pro 顯示音訊波形時使用的 Peak File。",
        purpose: "保留音訊 waveform 的快速讀取資料。",
        creationReason: "Premiere 分析音訊並顯示時間軸波形時產生。",
        commonContents: [".pek", "audio peak data", "waveform cache"],
        usageContext: "開啟含音訊的 Premiere 專案或在時間軸顯示波形時使用。",
        deletionImpact: "不會刪除原始音訊；之後可能需重新建立波形。",
        regeneration: "會。",
        mayReappear: "會，Premiere 再次分析音訊時會出現。",
        confidence: .high,
        evidence: "Known Adobe Peak Files path or .pek extension"
    )

    private static let adobeCameraRaw = SourceDescription(
        sourceAppTool: "Adobe Camera Raw",
        sourceType: "RAW 圖像預覽與處理快取",
        overview: "這是 Adobe Camera Raw 為 RAW 照片預覽與處理建立的快取。",
        purpose: "加快 RAW 照片的預覽、調整與開啟。",
        creationReason: "在 Camera Raw、Photoshop 或 Bridge 開啟 RAW 照片時產生。",
        commonContents: ["RAW preview cache", "image processing cache", "thumbnail data"],
        usageContext: "瀏覽、預覽或編輯 RAW 照片時使用。",
        deletionImpact: "不會刪除 RAW 原始檔或編輯設定；下次開啟照片時可能需重新建立預覽。",
        regeneration: "會。",
        mayReappear: "會，繼續處理 RAW 照片時會出現。",
        confidence: .high,
        evidence: "Known Adobe Camera Raw cache path"
    )

    private static let adobePremiere = SourceDescription(
        sourceAppTool: "Adobe application（可能是 Premiere Pro）",
        sourceType: "Adobe 應用程式快取",
        overview: "這個項目位於 Adobe 快取範圍，但路徑沒有足夠資訊確定是哪一個 Adobe App 或哪種快取。",
        purpose: "可能用於 Adobe App 的預覽、媒體處理或介面資源。",
        creationReason: "使用 Adobe 應用程式時產生。",
        commonContents: ["application cache", "media metadata", "preview data"],
        usageContext: "Adobe App 開啟或處理專案與媒體時可能使用。",
        deletionImpact: "不應視為原始專案，但用途未完全確認；請關閉 Adobe App 後再檢視。",
        regeneration: "可能會，但目前無法保證全部內容。",
        mayReappear: "可能。",
        confidence: .medium,
        evidence: "Inferred from Adobe cache location; exact cache type did not match"
    )

    private static let ollamaUpdater = SourceDescription(
        sourceAppTool: "Ollama Updater",
        sourceType: "應用程式更新下載快取",
        overview: "這是 Ollama 應用程式的更新安裝包快取，不是 Ollama 模型資料。",
        purpose: "保留 Ollama 更新用的下載壓縮檔。",
        creationReason: "Ollama 檢查、下載或準備更新時產生。",
        commonContents: ["Ollama-darwin.zip", "update archives"],
        usageContext: "Ollama 自動更新或準備安裝新版本時使用。",
        deletionImpact: "不會刪除 ~/.ollama/models 的模型；需要更新時可能得重新下載安裝包。",
        regeneration: "會，有更新需求時可重新下載。",
        mayReappear: "會，下次更新時可能出現。",
        confidence: .high,
        evidence: "Verified path ~/Library/Caches/ollama/updates containing Ollama update archive"
    )

    private static let chatcutUpdater = SourceDescription(
        sourceAppTool: "ChatCut Desktop Updater",
        sourceType: "應用程式更新下載快取",
        overview: "這是 ChatCut Desktop 更新程式保留的安裝包與下載資料。",
        purpose: "保留待安裝的更新 ZIP、blockmap 與更新資訊。",
        creationReason: "ChatCut 檢查或下載桌面版更新時產生。",
        commonContents: ["update.zip", "ChatCut arm64 update archive", "blockmap", "update-info.json"],
        usageContext: "ChatCut 更新中或等待安裝更新時使用。",
        deletionImpact: "不會刪除目前已安裝的 ChatCut；未完成的更新可能需重新下載。",
        regeneration: "會，更新程式需要時會重新下載。",
        mayReappear: "會，之後的 App 更新會再建立。",
        confidence: .high,
        evidence: "Verified path ~/Library/Caches/chatcut-desktop-updater and updater artifacts"
    )

    private static let novis = SourceDescription(
        sourceAppTool: "NOVIS",
        sourceType: "應用程式快取（用途未完全分類）",
        overview: "這個資料夾由 NOVIS 建立，但目前沒有足夠證據說明所有內容都可重新產生。",
        purpose: "可能用於 NOVIS 的介面資源、下載或處理中繼資料。",
        creationReason: "使用 NOVIS 時由 App 建立。",
        commonContents: ["application cache", "temporary working data", "unclassified app data"],
        usageContext: "NOVIS 開啟或執行處理任務時可能使用。",
        deletionImpact: "影響無法完全確定；請關閉 NOVIS 並檢視內容後再處理。",
        regeneration: "未知，不應假設全部可重建。",
        mayReappear: "可能。",
        confidence: .high,
        evidence: "Known path ~/Library/Caches/NOVIS; content semantics are not allowlisted"
    )

    private static let notion = SourceDescription(
        sourceAppTool: "Notion",
        sourceType: "應用程式快取或更新資料",
        overview: "這個項目的路徑與 Notion 應用程式有關。可能是頁面資源、離線快取或更新程式資料。",
        purpose: "加快 Notion 載入，或支援桌面 App 更新。",
        creationReason: "使用 Notion Desktop、瀏覽頁面或下載更新時產生。",
        commonContents: ["web application cache", "offline resources", "updater files"],
        usageContext: "Notion 開啟、背景同步或更新時可能使用。",
        deletionImpact: "可能需重新下載頁面資源或更新檔；未完全分類時請保守處理。",
        regeneration: "多數可能會，但不保證全部。",
        mayReappear: "會或可能。",
        confidence: .high,
        evidence: "Known Notion path or bundle identifier"
    )

    private static let appleSystemCache = SourceDescription(
        sourceAppTool: "macOS / Apple 系統服務",
        sourceType: "系統服務快取",
        overview: "這是 macOS 或 Apple 內建服務產生的快取。容量通常不大，但系統服務可能正在使用。",
        purpose: "支援 Spotlight、iCloud、PassKit 或其他 macOS 背景服務。",
        creationReason: "macOS 背景服務運作、索引、同步或處理系統資料時產生。",
        commonContents: ["system daemon cache", "indexes", "sync metadata"],
        usageContext: "登入 macOS 後的日常使用與背景系統服務中可能持續使用。",
        deletionImpact: "可能導致系統服務重建索引或重新同步；Nono Cleaner 不將它納入一鍵低風險清理。",
        regeneration: "可能會，但不建議為了少量空間主動清理。",
        mayReappear: "會，系統服務會持續使用。",
        confidence: .high,
        evidence: "Known Apple bundle identifier or system-service path"
    )

    private static let unknownTemporary = SourceDescription(
        sourceAppTool: "無法確認的 App 或 macOS 程序",
        sourceType: "暫存資料",
        overview: "這個項目位於 macOS 暫存區，但單從路徑無法確認是哪個 App 建立。",
        purpose: "可能是下載中繼檔、處理工作檔或短期快取。",
        creationReason: "某個 App 或系統服務執行任務時建立。",
        commonContents: ["temporary files", "working data", "partial downloads"],
        usageContext: "建立它的程式仍在執行時可能會用到。",
        deletionImpact: "無法完全確定；如果正在使用，刪除可能影響未完成的任務。",
        regeneration: "未知。",
        mayReappear: "可能。",
        confidence: .unknown,
        evidence: "Temporary location only; no known app or allowlist rule matched"
    )

    private static let unknown = SourceDescription(
        sourceAppTool: "未知",
        sourceType: "未分類資料",
        overview: "Nono Cleaner 目前無法只根據這個路徑可靠地說明它的來源與用途。",
        purpose: "用途未知。",
        creationReason: "無法確認是哪個 App 或操作建立。",
        commonContents: ["未分類內容"],
        usageContext: "請檢查檔名、路徑與 Finder 資訊後再決定。",
        deletionImpact: "未知；不應在未確認用途前刪除。",
        regeneration: "未知。",
        mayReappear: "未知。",
        confidence: .unknown,
        evidence: "No known path, bundle identifier, or origin rule matched"
    )

    private static func inferredApplicationCache(name: String) -> SourceDescription {
        SourceDescription(
            sourceAppTool: name.isEmpty ? "未知 App" : name,
            sourceType: "可能的應用程式快取",
            overview: "這個資料夾位於 ~/Library/Caches，名稱看起來像某個 App 的快取，但 Nono Cleaner 目前沒有對應的已知來源規則。",
            purpose: "可能用於加快 App 或保留中繼資料。",
            creationReason: "可能是同名 App 或相關工具運作時建立。",
            commonContents: ["application cache", "metadata", "temporary resources"],
            usageContext: "對應 App 啟動或處理資料時可能使用。",
            deletionImpact: "無法只由資料夾名稱保證影響；請確認對應 App 與內容。",
            regeneration: "可能，但無法保證全部可重建。",
            mayReappear: "可能。",
            confidence: .medium,
            evidence: "Inferred only from directory name under ~/Library/Caches"
        )
    }

    private static func userFile(location: String) -> SourceDescription {
        SourceDescription(
            sourceAppTool: "使用者或未知 App",
            sourceType: "使用者檔案",
            overview: "這是位於 \(location) 的使用者檔案或資料夾。僅從位置無法判斷當初是由哪個 App 建立。",
            purpose: "可能是下載、工作檔、匯出成果或使用者保留的資料。",
            creationReason: "由使用者儲存、瀏覽器下載或某個 App 匯出。",
            commonContents: ["documents", "downloads", "project or exported files"],
            usageContext: "日常工作、交付、分享或編輯時可能使用。",
            deletionImpact: "可能直接移除使用者保留的唯一副本；請先確認內容。",
            regeneration: "未知，不應假設可重建。",
            mayReappear: "未知。",
            confidence: .unknown,
            evidence: "Known user location \(location), but creating app is unknown"
        )
    }

    private static func pathComponents(_ path: String) -> [String] {
        path.split(separator: "/").map { String($0).lowercased() }
    }

    private static func isCodexPreview(_ path: String) -> Bool {
        pathComponents(path).contains {
            $0.hasPrefix("codex-file-preview-") ||
                $0.hasPrefix("chatgpt-file-preview-") ||
                $0.hasPrefix("codex-preview-")
        }
    }

    private static func isOpenAIComponent(_ value: String) -> Bool {
        value == "codex" || value == "chatgpt" ||
            value.hasPrefix("com.openai.") || value.hasPrefix(".com.openai.")
    }

    private static func isAppleComponent(_ value: String) -> Bool {
        value.hasPrefix("com.apple.") || value == "passkit" ||
            value.contains("spotlight") || value.contains("icloud")
    }
}
