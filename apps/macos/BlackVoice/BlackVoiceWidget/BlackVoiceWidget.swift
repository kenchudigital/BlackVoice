//
//  BlackVoiceWidget.swift
//  BlackVoiceWidget
//

import WidgetKit
import SwiftUI
import AppIntents

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        makeEntry(configuration: ConfigurationAppIntent(), isRecording: false)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        makeEntry(configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let isRecording = VoiceRecordingStore.isRecording()
        BlackVoiceLog.info(.widget, "Provider.timeline() — isRecording=\(isRecording) family=\(String(describing: context.family))")
        let entry = makeEntry(configuration: configuration, isRecording: isRecording)
        let policy: TimelineReloadPolicy = isRecording
            ? .after(Date().addingTimeInterval(1))
            : .never
        return Timeline(entries: [entry], policy: policy)
    }

    private func makeEntry(configuration: ConfigurationAppIntent, isRecording: Bool? = nil) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            configuration: configuration,
            isRecording: isRecording ?? VoiceRecordingStore.isRecording()
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let isRecording: Bool
}

struct BlackVoiceWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        Group {
            switch family {
            case .systemMedium, .systemLarge, .systemExtraLarge:
                HStack(spacing: 8) {
                    actionButtons
                }
            default:
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    actionButtons
                }
            }
        }
        .padding(8)
    }

    @ViewBuilder
    private var actionButtons: some View {
        WidgetActionButton(title: "Text", systemImage: "text.bubble", intent: OpenTextModeIntent())
        VoiceWidgetButton(isRecording: entry.isRecording)
        WidgetActionButton(title: "Settings", systemImage: "gearshape", intent: OpenSettingsIntent())
        WidgetActionButton(title: "Close", systemImage: "xmark.circle", intent: CloseAppIntent())
    }
}

private struct VoiceWidgetButton: View {
    let isRecording: Bool

    var body: some View {
        Button(intent: OpenVoiceModeIntent()) {
            VStack(spacing: 4) {
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(isRecording ? Color.white : Color.primary, isRecording ? Color.red : Color.primary)
                Text(isRecording ? "Stop" : "Voice")
                    .font(.caption2.weight(isRecording ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(isRecording ? Color.red : Color.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isRecording ? Color.red.opacity(0.22) : Color.clear)
            }
            .overlay {
                if isRecording {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.red.opacity(0.55), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct WidgetActionButton<I: AppIntent>: View {
    let title: String
    let systemImage: String
    let intent: I

    var body: some View {
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
        .buttonStyle(.plain)
    }
}

struct BlackVoiceWidget: Widget {
    let kind: String = "BlackVoiceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            BlackVoiceWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
