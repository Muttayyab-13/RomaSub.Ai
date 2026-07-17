# RomaSub.AI — Product Overview

*A design brief for the frontend. Describes what the product is, who uses it, what every screen must accomplish, and which constraints a design cannot contradict.*

---

## 1. What RomaSub.AI is

**RomaSub.AI turns Urdu speech into Roman Urdu captions.**

The name is literal: **Roma**nization + **Sub**titles. This is transliteration, not translation. The words stay Urdu; only the script changes. "میں ٹھیک ہوں" becomes "main theek hoon" — not "I am fine."

That distinction is the whole product. A large share of Pakistani audiences read Urdu far more comfortably in Latin script than in native Nastaʿlīq — it is the script they type in, message in, and search in every day. Yet virtually every automatic captioning tool offers exactly two outputs: native Urdu script, or an English translation. Neither is what this audience wants. RomaSub.AI fills that gap.

### The three problems it solves

1. **General ASR outputs Nastaʿlīq.** Correct, but slower to read for the target audience, especially at caption speed where a viewer has a couple of seconds per line.
2. **Generic transliterators mangle loanwords and names.** Spoken Urdu is saturated with English words — "laptop", "hospital", "computer", "mobile" — and Pakistani proper nouns like "Muhammad" and "Imran". Naive phonetic transliteration turns these into unreadable approximations. RomaSub.AI ships curated dictionaries of **1,041 English loanwords** and **189 Pakistani names** that bypass the model entirely, so "ہسپتال" comes out as "hospital", spelled the way a reader expects.
3. **Manual Roman Urdu subtitling is slow and inconsistent.** Roman Urdu has no single official spelling standard. Two people captioning the same video produce different text. The model enforces one convention across a whole file.

**In one line:** Urdu audio in, readable and convention-consistent Roman Urdu captions out, with a human editor for the last mile.

### Context

A final-year project (BS Software Engineering, 2022–2026) at COMSATS University Islamabad, Abbottabad Campus, by Muttayyab Abdurrehman, Muhammad Hashir, and Muneeb Khan, supervised by Dr. Osman Khalid. MIT licensed. It is a real working system, not a prototype: a FastAPI backend with a fine-tuned M2M100 transliteration model, Whisper ASR, and a Flutter client.

---

## 2. Who uses it, and what for

**Content creators and subtitlers** — vloggers, drama and podcast clippers, social media editors. They have finished Urdu media and need captions their audience will actually read. They care about turnaround time and about not having to fix the same word fifty times. This is the primary user; the product is shaped around them.

**Students and educators** — captioning recorded Urdu lectures for study, accessibility, or searchability. They arrive with long files (an hour or more) and lower tolerance for a slow pipeline. They are more likely to want to *watch while it processes* than to sit through a progress bar.

**Viewers who prefer Roman Urdu** — the ultimate beneficiary. They never open the app. They receive an exported file or a captioned video. Every design decision in the editor eventually serves this person's reading experience.

### The jobs they open the app to do

- *"I have a video. Give me Roman Urdu captions I can ship."* — the main loop.
- *"The model got a few words wrong. Let me fix them without redoing everything."* — the editor loop.
- *"I need this as a burned-in video for Instagram, not an SRT file."* — the export loop.
- *"This is an hour long. I don't want to wait — let me start watching now."* — the realtime loop.
- *"Where's that project from last week?"* — the retrieval loop.

---

## 3. The pipeline, as the user feels it

The user's mental model is a straight line: **upload → wait → edit → export.** Everything else is machinery they should not have to think about.

What actually happens:

| Step | What the user sees | What happens underneath |
|---|---|---|
| Upload | A file picker or drop zone, real progress | File stored, gets an ID |
| Extract audio | "Extracting audio…" | FFmpeg pulls a 16 kHz mono track (skipped for audio-only files) |
| Transcribe | "Transcribing audio…" | Whisper, locked to Urdu, produces timed segments |
| Transliterate | "Transliterating to Roman Urdu…" | The seven-layer pipeline (below) |
| Done | A completion dialog | A subtitle project is created automatically |
| Edit | The editor | Segment-level corrections, auto-saved |
| Export | A download | SRT, VTT, TXT, or a captioned MP4 |

Two things about this the design must respect.

**Transliteration is not a user action.** It happens automatically after transcription. There is no "now transliterate" button and there should not be one. Likewise, the subtitle project creates itself — the user never "starts a project."

