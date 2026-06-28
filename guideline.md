# BlackVoice 維護指南

本文件說明 macOS App + Widget 專案結構、資料流、以及日常改 code 時要改邊啲 file。

---

## 1. 專案結構

```text
apps/macos/BlackVoice/
├── Shared/                         # 主 App + Widget 共用（必須兩邊 target 都 compile）
│   ├── AppAction.swift             # AppAction enum + AppActionStore（App Group 通訊）
│   ├── WidgetActionIntents.swift   # Widget 四個掣嘅 AppIntent
│   ├── ConfigurationAppIntent.swift
│   └── BlackVoiceLog.swift         # Debug log
├── BlackVoice/                     # 主 App
│   ├── BlackVoiceApp.swift         # 入口：WindowGroup + MenuBarExtra
│   ├── App/
│   │   ├── AppDelegate.swift       # 生命週期、URL、Widget action 接收
│   │   ├── AppNavigationState.swift# 導航 + 主視窗 show/hide
│   │   └── BlackVoiceShortcuts.swift
│   ├── Views/                      # SwiftUI UI
│   ├── Models/
│   ├── Info.plist                  # URL scheme: blackvoice://
│   └── BlackVoice.entitlements     # App Group
├── BlackVoiceWidget/               # Widget Extension
│   ├── BlackVoiceWidget.swift
│   ├── BlackVoiceWidgetBundle.swift
│   └── BlackVoiceWidget.entitlements
└── BlackVoice.xcodeproj
```

**規則：**

- 兩邊 target 共用嘅 code 放 `Shared/`
- 只主 App 用嘅放 `BlackVoice/App/` 或 `BlackVoice/Views/`
- 只 Widget 用嘅放 `BlackVoiceWidget/`
- **唔好手改** `project.pbxproj`（用 Xcode 加 target / capability）；加 `.swift` 放 `Shared/` 或 sync folder 通常自動 sync

---

## 2. Widget 掣 → 主 App 資料流

```text
撳 Widget 掣
  → WidgetActionIntents.perform()
  → AppActionStore.setPending()  （寫入 Group Container 檔案 pending_action.txt）
  → Darwin notify
  → AppDelegate.consumePendingWidgetAction()
  → AppNavigationState.apply(action:)
```

| 掣 | AppAction | 行為 |
|----|-----------|------|
| Text | `.chat` | 開主視窗 → Chat 頁 |
| Voice | `.voice` | **唔 activate、唔 openWindow** → 只 hide 主視窗 |
| Settings | `.settings` | 開主視窗 → Settings 頁 |
| Close | `.close` | `terminate` 退出 App |

**Voice 唔閃窗嘅關鍵：**

1. `WindowGroup.defaultLaunchBehavior(.suppressed)` — App 啟動時唔 auto-show 主視窗
2. `AppDelegate` 對 `.voice` 只 call `applyVoiceMode()`（唔 activate）
3. 只有 Text / Settings 會 `openWindow(id: "main")`

---

## 3. Deep Link（備用路徑）

Terminal 測試：

```bash
open "blackvoice://settings"
```

- URL 由 **AppDelegate** 統一處理（`handleGetURL` + `application(_:open:)`）
- 解析成 `AppAction` → `AppNavigationState.handle(url:)`
- **唔用** SwiftUI `.onOpenURL`（避免同 AppDelegate 重複）

---

## 4. 主視窗 show / hide

| 情況 | 機制 |
|------|------|
| User 關咗主視窗，App 留 Menu Bar | `MenuBarMenuView` 註冊 `openWindow(id: "main")` |
| Widget Text / Settings | `showMainWindows()` → 若 0 window 就 `openWindow` |
| Widget Voice | 只 `orderOut`，**唔** openWindow |
| Menu Bar icon | 常駐；Quit 喺 `MenuBarMenuView` |

---

## 5. 加新 Widget 掣（checklist）

1. `Shared/AppAction.swift` — 加 `case`
2. `Shared/WidgetActionIntents.swift` — 加 `AppIntent` struct
3. `BlackVoiceWidget/BlackVoiceWidget.swift` — 加 `WidgetActionButton`
4. `AppNavigationState.apply(action:)` — 加 case 處理
5. Clean Build → 刪除舊 Widget → 重新加入桌面

---

## 6. App Group & Signing

- Group ID：`group.kenchuhk.BlackVoice`
- 兩個 target 都要 **Signing & Capabilities → App Groups**
- 需要 **Development Team**（Apple ID），唔可以用 Sign to Run Locally
- 改 Group ID 要同步：`AppAction.swift`（AppActionStore）+ 兩個 `.entitlements`

---

## 7. Log 除錯

Xcode Console filter：`BlackVoice`

| Category | 意思 |
|----------|------|
| `intent` | Widget perform / setPending |
| `app` | 主 App 導航、視窗 |
| `deeplink` | URL scheme |

- **Debug**：`print` + `os.Logger`
- **Release**：只有 `os.Logger`（Console.app 仍睇到）

---

## 8. Icons

```bash
./scripts/generate-icons.sh
```

詳見 `docs/MACOS_ICONS.md`。改完要 Clean Build + `killall Dock`。

---

## 9. 分發（DMG / GitHub）

| 方式 | 要求 |
|------|------|
| GitHub 源碼 | 朋友自己 Xcode build + 簽名 |
| .dmg 俾熟人 | Development 簽名 + 右鍵 Open |
| .dmg 公開發布 | **Developer ID** + **Notarize**（$99/年） |

```bash
# Archive 後 export .app，再：
mkdir -p dist
hdiutil create -volname "BlackVoice" -srcfolder "path/to/BlackVoice.app" -ov -format UDZO "dist/BlackVoice.dmg"
```

---

## 10. 常見問題

| 現象 | 檢查 |
|------|------|
| Widget 掣無反應 | App Group entitlements、兩邊 Team 一致 |
| 只開 App 唔導航 | Console 有冇 `AppActionStore.setPending` / `consumePending` |
| 主 App 開咗但冇視窗 | openWindow 喺 **MenuBarLabelView**（label），唔係 MenuBarMenuView（下拉） |
| CFPrefs 警告 | 已改用 **檔案** 傳 action，唔用 UserDefaults；container path 有 log 即 OK |
| Close 無反應 | `AppDelegate` Darwin observer 有 register |
| 重複 log / 重複 action | `shouldSkipDuplicate` 350ms debounce |

---

## 11. Phase 1 之後預期改動

- `Views/Pages/ChatView.swift` — 聊天 UI
- Settings + SQLite — API key 等
- Widget 顯示狀態 — 改 `Provider.timeline` policy

改 UI 唔使動 Widget 通訊架構，除非加新掣。
