# TaleFork App Store Screenshot Plan

Status: production captures pending. Checked against Apple’s official screenshot specification on August 29, 2026.

## Delivery set

- Platform: iPhone
- Display set: 6.9-inch
- Final size: 1320 × 2868 pixels, portrait
- Format: PNG, RGB, no alpha channel
- Quantity: five screenshots

Apple also accepts 1290 × 2796 and 1260 × 2736 for the 6.9-inch set. The older 1242 × 2688 size remains valid for the 6.5-inch set, but that set is only required when a 6.9-inch set is not supplied.

## Final sequence

1. **FIND YOUR NEXT STORY** — Screening Room with the production catalog loaded and no spinner.
2. **MARK THE MOMENT** — Production player showing the scene-note action while authorized media is visible.
3. **YOUR STORY FIELD NOTES** — A real saved scene note with episode and timestamp.
4. **CHOOSE YOUR EPISODE** — A production drama detail page with its episode list.
5. **WATCH 10 EPISODES FREE** — Episode 10 available and episode 11 visibly locked for TaleFork VIP.

## Upload gates

- Every screenshot must come from the exact release UI and authorized TaleFork catalog.
- No offline fixture names, loading indicators, debug badges, simulator chrome, or desktop background may remain.
- Marketing captions must describe visible, working behavior without unverifiable claims.
- The layout-draft badge is removed only after the source capture passes review.
- Final PNG dimensions, color mode, alpha-channel absence, and readable safe margins must be verified before upload.

## Current local drafts

The five files under `artifacts/app-store/screenshots/drafts-not-for-upload/` are composition studies only. They are intentionally ignored by Git because screenshots 2–5 contain offline fixture data and screenshot 1 still contains a loading-state placeholder. They must not be uploaded to App Store Connect.

## Final-capture authorization

Capturing final production screens requires launching the installed TaleFork app, loading the production catalog and authorized artwork/video, and establishing or refreshing an anonymous device pass. That can create or update a production anonymous-user record and service logs, so final capture waits for explicit user authorization immediately before the run.