**The transcribing progress bar is an estimate.** The backend gives no percentage for ASR, so the client animates against a rough time estimate. It is honest about direction, not about precision. Don't design UI that implies exact knowledge of remaining time.

### The seven-layer transliteration pipeline

This is the technical core, and worth understanding because it explains the product's quality claim:

1. Whisper ASR produces Urdu text
2. **Loanwords and names are matched and set aside** (greedy longest-match, up to bigrams, with Urdu suffix stripping)
3. Text is normalized (folding Arabic presentation forms — ﮨﮯ → ہے)
4. **M2M100 transliterates** the remainder (fine-tuned, with a custom Roman Urdu target token)
5. The set-aside loanwords and names are **reinserted at their original positions**
6. Fuzzy post-processing catches near-misses
7. **Optional LLM refinement** polishes the result

Every layer degrades gracefully. If refinement is unavailable, you get layer 6's output. If the hosted model is down, it falls back to local. **The user always gets a result.** This fallback philosophy is worth a quiet nod in the design — the app should never present a dead end.

### The fork: batch vs. realtime

This is a genuine product fork and the design has to express it.

**Batch** is the default. Upload, wait, get everything, edit.

**Realtime** streams captions as they are produced. Audio is chunked into 30-second windows with 2 seconds of overlap. Once **three chunks are buffered**, playback begins and captions appear as they finish. The user watches a video that is still being processed. If they seek forward, the chunks around the seek target jump the queue.

Realtime is offered as an escape hatch *during* the wait — the upload dialog carries a "Skip wait — Watch with Live Subtitles" affordance while extracting, transcribing, or transliterating. It is not a separate mode chosen up front; it is a way out of a wait that turned out to be longer than expected. That framing matters: it's the answer to impatience, not a parallel product.

Realtime moves through: connecting → buffering → streaming → complete. When it completes, it offers a door into the editor.

---

## 4. Hard constraints

These are product facts, not style preferences. A mockup that contradicts one of these describes software that doesn't exist.

### Bidirectional text is unavoidable

The editor shows **both scripts at once**: native Urdu (right-to-left, read-only) and Roman Urdu (left-to-right, editable). They sit side by side. This is the single most demanding layout requirement in the product, and it is not optional — the Urdu is the reference the user checks the Roman against.

Urdu is read-only by design. The user corrects the *romanization*, not the transcription.

Nastaʿlīq needs vertical breathing room and a real font. Latin and Urdu at the same optical size look mismatched; the Urdu will need to be larger.

### Segment rules

Every caption segment carries a start time, an end time, Urdu text, Roman Urdu text, and an edited flag. The backend enforces:

- **500 characters** maximum per segment
- **0.5 to 7 seconds** duration
- **0.1 second** minimum gap between segments

Overlaps are possible and there is a one-click "fix overlaps" action. Timings display as `HH:MM:SS,mmm`.

### Uploads

**2 GB maximum.** Video: mp4, avi, mkv, mov, webm. Audio: mp3, wav, m4a, flac, ogg.

### Exports

Five options, but **two of them disappear for audio-only sources**:

| Export | Available for |
|---|---|
| SRT | always |
| VTT | always |
| TXT | always |
| Video — burned-in captions | video sources only |
| Video — toggleable captions | video sources only |

Burned-in re-encodes the video (slow, plays anywhere including social platforms). Toggleable muxes a caption track without re-encoding (near-instant, viewer can switch captions off). Output is always MP4.

### Things that don't exist — don't design them

- **No progress for video export.** Rendering is synchronous. Burning captions into a long video can take minutes with *no percentage available*. The only honest treatment is an indeterminate state. A "62% — rendering" mockup is fiction.
- **No caption styling.** No font, color, position, or size controls. Exports carry plain SRT styling. There is no backend for a styling panel.
- **No language picker.** The pipeline is hardcoded to Urdu. The ASR engine can technically hear other languages, but only Urdu has a romanization path, so a language selector would promise something the product cannot deliver.
- **No background jobs.** Nothing runs while the user is elsewhere in the app. Long operations hold their screen.

### The awkward truths

**A project can outlive its video.** Subtitle projects persist to disk; uploaded media does not survive a server restart. So a project in the list may open with no video to play, and video export will fail. This is a real, reachable state that needs a designed answer, not an error dump.

**Sessions expire hard.** Tokens last 24 hours with no refresh. Expiry means logout, mid-task, without warning.

**Email verification is mandatory.** An unverified account cannot log in — it is rejected at the login screen, which is a confusing place to discover the problem. Verification codes are six digits and last 15 minutes.

