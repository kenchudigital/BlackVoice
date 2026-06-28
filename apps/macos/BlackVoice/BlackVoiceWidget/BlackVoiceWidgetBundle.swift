//
//  BlackVoiceWidgetBundle.swift
//  BlackVoiceWidget
//
//  Created by Tsz Kan Chu on 28/6/2026.
//

import WidgetKit
import SwiftUI

@main
struct BlackVoiceWidgetBundle: WidgetBundle {
    init() {
        BlackVoiceLog.info(.widget, "BlackVoiceWidgetBundle init")
    }

    var body: some Widget {
        BlackVoiceWidget()
    }
}
