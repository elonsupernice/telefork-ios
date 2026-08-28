# TaleFork App Store Connect Metadata — English

Status: Release draft. Bracketed values require the account owner’s confirmed business details or the final App Store Connect subscription price before submission.

## App identity

- App name: `TaleFork`
- Subtitle: `Short Drama Scene Notes`
- Primary language: English (U.S.)
- Bundle ID: `com.talefork.storypaths`
- SKU: `talefork-ios-1`
- Primary category: Entertainment
- Secondary category: None
- Version: `1.0.0`
- Copyright: `© 2026 [LEGAL ENTITY OR INDIVIDUAL SELLER NAME]`

## Promotional text

Watch vertical short dramas, mark the moments that matter, and return to an exact scene whenever you want.

## Description

TaleFork brings short-drama viewing and personal scene notes into one focused experience.

Discover a story on the Screening Room, watch it in a vertical player, and mark a turning point, memorable line, clue, or scene to revisit. Each scene note keeps the drama, episode, exact timestamp, and an optional note, so you can return to the same moment later.

Use your Watchlist to organize saved dramas and viewing history. Adjust appearance, haptics, motion, and autoplay in Story Studio. Scene notes, viewing progress, saved dramas, history, and preferences are stored on your current device.

Key features:

- Curated vertical short-drama catalog and search
- Exact-timestamp scene notes while watching
- Four note types: turning point, quote, clue, and rewatch
- Resume a saved moment in its original episode
- Separate Watchlist, viewing history, and scene-note spaces
- English, Japanese, Simplified Chinese, and Traditional Chinese interfaces
- No advertising and no third-party payment SDKs

Episodes 1–10 of each available drama are free to watch. Episode 11 and later require TaleFork VIP, a single weekly auto-renewable subscription purchased through Apple. The purchase screen displays the localized price, renewal period, Restore Purchases, Privacy Policy, and Terms of Use before confirmation.

Subscription price: `[CONFIRM THE EXACT ENGLISH APP STORE PRICE]` per week, automatically renewing until cancelled.

## Keywords

`vertical video,story moments,episode tracker,watchlist,plot notes,dialogue,rewatch`

## URLs planned for GitHub Pages

- Support URL: `https://elonsupernice.github.io/telefork-ios/`
- Marketing URL: `https://elonsupernice.github.io/telefork-ios/`
- Privacy Policy URL: `https://elonsupernice.github.io/telefork-ios/privacy-policy.html`
- Terms of Use URL: `https://elonsupernice.github.io/telefork-ios/terms-of-use.html`

These URLs must not be entered in App Store Connect until the pages are published and verified without authentication.

## App Review contact

- First name: `[REQUIRED]`
- Last name: `[REQUIRED]`
- Phone: `[REQUIRED, INCLUDING COUNTRY CODE]`
- Email: `[REQUIRED]`

## Review notes

TaleFork does not require a phone number, password, or user-created account. On first launch, the app establishes an anonymous device pass so the reviewer can browse the online catalog immediately.

Core feature test path:

1. Open Screening Room and select any drama with more than one episode.
2. Play an episode from 1 through 10; no purchase is required.
3. In the player, choose “Mark This Scene.”
4. Select a note type, optionally enter a note, and save it.
5. Open Scene Notes and choose the saved item to return to the recorded episode and timestamp.

Episodes 1–10 are free. Episode 11 and later display a lock and open the Apple StoreKit subscription screen. TaleFork offers only one weekly auto-renewable product: `com.talefork.storypaths.vip.weekly`. The subscription screen shows Apple’s localized price and includes Restore Purchases, Privacy Policy, and Terms of Use.

Scene notes, progress, favorites, history, and preferences are stored on the device. The Settings screen provides deletion of the current anonymous service identity and local app data. No external payment link, advertising SDK, or tracking SDK is included.

## App Privacy answers from the current client and server source

- Tracking: No.
- Third-party advertising: No.
- Device ID: Collected, linked to the device identity, used for App Functionality, and not used for tracking. The service stores a salted hash of the app-generated installation seed.
- Product Interaction: Collected, linked to the anonymous device identity, used for App Functionality, and not used for tracking. The service stores the latest authenticated service-access time.
- Search History: Not collected under Apple’s definition. Search text is transmitted to service the request in real time but is not persisted in the TaleFork application database.
- Purchase History: Not collected by TaleFork. Apple processes StoreKit purchases and the app reads verified entitlement state.
- Diagnostics/IP address: pending production-operator confirmation. Nginx forwards client IP headers and may retain access logs; the exact deployed log destination and retention period must be confirmed before finalizing the questionnaire.

Do not finalize the App Privacy questionnaire until the production log-retention fact matches the public privacy policy and deployed behavior.

## Submission selections pending account access

- Exact seller/copyright name
- App Review contact details
- Content-rights declaration and age-rating questionnaire
- Final subscription price text for the last description line
- App Store Connect app numeric Apple ID
- TaleFork Apple Developer Team ID
- App Store Connect API key integration for Codemagic
