# RomaSub.AI — UI/UX Audit

**Date:** 2026-06-29
**Scope:** Flutter frontend (`FrontEnd/lib`) — 80 Dart files
**Method:** Reviewed design tokens (`app_colors`, `app_theme`, `app_sizes`) + Dashboard, Sidebar, Projects, Login, and Settings screens. Ran `flutter analyze` and grep'd for token usage. Findings mapped to the UI/UX Pro Max rule set (Accessibility → Charts, priority 1–10).

---

## Summary

The foundation is sound: a clean monochrome aesthetic, real light/dark theming, and good empty/error/loading states on the Projects screen. The problems are **systemic, not cosmetic** — the most important being that a proper design-token system exists but is bypassed almost everywhere.

| # | Finding | Impact | Rule(s) |
|---|---------|--------|---------|
| 1 | Design tokens defined but unused (195 hardcoded colors) | 🔴 High | `color-semantic`, `token-driven-theming` |
| 2 | Icon-only sidebar navigation | 🔴 High | `nav-label-icon` |
| 3 | Navigation destroys back stack (`replace` everywhere) | 🔴 High | `back-stack-integrity`, `state-preservation` |
| 4 | Not responsive / desktop-only layout | 🔴 High | `mobile-first`, `breakpoint-consistency` |
| 5 | Misleading notification bell → opens help dialog | 🟡 Medium | `motion-meaning` / affordance |
| 6 | All-greyscale palette, pure-black primary, no accent | 🟡 Medium | `primary-action`, `visual-hierarchy` |
| 7 | No press / motion feedback (ripple hidden, no transitions) | 🟡 Medium | `press-feedback`, `scale-feedback`, `state-transition` |
| 8 | `flutter analyze`: 53 issues (19 deprecated `withOpacity`) | 🟢 Low | mechanical |
| 9 | Stale `CLAUDE.md` (says InheritedWidget; code is Riverpod) | 🟢 Low | docs |

---

## 🔴 High Impact

### 1. The design system is defined but unused

**Files:** `core/constants/app_colors.dart` (tokens) vs. all screens
**Rule:** `color-semantic` — "Define semantic color tokens, not raw hex in components"; `token-driven-theming`

`AppColors` ships semantic tokens **and** ready-made helpers (`getBackground(isDark)`, `getSurface(isDark)`, `getTextPrimary(isDark)`, etc.). Screens ignore them. Grep finds **195 hardcoded color references** (`Colors.grey.shade400`, `const Color(0xFF2A2A2A)`, `Colors.black`/`Colors.white`) across `lib`. Every screen re-derives its own `isDark ? grey.400 : grey.600` ladder by hand.

**Concrete defect this causes:**
- Dark-mode cards are hardcoded `Color(0xFF2A2A2A)` in ~12 locations (`dashboard_screen.dart:133`, `projects_screen.dart:43`, `settings_screen.dart:293`, `login_screen.dart:71`, …).
- Meanwhile `AppColors.surfaceDark` (`#1A1A1A`) is **defined but never referenced** — so the app effectively has *two* competing dark surfaces. The token file and the rendered UI disagree.
- The `AppTheme` `textTheme`/`cardTheme` is largely dead too, because screens build raw `Container`s with inline `TextStyle`s instead of `Theme.of(context).textTheme.*`.

**Fix:** Route every screen through the `AppColors.getX(isDark)` helpers (or, better, `Theme.of(context).colorScheme` / `textTheme`). Delete the duplicate dark surface. This is invisible to users but is the #1 structural problem — it's what makes every future restyle a 80-file find-and-replace.

### 2. Icon-only sidebar navigation

**File:** `widgets/sidebar/sidebar.dart`
**Rule:** `nav-label-icon` — "Navigation items must have both icon and text label; icon-only nav harms discoverability"

The 100px rail shows icons + `Tooltip` only. Tooltips don't fire on touch devices and force first-time users to guess what each glyph does (Dashboard / Recent Projects / Exports / Feedback / Settings are not all obvious from icons alone).

**Fix:** Add a text label under each icon, or widen the rail to a labelled nav. Keep the active-pill highlight (that part is good).

### 3. Navigation destroys the back stack

**Files:** `widgets/sidebar/sidebar.dart` (all `_MenuItem.onTap`), `dashboard_screen.dart:533` (profile avatar)
**Rule:** `back-stack-integrity`, `state-preservation`

Every top-level nav uses `AppRoutes.replace(...)`. Consequences:
- No back navigation between sections.
- Scroll position, search query, and form state are lost on every switch.
- Browser **back** button breaks on Flutter web.

