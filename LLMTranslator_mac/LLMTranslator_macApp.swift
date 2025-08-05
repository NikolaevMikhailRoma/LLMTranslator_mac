//
//  LLMTranslator_macApp.swift
//  LLMTranslator_mac
//
//  Created by admin on 05.08.2025.
//

import SwiftUI
import AppKit

@main
struct TranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {          // скрываем главное окно
        Settings { EmptyView() }    // нужно, чтобы проект собирался
    }
}