---

## 5. Design direction

The visual identity is open. What follows is the personality the product should carry, not a palette.

**RomaSub.AI is a working tool, not a toy.** People open it with a deadline and a file. The dominant emotion should be *competence* — this thing will not lose my work, and it will not make me squint. It is closer to a code editor or a DAW than to a consumer AI app.

**Legibility is the brand.** The entire product exists because a script is easier to read. A design that is beautiful but hard to read refutes its own premise. Text quality, contrast, and rhythm carry more weight here than in almost any other product category. This applies doubly to the two scripts side by side: they must feel like equals, not like a translation widget bolted to a main text field.

**It should feel Pakistani without costume.** The users are Pakistani, the language is Urdu, and the product understands things a generic tool doesn't. That's worth expressing — but through typographic care and the confidence of a tool that takes Urdu seriously, not through decorative motifs or flag colors.

**Calm under long waits.** Much of the experience is waiting: transcribing, rendering, buffering. The waiting states are not edge cases to be styled last; they are a large share of total screen time. They should feel like something is being done carefully, not like something is stuck.

**Worth avoiding:** the generic "AI product" costume — purple-to-blue gradients, glowing orbs, sparkle icons, dark mode as the only mode. Also avoid dense chrome; the editor is already information-heavy and every non-essential pixel competes with the text the user is trying to read.

**Light and dark both matter.** Editors get used at night; the app already carries a user preference for it.

**Breakpoints:** mobile below 600px, tablet below 1024px, desktop at 1024px and up.

---

## 6. The screens

Fourteen screens and four modals. Each entry below covers purpose, content, states, and the responsive question.

---

### 6.1 Splash

**Purpose:** brand moment while the app checks for a stored session.

Logo, product name, tagline "Roman Urdu Caption Generator". Roughly two seconds, then login or straight to the dashboard.

*Responsive:* identical everywhere; it's a centered mark.

---

### 6.2 Login

**Purpose:** get a returning user in, fast.

Email, password, submit. Google sign-in as a peer option — not a footnote, a real alternative. "Forgot password" link. A route to sign-up for people who don't have an account.

**States:** idle, submitting, invalid credentials, **email-not-verified** (the important one — the account is real but blocked, and this screen must offer a path to verification rather than just failing), network error.

The current build fills the empty space with a rotating image panel. Whether to keep that idea is open; the space is real.

*Responsive:* desktop can afford a two-column split (form and something else). Mobile is a single centered column, form capped around 420px.

---

### 6.3 Sign Up

**Purpose:** create an account and set expectations about verification.

First name, last name, email, password, confirm password, terms acceptance. Password must be at least 8 characters with a letter, a digit, and a special character — communicate this *before* submission, not as a rejection.

The screen must make clear that a verification code is coming. Landing on an OTP screen unannounced is a jarring transition.

**States:** idle, validating (inline, per field), submitting, email already registered, success → verification.

*Responsive:* five fields plus a checkbox is a long mobile form; it will scroll, and the submit button should not be stranded below the fold on desktop.

---

### 6.4 Email Verification

**Purpose:** enter a six-digit code and get in.

Six-digit entry (segmented, one box per digit), the email it was sent to, resend with a **60-second cooldown**, and a clear statement that the code expires in 15 minutes.

Success **logs the user straight in** — no bounce back to the login screen. That's a small mercy worth preserving.

**States:** waiting for input, verifying, wrong code, expired code, resend cooldown counting, resent, success.

*Responsive:* six boxes fit a phone, but only just. They must not shrink into unreadability, and the numeric keyboard must appear.

---

### 6.5–6.7 Forgot Password (three steps)

A wizard: **enter email → verify code → set new password.** Show progress; three unexplained screens in a row feels like being lost.

**Step 1 — Email.** One field. The response is deliberately generic whether or not the account exists (anti-enumeration), so the confirmation copy must not imply an account was found.

**Step 2 — Code.** Same six-digit pattern as verification. Reuse it exactly; two different OTP treatments in one product is a mistake.

**Step 3 — New password.** New password, confirm, same rules as sign-up, then back to login.

*Responsive:* each step is one small centered card. This is the easiest set in the product.

---

### 6.8 Dashboard

**Purpose:** the front door. Start a new job, or see that the system is ready.

A **time-based greeting** with the user's first name ("Good Morning, Muttayyab") — small, but it's the app's only warm moment; keep it.

The centerpiece is the **upload zone**: drag-and-drop or click, stating the accepted formats and the 2 GB limit. This is the primary action of the entire product and should read that way at a glance.

