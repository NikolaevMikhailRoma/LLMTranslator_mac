# LLMTranslator_mac

Menu‑bar macOS app. Press ⌘ C C → instant EN↔RU translation bubble. Language choosing automatic.

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
    TranslationBubble.swift                 # UI bubble view
  Translation/
    TranslationService.swift                # High-level service: text → text
    TranslationProvider.swift               # Translation provider protocol
    LanguageDetector.swift                  # Automatic language detection
    ClipboardService.swift                  # Clipboard monitoring
    llm/
      few_shot_examples.json                # Translation examples
  Provider/
    LMStudioProvider.swift                  # LM Studio (OpenAI API compatible)
  Config.swift                              # App configuration
  ClipTranslatorApp.swift                   # App entry point
  AppDelegate.swift                         # Menu-bar, clipboard and popover logic
  settings.json                             # Runtime configuration
```