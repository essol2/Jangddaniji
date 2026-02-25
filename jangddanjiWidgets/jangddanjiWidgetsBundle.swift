//
//  jangddanjiWidgetsBundle.swift
//  jangddanjiWidgets
//
//  Created by 이은솔 on 2/25/26.
//

import WidgetKit
import SwiftUI

@main
struct jangddanjiWidgetsBundle: WidgetBundle {
    var body: some Widget {
        jangddanjiWidgets()
        jangddanjiWidgetsControl()
        WalkingLiveActivity()
    }
}