Alongside it, a **system status panel** — audio transcription, Roman Urdu transliteration, and model status, each showing ready/online. It answers "will this work right now?" before the user commits a 2 GB file.

**States:** idle, dragging a file over the zone, invalid file type, file too large, uploading (hands off to the progress modal).

*Responsive:* upload and status sit side by side above ~760px, stack below. On mobile the drop zone becomes a button — there is nothing to drag from.

---

### 6.9 Recent Projects

**Purpose:** find previous work.

Search field plus a grid of project tiles. Each tile: project name, source filename, segment count, duration. Tap opens the editor. Newest first.

**States:** loading, empty (first-run — this is a *teaching* moment, point at the dashboard), search with no matches, populated.

The **missing-media** case belongs here too: a project whose video is gone still lists, still opens, still edits. If the design marks that state on the tile, the user learns before they click rather than after.

*Responsive:* three columns desktop, two tablet, one mobile — and a single-column grid of wide short tiles is really a list, so it may as well be designed as one.

---

### 6.10 Exports

**Purpose:** get back to something already produced.

A list of past exports: filename, format badge, source project, when. Formats are SRT, VTT, TXT, and the two MP4 variants; the badge should make the format instantly scannable since that's the main thing distinguishing otherwise identical rows.

**States:** loading, empty, populated.

Note that history records the export event. Whether the file is still retrievable or the row is a receipt is a real design question worth resolving deliberately.

*Responsive:* a list is a list. Mobile drops the least useful column.

---

### 6.11 Feedback

**Purpose:** collect a rating and a comment.

Star rating (1–5), optional comment up to 2000 characters, and a category — general, bug, feature, other. Heading: "We Value Your Feedback".

**States:** empty, rated, submitting, submitted (thank-you), error.

*Responsive:* a single centered form throughout.

---

### 6.12 Settings

**Purpose:** account management, in four groups.

**Profile** — first name, last name, profile picture (upload, max 5 MB, or remove).
**Security** — change password (current, new, confirm).
**Account** — account details, sign out.
**Appearance** — light/dark theme.

Each group saves independently. This is the app's most conventional screen and it should look it; novelty here costs more than it earns.

*Responsive:* sectioned scroll on mobile; on desktop the current single-column layout leaves a lot of width unused, which is worth revisiting.

---

### 6.13 Subtitle Editor — the core screen

**Purpose:** correct machine output efficiently. This is where the product's value is realized and where users spend the most time. Everything else is scaffolding.

Three regions:

**Video preview** (~half the width) — player, transport controls, and a live caption overlay showing the current segment burned over the frame at reduced opacity. This is how the user judges the result: not by reading text, but by watching it.

**Segment list** (~quarter) — every segment as a compact row, searchable, **auto-scrolling to follow playback**. Rows need to show enough text to be identifiable, a timestamp, and whether they've been edited.

**Text editor** (~quarter) — the selected segment in detail:
- **Roman Urdu, editable, LTR** — the working field, where corrections happen
- **Urdu, read-only, RTL** — the reference
- Start and end time fields, `HH:MM:SS,mmm`
- Play this segment, delete it, add one after it

**The toolbar** carries: back, project name, **undo/redo** (50 levels deep), **save with an unsaved-changes indicator**, "fix overlaps", and the export menu (five items, two hidden for audio).

**Behaviors that shape the design:**
- **Auto-save every 30 seconds.** The save button and its dot exist to communicate state, not to shoulder responsibility. The user should never fear losing work — but should always know whether it's saved.
- **Keyboard-first.** Ctrl+Z, Ctrl+Y, Ctrl+S, and space for play/pause (suppressed while typing). Real subtitle work is a rhythm: play, hear, fix, next.
- Segments move Clean → Edited → Saved, and back to Clean if undone to original.

**States:** loading, playing, paused, segment selected, unsaved changes, saving, save failed, exporting (indeterminate — see §4), **media unavailable** (the video panel has nothing to show; this must degrade to a working text editor rather than a broken player), empty search.

*Responsive:* **this is the hardest problem in the product.** Three side-by-side panels cannot exist on a phone. The panels are also not equal — the text editor is where work happens, the video is how it's judged, the list is how you navigate. A mobile design has to choose what's on screen and what's a swipe away, and any answer costs something. The desktop layout is well established; mobile is genuinely open.

---

### 6.14 Realtime Viewer

**Purpose:** watch a video with captions that are still being generated.

