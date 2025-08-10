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

