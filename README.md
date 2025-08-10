# LLMTranslator_mac

Menu‑bar macOS app. Press ⌘ C C → instant EN↔RU or RU↔EN translation bubble. Language choosing automaticly.

- Monitors clipboard; shows SwiftUI pop‑over at cursor.
- Calls local LLM via LM Studio (OpenAI‑style API on 127.0.0.1:1234).

## Requires

- macOS 13+ on Apple Silicon (GPU)
- Xcode 15 / Swift 5.9
- LM Studio running with an open‑source model

## Entitlements

- `com.apple.security.network.client` – HTTP to localhost
- `com.apple.security.automation.apple-events` – restore focus
- Sandbox clipboard read (no extra entitlement needed)

## Project structure

```
LLMTranslator_mac/
  Bubble/
    TranslationBubble.swift                 # UI пузырь перевода
  Translation/
    TranslationService.swift                # Высокоуровневый сервис: текст -> текст
    TranslationProvider.swift               # Протокол провайдера перевода
    llm/
      qwen3-1.7b/                           # Промпты/инструкции под конкретную модель
        messages.openais-gpt-oss-20b.json
      OpenAI's gpt-oss 20B/                 # Промпты/инструкции под конкретную модель
        messages.qwen3-1.7b.json
  Provider/
    LMStudioProvider.swift                  # Провайдер для LM Studio (OpenAI API совместимый)
    # В будущем: api_offline, openrouter, openai, google, ...
  Config.swift                               # Конфигурация приложения и SettingsStore
  ClipTranslatorApp.swift                    # Точка входа SwiftUI
  AppDelegate.swift                          # Логика меню-бара, буфера и popover
  LLMTranslator-mac-Info.plist               # ATS настройки
  LLMTranslator_mac.entitlements             # Sandbox права
```