Video player, live caption overlay, a phase indicator, and progress through the file. The user arrives from the upload dialog by choosing not to wait.

**Phases:** connecting → buffering (waiting on the first three chunks) → streaming (captions appearing as they finish) → complete.

Two things are unusual and worth designing well:

**The buffering wait has a reason.** The user chose this to *avoid* waiting, then hits a shorter wait. Explaining why — we're getting a head start so playback doesn't stall — turns a broken promise into a reasonable one.

**Seeking is not free.** Jumping ahead of processed audio means the captions aren't there yet; the system reprioritizes and catches up. The player must communicate the boundary between processed and unprocessed audio. A standard scrubber implies you can jump anywhere and everything will be fine, which is not true here.

On completion, the door into the editor.

**States:** connecting, buffering, streaming, seeking ahead of processing, complete, connection lost.

*Responsive:* a video with an overlay adapts well. The phase indicator and progress need to survive a small screen without covering the captions.

---

## 7. The modals

### 7.1 Upload Progress — the pipeline hub

The most important modal in the product. It owns the whole wait, from bytes leaving the machine to a finished transcript.

Phases, with the copy the product uses today:

| Phase | Message | Progress |
|---|---|---|
| uploading | "Uploading file… {n}%" | real |
| extractingAudio | "Extracting audio…" | indeterminate (skipped for audio files) |
| transcribing | "Transcribing audio… {n}%" | **estimated, not measured** |
| transliterating | "Transliterating to Roman Urdu…" | indeterminate |
| completed | "Transcription complete!" | done |
| error | the failure reason | — |

It also carries the **"Skip wait — Watch with Live Subtitles"** escape into the realtime viewer, offered during the three slow phases.

This modal is on screen for minutes on long files. It deserves more design attention than a modal usually gets.

### 7.2 Transcription Complete

The pivot after a successful run: view details, open the editor, or export immediately. Some users only want an SRT and never touch the editor — that path should be one click, not a detour through a screen they don't need.

### 7.3 Full Text Viewer

The whole transcript as continuous text rather than segments. For reading and copying, not editing.

### 7.4 Export Menu

Five items, in order: SRT, VTT, TXT, then — **only for video sources** — burned-in and toggleable video. The two video options are meaningfully different in speed and outcome (minutes of re-encoding vs. near-instant muxing) and the menu is where the user chooses between them. Bare labels make that choice blind.

---

## 8. Open design problems

Worth attacking deliberately rather than discovering late.

**The mobile editor.** Three panels, one phone. Not a scaling problem — a *decision* problem about what earns screen space during subtitle work. The most valuable thing in this document to get right.

**Bidi typography.** Nastaʿlīq and Latin as equals, at readable sizes, in a panel narrow enough to sit beside a video. Every part of that sentence fights the others.

**Honest waiting.** Two of the longest operations — transcription and video rendering — cannot report real progress. Making a multi-minute indeterminate wait feel controlled rather than frozen is a genuine design problem, not a spinner.

**The realtime seek boundary.** Communicating "you can watch up to here, and beyond that we're still working" inside a scrubber people already think they understand.

**Projects without media.** A reachable, currently unglamorous state. The editor still works; the video doesn't. Design it as a mode, not an error.

**Session expiry.** Twenty-four hours, no refresh, no warning. Being kicked out mid-edit is the worst moment the product can produce.

---

## Appendix — quick reference

| | |
|---|---|
| **Product** | Roman Urdu caption generator — Urdu speech to Latin-script Urdu subtitles |
| **Not** | A translator. The output is Urdu, written in Roman script. |
| **Language** | Urdu only. No picker. |
| **Uploads** | 2 GB max · video: mp4, avi, mkv, mov, webm · audio: mp3, wav, m4a, flac, ogg |
| **Exports** | SRT, VTT, TXT always · burned-in MP4, toggleable MP4 for video sources only |
| **Segments** | 500 chars max · 0.5–7 s · 0.1 s minimum gap · timings `HH:MM:SS,mmm` |
| **Editor** | 50-level undo · 30-second auto-save · keyboard-first |
| **Realtime** | 30 s chunks · playback after 3 buffered · seek reprioritizes |
| **Auth** | Email + password, or Google · mandatory 6-digit verification, 15 min · 24 h sessions |
| **Screens** | 14 screens, 4 modals |
| **Breakpoints** | mobile <600 · tablet <1024 · desktop ≥1024 |
| **Both scripts** | Urdu RTL read-only · Roman Urdu LTR editable · side by side in the editor |
