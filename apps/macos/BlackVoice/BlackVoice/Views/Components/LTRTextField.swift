//
//  LTRTextField.swift
//  BlackVoice
//
//  做咩：強制左至右輸入嘅 AppKit text field（API token 等）。
//  目的：SwiftUI SecureField 喺部分 locale 會變 RTL。
//  維護：其他需要 LTR 嘅欄位可重用。

import AppKit
import SwiftUI

struct LTRTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isSecure: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = isSecure ? NSSecureTextField() : NSTextField()
        configure(field)
        field.stringValue = text
        field.delegate = context.coordinator
        context.coordinator.field = field
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        configure(nsView)
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    private func configure(_ field: NSTextField) {
        field.placeholderString = placeholder
        field.isEditable = true
        field.isBordered = true
        field.isBezeled = true
        field.baseWritingDirection = .leftToRight
        field.alignment = .left
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        if let cell = field.cell as? NSTextFieldCell {
            cell.wraps = false
            cell.isScrollable = true
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        weak var field: NSTextField?

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }
    }
}