**Fix:** Use a persistent shell (e.g. `IndexedStack` behind the sidebar) so each section keeps its state, or push routes instead of replacing. The avatar→Settings jump should `push`, not `replace`.

### 4. Not responsive — desktop-only layout

**Files:** `dashboard_screen.dart` (`Row` 6:4 split), `projects_screen.dart`, `settings_screen.dart`
**Rule:** `mobile-first`, `breakpoint-consistency`, `horizontal-scroll`

All main screens are `Row[Sidebar, Expanded[...]]` with fixed flex columns. The Dashboard puts the upload box and status panel side-by-side (flex 6:4); Projects uses a hard-coded 3-column grid. Below ~900px these cramp and overflow. `CLAUDE.md` itself lists "Add responsive design for mobile" as an open TODO.

**Fix:** Introduce breakpoints (e.g. 600 / 905 / 1240). Collapse the sidebar to a bottom nav or drawer on narrow widths; stack the Dashboard panels vertically; make the Projects grid column-count responsive via `LayoutBuilder`.

---

## 🟡 Medium Impact

### 5. Misleading notification bell

**File:** `dashboard_screen.dart:193-218`
**Rule:** affordance / `motion-meaning` (action must match its signifier)

A bell icon **with a red unread badge** opens a static "Guide to Use" help dialog. The badge implies pending notifications that don't exist, and the icon's meaning doesn't match its action.

**Fix:** Either make it a real notifications surface, or swap to a `help_outline` / `info_outline` icon and drop the badge.

### 6. All-greyscale palette reads as unfinished

**File:** `core/constants/app_colors.dart`
**Rule:** `primary-action`, `visual-hierarchy`

Primary is pure `#000000` (HIG/Material both discourage pure black for large surfaces — it can halo and feels harsh), and the "accent" is just `#333333` grey. With no brand color, nothing visually elevates the primary CTA above secondary actions; the only color anywhere is the status green/amber. The result reads closer to a wireframe than a finished product.

**Fix (decision required):** Either (a) keep monochrome but soften `#000` to a near-black (`#0A0A0A`) and let status colors accent, or (b) introduce **one** brand accent used sparingly for primary CTAs and the active nav state.

### 7. No press / motion feedback

**Files:** `projects_screen.dart` `_ProjectTile`, `dashboard_screen.dart` cards
**Rule:** `press-feedback`, `scale-feedback`, `state-transition`

Cards wrap an `InkWell` around an **opaque** `Container`, so the Material ripple is painted *under* the card and never shows. There's no scale/elevation change on press, and theme toggle + status changes snap with no transition.

**Fix:** Put the `InkWell`/`Ink` above the fill (or use `Material` + `InkWell` with a transparent container), add a subtle press scale (0.97) or elevation, and animate the theme/state transitions (150–300ms).

---

## 🟢 Low / Mechanical

### 8. `flutter analyze` — 53 issues

Quick, safe cleanups:
- **19× deprecated `withOpacity`** → `.withValues(alpha: …)` (e.g. `sidebar.dart:34`, `upload_progress_dialog.dart` ×6, `app_snackbar.dart` ×2, `theme_toggle_button.dart` ×2, `transcription_complete_dialog.dart`).
- Unused import `dart:io` in `services/user_service.dart:7`.
- `avoid_print` in `services/google_oauth_desktop_service.dart:101,109`.
- `use_super_parameters`, `unnecessary_underscores`, `use_null_aware_elements` — minor lints.

### 9. Stale documentation

`FrontEnd/CLAUDE.md` describes state management as "Simple `InheritedWidget` pattern" and lists unimplemented features (Settings, social login, file upload) that now exist. The code uses **Riverpod**. Update to prevent misleading future work.

---

## What's already good (keep)

- Light/dark theming is wired end-to-end and toggles live.
- Projects screen has proper **loading / error / empty** states with retry — a model the other screens should copy.
- Consistent 4/8px spacing scale (`AppSizes`) and radius scale.
- Touch targets on the icon buttons (48×48) meet the minimum.
- Auth screens are constrained to a readable max-width.

---

## Recommended order of work

1. **Quick wins** (analyze cleanup + CLAUDE.md) — minutes, de-risks the build.
2. **Visible UX fixes** (#2 sidebar labels, #5 bell, #7 press feedback, #3 back stack) — highest visible payoff.
3. **Token refactor** (#1) — large but fixes the root structural problem.
4. **Responsive** (#4) — largest effort; do once the token layer is clean.
5. **Brand color** (#6) — a product decision to make before or alongside the token refactor.
