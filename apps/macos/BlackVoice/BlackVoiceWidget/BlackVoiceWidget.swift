//
//  BlackVoiceWidget.swift
//  BlackVoiceWidget
//
//  Created by Tsz Kan Chu on 28/6/2026.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Provider（資料提供者）
// 做咩：WidgetKit 規定一定要有呢個 struct，負責喺唔同時機提供畫 Widget 需要嘅資料。
// 目的：就算 Widget 只係四個掣，系統都要問你攞「一筆 entry」先至畫到出嚟；同 login 無關。

struct Provider: AppIntentTimelineProvider {

    // 做咩：Widget 選擇器（加 Widget 嗰個 gallery）入面顯示嘅假預覽。
    // 目的：要即刻出圖，唔可以等 network 或者讀 database，所以用固定假資料。
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    // 做咩：Widget 啱啱加到桌面嗰陣，系統要快啲畫第一版。
    // 目的：比 timeline 更快；我哋而家 UI 係靜態四個掣，所以同 placeholder 差唔多。
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }

    // 做咩：Widget 喺桌面常駐時，決定顯示咩內容、幾時再刷新。
    // 目的：policy: .never 即係唔自動更新（四個掣唔使每個鐘 refresh）；
    //       之後若要顯示語音狀態 / Agent 名，先至改做定時更新。
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = SimpleEntry(date: Date(), configuration: configuration)
        return Timeline(entries: [entry], policy: .never)
    }
}

// MARK: - SimpleEntry（一筆 Widget 資料）
// 做咩：Provider 交俾 View 嘅資料包。
// 目的：date 係 TimelineEntry 協議規定要有（即使 UI 唔顯示時間）；
//       configuration 係 Edit Widget 設定（之後會放 Text/Voice 預設 Prompt Template）。

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

// MARK: - BlackVoiceWidgetEntryView（Widget 畫面）
// 做咩：真正畫出桌面 Widget 上見到嘅四個掣。
// 目的：BlackVoice Widget 係「遙控器」—— 撳掣開 App 對應功能，唔喺 Widget 入面聊天。

struct BlackVoiceWidgetEntryView: View {
    // 做咩：讀系統話你知而家 Widget 係 small / medium / large 邊種尺寸。
    // 目的：唔同尺寸用唔同排版（細嘅 2×2 grid，大嘅橫排）；同 configuration 無關。
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        // Group：將 switch 兩種 layout 包成一個 View，方便共用 .padding(8)
        Group {
            switch family {
            case .systemMedium, .systemLarge, .systemExtraLarge:
                // 做咩：中 / 大 Widget 四個掣橫排。
                // 目的：闊啲嘅空間橫排易撳、易睇。
                HStack(spacing: 8) {
                    actionButtons
                }
            default:
                // 做咩：細 Widget 用兩欄 grid，四個掣變 2×2。
                // 目的：細尺寸橫排四個會太擠。
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    actionButtons
                }
            }
        }
        .padding(8)
    }

    // 做咩：定義四個掣（Text / Voice / Settings / Close）。
    // 目的：@ViewBuilder 令 HStack 同 LazyVGrid 都可以重用同一組掣，唔使寫兩次。
    @ViewBuilder
    private var actionButtons: some View {
        WidgetActionButton(title: "Text", systemImage: "text.bubble", intent: OpenTextModeIntent())
        WidgetActionButton(title: "Voice", systemImage: "mic.fill", intent: OpenVoiceModeIntent())
        WidgetActionButton(title: "Settings", systemImage: "gearshape", intent: OpenSettingsIntent())
        WidgetActionButton(title: "Close", systemImage: "xmark.circle", intent: CloseAppIntent())
    }
}

// MARK: - WidgetActionButton（可重用掣元件）
// 做咩：一個 Icon + 短 label 嘅掣，撳咗會觸發對應 AppIntent。
// 目的：四個掣樣式一樣，抽成 component 避免重複 code。

struct WidgetActionButton<I: AppIntent>: View {
    let title: String
    let systemImage: String
    let intent: I

    var body: some View {
        // Button(intent:) 係 Widget 專用：撳掣 → 執行 intent → 可以順便開主 App
        Button(intent: intent) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain) // 做咩：唔用系統預設藍色掣樣式，配合 Widget 簡潔外觀
    }
}

// MARK: - BlackVoiceWidget（Widget 註冊）
// 做咩：向 WidgetKit 註冊呢個 Widget 嘅種類、設定 intent、資料 provider 同畫面。
// 目的：kind 係 Widget 唯一 ID；AppIntentConfiguration 支援 Edit Widget 設定（之後加 Prompt Template）。

struct BlackVoiceWidget: Widget {
    let kind: String = "BlackVoiceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            BlackVoiceWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget) // Widget 背景色（macOS 要求）
        }
    }
}
