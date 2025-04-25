
# IPTV Client for Apple TV (tvOS) - Product Requirements Document (PRD)

## Executive Summary
The IPTV Apple TV Client is a dedicated **tvOS application** designed to deliver a rich, user-friendly IPTV streaming experience. This PRD outlines the vision for a next-generation IPTV client app combining the best features of iPlayTV and IPTVX while introducing multi-user profiles, robust cloud sync, and a modern UI. The app will be **free**, legally compliant, and optimized for performance.

## Personas
- **Tech-Savvy Cord Cutter**: Power user, multiple playlists, advanced features.
- **Family Viewer**: Needs profiles, parental controls.
- **Casual Viewer**: Simplicity, reliability.

## Competitive Landscape
| Feature              | iPlayTV     | IPTVX       | Proposed App |
|----------------------|-------------|-------------|--------------|
| Price                | Paid        | Freemium    | Free         |
| Multi-Playlist       | Yes         | Yes         | Yes          |
| Profiles             | No          | No          | Yes          |
| iCloud Sync          | Limited     | Yes         | Yes          |
| TV Guide (EPG)       | Yes         | Yes         | Yes          |
| VOD (Movies/Shows)   | Yes         | Yes         | Yes          |
| Parental Controls    | Yes         | Yes         | Yes          |
| PiP                  | No          | Yes         | Yes          |
| Metadata Integration | Limited     | TMDb        | TMDb         |

## Functional Requirements
- Multi-user profiles with PIN.
- Add IPTV playlists (M3U/Xtream), set refresh rates.
- Live TV with categories, EPG, fast zapping.
- VOD browsing (Movies & Shows) with TMDb metadata.
- Full TV Guide grid.
- Favorites & Continue Watching.
- Global Search.
- Parental Controls.
- iCloud Sync.

## Non-Functional Requirements
- Fast startup, smooth navigation.
- AVPlayer + VLCKit for broad streaming support.
- Secure storage (Keychain, CloudKit).
- Full App Store compliance (no content provided, clear disclaimers).
- tvOS-optimized UI, accessibility, localization-ready.

## UX/UI Screen Flows
- Onboarding > Profile Select > Add Playlist > Main Menu.
- Channel browsing & playback.
- TV Guide navigation.
- VOD browsing & detail views.

## Data Model
- Entities: Profile, Playlist, Channel, Program (EPG), Movie, Show, Episode, Favorites, WatchHistory.

## Tech Stack
- **Frontend**: Swift, SwiftUI.
- **Playback**: AVPlayer, VLCKit.
- **Storage**: Core Data, iCloud (CloudKit).
- **Networking**: URLSession, Codable.
- **Metadata**: TMDb, OpenSubtitles.
- **Testing**: Xcode, TestFlight.

## Privacy & Compliance
- No bundled content.
- User-supplied playlists only.
- Strong disclaimers.
- GDPR & App Store compliant.

## Launch & MVP Plan
- 4-month dev cycle.
- Core features: Profiles, playlist mgmt, live TV, VOD, EPG.
- Beta via TestFlight.
- App Store submission with compliance focus.

## Future Roadmap
- Multi-view streaming.
- Advanced EPG features.
- iOS/iPadOS app.
- UI themes, Trakt integration.
- Performance enhancements.

## Sources
- iPlayTV, IPTVX research.
- Apple Developer docs.
- App Store Guidelines.
- User feedback & reviews.

---
*This PRD defines a compliant, feature-rich IPTV client for Apple TV, blending advanced functionality with simplicity and privacy-first design.*
