# Auth Redesign — Split Hero Login / Sign Up

**Date:** 2026-07-21
**Branch:** `newLogin`
**Goal:** Reshape the sign-in and sign-up screens to match the provided mockup
(split layout: photographic branded hero on the left, quiet form on the right).

## Decisions (confirmed with user)

1. **Left panel** — *Faithful photo hero.* A full-bleed background photograph with
   the logo lockup, tagline, feature pills, demo caption card, and quote rendered
   as **real Flutter widgets** on top (crisp, responsive, localizable). Replaces the
   in-progress `CaptionStage` as the branded panel.
2. **Hero image source** — temporary placeholder cropped + softened from the mockup
   (`assets/images/auth_hero.jpg`); wired as a **single swappable asset** so the
   user's future clean photo is a one-file replace.
3. **Social auth** — *Google only.* Real multi-colour Google "G". No GitHub button
   (backend does not support it — showing it would be dishonest UI).
4. **Structure** — *Keep two routed screens* (`/login`, `/signup`), restyle both.
   The tab bar is a **Log In / Sign Up switcher** that navigates between the routes.
5. **Remember me** — *Included and wired.* Controls whether the session survives a
   cold app restart. Unchecked ⇒ stored session cleared on next `initialize()`.

## Components

### `widgets/auth/auth_hero_panel.dart` (new) — replaces `caption_stage.dart` usage
- Full-bleed `Image.asset(AppAssets.authHero, fit: BoxFit.cover)` + dark scrim
  gradient for legibility (top-left for the lockup, bottom for the quote).
- Overlay column: brand lockup (logo mark + "RomaSub" / ".AI" teal) → short teal
  underline → tagline "Urdu Speech to Roman Urdu Subtitles" → three feature pills
  (Accurate / Urdu ASR · Smart / Transliteration · Powerful / Editor) → spacer →
  dual-script demo card ("main theek hoon" / "میں ٹھیک ہوں") → spacer → quote.
- `compact` variant for narrow screens: slim band (lockup + tagline).
- Always dark (a hero photo is dark regardless of app theme).

### `widgets/auth/auth_tab_switcher.dart` (new)
- Two labels, teal underline on the active one; tapping the inactive navigates to
  the other route (`AppRoutes.to(signup)` / `AppRoutes.replace(login)`).

### `widgets/auth/auth_shell.dart` (edit)
- Left = `AuthHeroPanel`. Right = theme toggle + header (title + "…continue to
  RomaSub.AI" with the brand in teal) + `AuthTabSwitcher` + `form` slot.
- `GoogleAuthButton` gets a real colour "G" (small `CustomPainter`).
- New param: `activeTab` (login | signup).

### `widgets/auth/auth_text_field.dart` (edit)
- Add `hintText` + `floatingLabel` (default true). When false, the field shows a
  hint and the **label is rendered above** by the screen (matches mockup).

### `screens/auth/login_screen.dart` (edit)
- Order per mockup: Google → "or" → Email (label above) → Password (label above +
  inline "Forgot password?") → Remember me → Log In → "Don't have an account? Sign up".
- `login(email, pw, rememberMe: _rememberMe)`.

### `screens/auth/signup_screen.dart` (edit)
- Same chrome; fields: First/Last → Email → Password → Confirm → Terms → Create
  account → "Already have an account? Log in".

### Remember-me wiring
- `storage_service.dart`: `saveRememberMe(bool)` / `getRememberMe()` (prefs, default
  `true`); reset to default in `clearAll()`.
- `auth_provider.dart`: `login(..., {bool rememberMe = true})` persists the flag;
  `initialize()` clears the stored session when the flag is `false`. Mirror the new
  `login` signature on `_LoadingAuthNotifier`.

## Data flow
Unchanged auth flow (`AuthService` → `StorageService` → `AuthState`). Only additions:
a persisted `remember_me` bool and its check on startup.

## Testing
- Unit test for remember-me: `initialize()` clears session when flag is false, keeps
  it when true. (`flutter analyze` + `dart format` clean; manual visual pass.)

## Out of scope
GitHub OAuth, a real R-waveform logo asset (uses existing logo/icon fallback),
mobile-first responsive rework beyond the existing split/stack breakpoint.
