# Skincare Companion (iOS)

A SwiftUI app for people who own skincare products but aren't sure how or why to
use them. You build a "bag" from what you actually own (searched from a real
product database, or entered manually), pick the concerns you're dealing with
(breakouts, uneven texture, dullness, etc.), and the app builds you an ordered
AM/PM routine from your own products — flagging known ingredient conflicts and
telling you what category of product you're missing for the concerns you picked.

This repo is **source code only** — it was written outside of Xcode, so there's
no `.xcodeproj` bundled (a hand-built project file is more likely to be subtly
broken than one Xcode generates for you). Setup below takes about five minutes.

## Design

Soft, pastel "cute" aesthetic — blush pink, lavender, peach, mint, and butter
yellow, with rounded system fonts, pill-shaped tags, and gently-shadowed
cards instead of plain list rows. All of it lives in one file,
`Resources/Theme.swift`: a color palette, `Font` helpers (`.cuteTitle`,
`.cuteHeadline`, `.cuteBody`, `.cuteCaption`), a `cuteCard()` view modifier,
`CuteButtonStyle`/`CuteSecondaryButtonStyle`, a `CutePill` tag component, a
`CuteEmptyState` view, and a `CuteAppearance.configure()` call (run once from
the App's `init`) that reskins the navigation bar and tab bar to match.
Retuning the whole app's look — different palette, different accent — means
editing that one file rather than hunting through every screen.

## Why this stack (and why it's a good resume project)

- **SwiftUI + Swift Concurrency (async/await)** — modern, currently the
  default recommendation for new iOS apps.
- **SwiftData** for persistence (profile, bag, saved routines) — Apple's
  current ORM-style persistence layer, less boilerplate than Core Data,
  and a talking point since it's still relatively new.
- **A real, free, keyless REST API** — [Open Beauty Facts](https://world.openbeautyfacts.org)
  (the cosmetics sibling of Open Food Facts) for product search and barcode
  lookup. No backend of your own to stand up, but it's a genuine third-party
  integration with real-world messiness (inconsistent categorization, missing
  fields, products with no ingredients list) that you had to handle — good
  interview material.
- **A hand-written rule engine** (`RoutineEngine` + `IngredientConflictRules`),
  not a hardcoded list — this is the actual "product" of the app and the part
  most worth walking an interviewer through: given a bag of products and a set
  of concerns, it does ingredient-keyword detection, AM/PM session assignment,
  application ordering, conflict detection, and gap-based recommendations, all
  covered by unit tests with no UI or network dependency.
- **Protocol-based dependency injection** for networking (`URLSessionProtocol`)
  so the test suite runs offline and deterministically against a mock instead
  of hitting the real API.
- **MVVM**, with a deliberate, defensible exception: simple SwiftData CRUD (add
  a product to the bag, delete one, edit its category) is done directly from
  views via `@Query`/`@Environment(\.modelContext)`, which is Apple's own
  current guidance for SwiftData — a ViewModel wrapping trivial persistence
  calls would just be an extra layer with no logic in it. `RoutineViewModel`
  exists because it actually does something: it orchestrates the engine.

## Project structure

```
SkincareCompanion/
  App/                    App entry point, SwiftData ModelContainer setup
  Models/                 Domain types: Product, Active, ProductCategory,
                           SkinConcern, plus SwiftData @Model types
                           (BagItem, UserProfile, SavedRoutine)
  Networking/              OpenBeautyFactsService (async/await), DTOs, errors
  Domain/                  RoutineEngine, IngredientConflictRules — pure logic
  ViewModels/              ProductSearchViewModel, RoutineViewModel
  Views/                   SwiftUI screens, grouped by feature
SkincareCompanionTests/     XCTest suite (engine, ingredient detection, network)
```

## How the routine engine actually works

1. **Detect actives.** Every product's ingredients text (from the API or
   pasted in manually) is scanned for ~15 known actives — retinoids, AHAs,
   BHAs, vitamin C, niacinamide, hyaluronic acid, etc. — via substring
   matching (`Active.detect(in:)`). This is intentionally simple rather than
   a full INCI parser, and that tradeoff is worth being upfront about.
2. **Filter to what's relevant.** Cleanser, moisturizer, and sunscreen are
   always included (every routine needs them); everything else is included
   only if its detected actives target one of the selected concerns.
3. **Assign AM or PM.** Each active has a conventional usage window
   (retinoids and exfoliating acids → PM, vitamin C and SPF → AM, most
   everything else → both). A product's session is derived from the actives
   detected in it.
4. **Order within a session.** Steps are sorted by category — cleanser →
   toner → exfoliant → treatment/serum → eye cream → moisturizer → face oil
   → SPF — matching commonly-cited application order (thinnest/most-active
   products first, occlusive products last).
5. **Flag conflicts.** `IngredientConflictRules` encodes commonly-cited
   pairings that shouldn't be layered in one session (retinoid + AHA,
   retinoid + benzoyl peroxide, vitamin C + retinoid, AHA + BHA) and checks
   whichever actives land in the same AM or PM session.
6. **Recommend gaps.** For every selected concern with no matching product in
   the bag, and for any missing cleanser/moisturizer/sunscreen, the engine
   returns a `Recommendation` naming the product category and the actives to
   look for, phrased as a plain-language sentence ("Since you're dealing
   with breakouts, try a treatment with salicylic acid or benzoyl
   peroxide.") rather than a bare ingredient list.
7. **Collapse duplicate foundational products.** Owning three cleansers
   doesn't mean lathering with all three in one sitting — if the bag has
   more than one product in a foundational category (cleanser,
   moisturizer, sunscreen), only one representative shows up in the
   generated routine per session (preferring whichever one targets a
   selected concern), and its step note says how many others exist in
   the bag rather than silently hiding them.
8. **Assign a weekly schedule, not just AM/PM.** Not everything belongs in
   the routine every day — exfoliating acids and benzoyl peroxide are
   used a few times a week, retinoids every other day (irritation
   risk), and masks weekly. `StepSchedule` assigns each step a
   frequency from its category and detected actives, then derives which
   day(s) it's due from a deterministic hash of the product's id (so the
   same product always lands on the same day of the week, without
   having to persist "which Tuesday did I start this"). `RoutineView`
   filters the AM/PM lists down to what's actually due **today** (with a
   day-of-week strip showing where today falls), and lists anything
   skipped today under "Not Today" with its schedule, so a 3x-weekly
   exfoliant doesn't just silently vanish from the screen.

None of this is medical advice — the UI says so, and it should keep saying so
if you extend it. It's general, commonly-cited skincare-community guidance
encoded as rules, not a dermatologist.

## Product data: bundled starter set + live API

Open Beauty Facts' catalog is excellent for mass-market/drugstore brands but
has very thin coverage for premium and indie brands (its category tagging is
entirely crowd-sourced) — and even when a product is present, fields like
`brands` and `categories_tags` are frequently blank, so search results show
no brand and fall back to the generic "Other" category. Rather than let
search come up empty (or unlabeled) for something as recognizable as Glow
Recipe or Rhode, `Resources/CuratedProducts.json` bundles 300+ well-known
products across 145+ brands, spanning drugstore (CeraVe, Neutrogena,
Cetaphil, Aveeno, Olay, Garnier, Simple, Nivea, RoC), dermatologist/clinical
(SkinCeuticals, Obagi, Dermalogica, PCA Skin, ZO Skin Health, Skinbetter
Science, Alastin), prestige and luxury (Tatcha, Drunk Elephant, Sunday
Riley, Kiehl's, Summer Fridays, Rhode, Charlotte Tilbury, Elemis, Fresh,
Estée Lauder, Lancôme, SK-II, Shiseido, La Mer, La Prairie, Sisley Paris,
Chanel, Dior, Guerlain, YSL), French pharmacy (La Roche-Posay, Vichy, Avene,
Bioderma, Uriage, Nuxe, Embryolisse), clean/indie (Herbivore, Indie Lee,
True Botanicals, Pai, REN, Votary, Vintner's Daughter, Augustinus Bader,
Dr. Barbara Sturm), and a large K-beauty/J-beauty wave (COSRX, Beauty of
Joseon, Glow Recipe, SKIN1004, Laneige, Round Lab, Klairs, Isntree, Anua,
Torriden, Numbuzin, Sulwhasoo, Hada Labo, Biore, Anessa, and more). Every
curated entry has its brand and category hand-filled correctly, so it never
falls into "Other" the way a live API result can. `CuratedProductStore`
loads and searches it locally — no network call, so it's instant.

This is meant as a broad, realistic starter catalog rather than an
exhaustive one — "every skincare product that exists" isn't a bar any
dataset (curated or live) can actually clear, so the honest goal here is
wide brand/category coverage for demo purposes, not literal completeness.
Manual entry is still there as the true fallback for anything not covered.

Sephora and Ulta don't publish a public product API (and scraping their
storefronts would violate their terms of service and break the moment their
HTML changes), so there's no way to wire up a live integration to either —
this bundled set is the practical alternative: real, currently-sold
products and plausible ingredient lists researched from public product
information, reviewed for accuracy rather than pulled live.

`ProductSearchViewModel` merges the two sources: the curated set is searched
synchronously and shown immediately, then live Open Beauty Facts results are
appended once they arrive, deduplicated against anything curated already
matched. Search results show a small "STARTER SET" badge on curated entries
so it's clear which is which. The tradeoff worth being upfront about:
ingredient lists in the curated set were hand-entered from publicly published
product information for demo purposes — good enough to exercise the active-
ingredient detection and conflict logic, but not guaranteed to exactly match
current packaging. A production version of this would license a real
ingredient database instead of hand-curating one.

## Setting up the Xcode project

1. Open Xcode → **File → New → Project → iOS → App**.
2. Product Name: `SkincareCompanion`. Interface: **SwiftUI**. Storage:
   **SwiftData**. Language: Swift. Uncheck "Include Tests" is fine either way
   since we're adding our own test target files.
3. Xcode creates a default `SkincareCompanionApp.swift` and `ContentView.swift`
   — delete both (or just overwrite the App file with the one in this repo;
   delete `ContentView.swift`, it isn't used).
4. Drag the `App/`, `Models/`, `Networking/`, `Domain/`, `ViewModels/`, and
   `Views/` folders from this repo into the Xcode project navigator (check
   "Copy items if needed" and "Create groups", target: SkincareCompanion).
   This repo also includes an `Assets.xcassets/AppIcon.appiconset/` with a
   1024×1024 app icon already in it — you can either drag this repo's
   `Assets.xcassets` in to replace Xcode's auto-generated empty one, or
   (simpler, if you've already customized the auto-generated one) just
   drag `AppIcon-1024.png` from this repo's `Assets.xcassets/AppIcon.appiconset/`
   straight onto the single icon slot in your project's own AppIcon set.
5. Add a test target: **File → New → Target → iOS → Unit Testing Bundle**,
   name it `SkincareCompanionTests`, then drag in the files from this repo's
   `SkincareCompanionTests/` folder (target: SkincareCompanionTests only).
6. Set the minimum deployment target to **iOS 17.0** (SwiftData requires it).
7. Build and run (⌘R) on a simulator. Run tests with ⌘U.
8. The app icon (see step 4 above) is a simple pastel flower-and-sparkles
   mark generated to match `Theme.swift`'s palette — good enough to see
   the app looking finished on a Home Screen / in the simulator. Swap it
   for a custom design whenever you're ready to actually ship; a launch
   screen isn't included and SwiftUI apps don't strictly need one
   (the system shows your first view almost immediately).

No API keys or `.env` setup needed — Open Beauty Facts doesn't require auth.

To use the barcode/label scanner (Bag tab → Add → 📷 Scan), add a
`NSCameraUsageDescription` key to Info.plist (Xcode target → Info tab →
"Custom iOS Target Properties" → + → "Privacy - Camera Usage Description"),
something like "Used to scan a product's barcode or label to add it to your
bag." It only works on a physical device — VisionKit's live scanner isn't
available in the Simulator, so on the Simulator that tab shows a fallback
message pointing to Search/Manual entry instead.

## CloudKit sync

Profile, bag, saved routines, check-ins, and photos now sync across a
user's own devices via SwiftData's built-in CloudKit integration
(`SkincareCompanionApp.sharedModelContainer` uses `ModelConfiguration(...,
cloudKitDatabase: .automatic)`). This needed two changes:

1. **Every `@Model`'s stored properties needed a default value at their
   declaration**, not just an assignment in `init` — CloudKit requires
   every attribute to be optional or defaulted, since a `CKRecord` field
   is always nullable under the hood. `BagItem.id: String = ""`,
   `UserProfile.acknowledgedDisclaimer: Bool = false`, and so on across
   all 8 persisted models. (None of the models here use `@Relationship`
   or `@Attribute(.unique)`, both of which CloudKit also restricts, so no
   changes were needed on that front.)
2. **The container tries a CloudKit-backed configuration first, and falls
   back to a local-only one if that fails** — same "the extra setup is
   optional, nothing crashes without it" pattern this project already
   uses for the barcode scanner and notifications. So it's safe to build
   and run before doing the Xcode setup below; sync just won't be active
   yet.

To actually turn sync on, since there's no `.xcodeproj` checked into this
repo to carry the capability automatically (see "Setting up the Xcode
project" above):

1. Target → **Signing & Capabilities** → **+ Capability** → **iCloud** →
   check **CloudKit**, and add/select a container (the default
   `iCloud.<your bundle identifier>` is fine).
2. **+ Capability** again → **Background Modes** → check
   **Remote notifications** (CloudKit's sync relies on silent push).
3. Run on a simulator or device signed into an iCloud account — any
   personal Apple ID works for development. A paid Apple Developer
   Program membership is only needed to actually ship this to other
   people's devices.

Worth knowing before treating this as done: it hasn't been tested against
a real second device (no Mac/Xcode in this environment to do that), so
conflict-resolution behavior when the same record changes on two devices
close together is unverified — SwiftData's CloudKit sync auto-merges by
default, which is a reasonable starting assumption but not something
proven out here. `ProgressPhoto`'s `@Attribute(.externalStorage)` image
data is expected to sync as a `CKAsset` automatically, but that's also
untested against a live container.

## Age & safety considerations

Onboarding now asks for an age range (`Models/AgeRange.swift`) — a coarse
bucket, not a birthdate, since that's the minimum the app actually needs.
Two things happen with it:

- **Under-13 gate.** COPPA prohibits collecting personal information from
  children under 13 without verified parental consent, which this app has
  no mechanism for. Picking "Under 13" blocks onboarding entirely rather
  than quietly creating a profile — `AgeRange.isEligible` / `canContinue`
  in `ProfileSetupView`. This is also standard practice for App Store
  review on any app that stores personal data.
- **Teen active-ingredient caution (13–17).** Commonly-cited skincare
  guidance is to avoid over-the-counter retinoids (and go easy on strong
  exfoliating acids) during the teen years without a dermatologist's
  input. `RoutineEngine` flags any retinoid already in the bag with a
  caution warning for this age range, and gap recommendations never
  suggest shopping for a retinoid — see `ageCautionWarnings` and the
  `avoidRetinoidSuggestions` filter in `buildRecommendations`.

This is deliberately conservative and simple (one flagged active, one age
threshold) — a real product would want a dermatologist-reviewed rule set,
not an engineering guess, before shipping stronger age-based filtering.

## Where the routine logic comes from

`RoutineEngine`'s rules (thinnest-to-thickest application order, retinoids
and exfoliating acids at night, vitamin C and SPF in the morning, don't
layer retinoid with AHA/BHA, patch test before a new active, and so on)
reflect widely-repeated, commonly-cited general skincare guidance — the
kind of thing consistently said across dermatologist-written consumer
articles, ingredient brands' own usage guidance, and skincare community
consensus. It is **not** random, and it's **not** sourced from a specific
peer-reviewed study or a licensed dermatology database — there's no
citation trail behind any individual rule. That distinction matters and is
worth being upfront about (including in an interview): this is a solid,
defensible **rule-based system design** — the actual engineering, and the
part worth walking through — built on genuinely accurate general-consensus
information, not on individualized, evidence-graded medical guidance. A
production version aimed at real users would want each rule reviewed and
signed off by an actual dermatologist or licensed esthetician before
shipping, which is exactly why the disclaimer below exists and why the app
gates on it.

## Reducing routine overwhelm + newer features (researched against real guidance)

A user testing session turned up a real usability problem: some days had 7
steps stacked up at once, which is a lot to actually do. Two separate things
were going on, and both got fixed:

1. **A real scheduling bug** — two unrelated "3x a week" acid products could
   independently hash to the *same* day pattern (a coin-flip with only two
   possible patterns), stacking both on the same days instead of spreading
   out. `RoutineEngine.assignScheduleKeys` now detects this and nudges a
   colliding product onto the other pattern.
2. **A genuine design question** — how many steps *should* a routine have?
   Dermatologist sources back a minimal 3-step core (cleanse, moisturize,
   SPF in the morning) as the actual evidence-backed floor, with everything
   else — toners, extra serums, actives — as optional layering on top of
   that (see sources below). The Morning section now always shows the
   foundational steps and collapses everything else behind a "+N more
   steps" disclosure, so mornings read as short by default without hiding
   anything.

Researched sources: [DermApproved's 3-step minimalist routine](https://dermapproved.com/routines/minimalist/),
[a dermatologist's 6-step AM routine](https://www.scanskinai.com/blog/ask-a-dermatologist/dermatologist-morning-skincare-routine),
[a dermatologist's 6-step PM routine](https://www.elitedermatology.com/blog/lets-talk-dermatologist-recommended-pm-skincare-routine/),
and a scan of [2026 skincare-app feature roundups](https://layered-skincare.app/blog/best-skincare-apps-2026)
for what similar apps do (and don't) offer — ingredient safety ratings and
routine timers are common; ingredient-conflict warnings, skin-type matching,
and schedule rescheduling are not, which is part of why they're worth having
here.

That research also fed a batch of other features:

- **Per-step warnings instead of an upfront list.** `RoutineWarning` now
  carries `relatedBagItemIDs` — which specific products triggered it — so a
  conflict (e.g. retinoid + AHA) shows as a small tappable warning icon
  right on those two product rows instead of a block of warnings before
  you've even seen the routine. Only truly routine-wide warnings (no single
  product to point at, like "no sunscreen in your bag") still show in a
  general "Heads Up" section, which stays at the bottom.
- **Tappable recommendations.** "You Might Need" cards now push into
  `RecommendationDetailView`, showing real curated products for that gap
  ranked by what percentage of the concern's targeting actives each one
  actually contains. Note: this is an ingredient-fit match, not a
  collaborative "people who bought X also bought Y" signal — this is a
  single-user, offline app with no purchase history or other users to draw
  that from, so ingredient-match percentage is the honest, buildable
  equivalent.
- **Tappable ingredients.** Each detected active on a product's detail page
  is now a button; tapping it shows a plain-language "what it does"
  (`Active.whatItDoes`) and anything it's commonly flagged for layering
  with, pulled directly from `IngredientConflictRules` so the explanation
  never drifts out of sync with the actual conflict logic.
- **Skin-type suitability.** `SkinTypeSuitability.infer` guesses which of
  the five skin types (oily/dry/combination/normal/sensitive) a product
  suits from its category and ingredients — the same keyword-heuristic
  approach as category inference and active detection, since no data
  source (curated set or Open Beauty Facts) actually carries this as
  structured data. Shown on the product detail screen and as a compact
  hint on search results. Explicitly labeled a best-guess, not a verified
  brand claim.
- **Reschedule a missed step.** `ScheduleOverride` is a new persisted,
  per-day exception on top of the normal weekly pattern — "Do Today"
  on a "Not Today" item pulls it into today just this once (for "I missed
  Tuesday's exfoliant"), and a context menu on any step offers "Not doing
  this today" the other direction. Neither changes the product's ongoing
  schedule, just that one day.

A follow-up look at a real "example rotational routine" (a dermatologist-style
Google AI Overview showing per-step technique notes like "milk toner, 1-2
layers") plus competitive research against other skincare apps (written up
separately as `competitive-research-and-roadmap.md` in the project) led to a
second batch:

- **Layering/technique tips per category.** `ProductCategory.applicationTip`
  gives conventional how-to-apply guidance (a toner is commonly layered 1-2
  times, not just swiped once; a face oil goes on last to seal everything
  in). `ProductCategory.prepNote` adds a companion "before this" note — what
  state your skin should be in going into the step (fully dry vs. still
  damp, freshly cleansed, etc.) — since a Google AI Overview routine's most
  useful detail turned out to be exactly this "pat dry between steps" kind
  of instruction, not just a list of product names. Both are tap-revealed
  next to the step (an info icon appears only when there's something to
  show) rather than always-on text, keeping each row compact.
- **A "tool" product category.** Devices like a facial steamer, jade
  roller, gua sha stone, ice roller, or LED mask aren't ingredient-based
  products, so they get their own `.tool` category: no ingredients section,
  no skin-type suitability guess, a weekly-ish suggested frequency, and
  their own application tip ("move it slowly, don't hold a hot tool in one
  spot"). `Product.hasIngredients` gates the ingredient/skin-type UI so a
  steamer's detail page doesn't show empty sections. Five starter tool
  products are in the curated set to search for and add.
- **A personal allergen list.** Beyond the fixed `Active` enum (which only
  covers well-known actives), `PersonalAllergen` lets someone flag their own
  free-text terms — a fragrance, an extract, lanolin, a nut oil — anything
  only they would know to watch for. `RoutineEngine.allergenWarnings`
  matches each term against every included product's ingredients text
  (same case-insensitive substring approach `Active.detect` already uses)
  and raises a per-product warning pinned to exactly the product that
  contains it. Managed from a new "My Allergens" screen off the Profile tab.
- **A skin-type mini-quiz.** `SkinTypeQuiz` is a pure 3-question heuristic
  (shiny T-zone by midday? tight/flaky cheeks? easily irritated by new
  products?) for anyone who genuinely doesn't know their skin type yet,
  reachable via "Not sure? Take a quick quiz" next to the skin-type picker
  in Profile setup. Explicitly labeled a starting-point guess, not a
  dermatological assessment — irritation answers always win out to
  "sensitive" first, since that's the one that should change what gets
  recommended.
- **Routine reminders.** `NotificationScheduler` wraps
  `UNUserNotificationCenter` for two repeating daily local notifications
  (AM/PM), driven entirely by times the user picks in a new "Routine
  Reminders" screen — no push infrastructure, nothing leaves the device.
  `UserProfile` gained `remindersEnabled`/`amReminderTime`/`pmReminderTime`
  to persist the choice.
- **Progress photo log.** `ProgressPhoto` (a new SwiftData model, photo data
  stored via `.externalStorage` so the database itself stays small) backs a
  private, chronological photo + note timeline in a new "Progress" tab,
  built with `PhotosPicker`. Deliberately does **not** claim to analyze or
  score photos — "does this actually look different after 6 weeks" is a
  judgment call a person makes by eye, and claiming otherwise would be the
  kind of unverifiable "AI skin scanning" feature the research write-up
  explicitly recommended against building.

A third round targeted the two loudest gaps left after that batch: the app
still couldn't tell whether a routine was actually *working*, and adding a
product still meant typing it in by hand every time.

- **Consistency streak + heatmap.** `RoutineCompletion` records "I actually
  did my AM/PM routine today" (a new "Mark Done" toggle on each session
  header) — a real gap, since the app previously only knew what was
  *scheduled*, never what was *done*. `RoutineAdherence` turns that log into
  a streak count and a 21-day heatmap strip on the Progress tab. Today not
  being marked yet doesn't zero out the streak — it just doesn't count until
  it's marked.
- **Daily skin check-in + flare-pattern flags.** A 1-tap "Great / Okay /
  Irritated" log (`SkinCheckIn`) sits above the photo timeline. Once there
  are at least 3 "irritated" days logged, `SkinCheckInInsights` checks
  which actives were scheduled to be in use on those days versus their
  overall baseline rate (reusing `StepSchedule.isDue`, which is a pure
  function of date — no separate "what did I use each day" log needed) and
  flags anything disproportionately common on the bad days. Presented with
  the raw counts alongside the rate ("scheduled on 4 of 5 irritated
  check-ins, vs. 3 of 12 overall") specifically so a 3-data-point pattern
  doesn't read as more confident than it is — correlation, not causation,
  small sample size, always.
- **Patch-test advisory.** Dermatologist-cited guidance is to introduce one
  new active at a time so a reaction is traceable — `PatchTestAdvisor` flags
  when 2+ active-containing products were added to the bag within the same
  week, named directly, as a nudge (not a block) on the Bag tab.
- **PAO / expiry tracking.** `BagItem` gained `openedDate`/`paoMonths` — the
  "12M" jar-icon number from packaging — plus `ProductLifecycle`'s date math
  for an estimated expiry. An "Expiring Soon" card surfaces anything expired
  or within 2 weeks of it on the Bag tab; toggled on from the product detail
  screen.
- **Scan a product — barcode or not.** A new "📷 Scan" mode
  (`ProductScannerView`) uses VisionKit's on-device `DataScannerViewController`
  to read a real barcode (looked up against Open Beauty Facts, same as
  typing one in) *and*, when there isn't one, to read the product's name
  straight off the label via on-device text recognition, prefilling the
  manual-entry form for review. Deliberately framed as reading text off
  packaging, not as "identifying a product" — genuine product recognition
  from a photo needs a trained image model this app doesn't have, and
  overclaiming what OCR can actually tell you would be the same mistake the
  progress-photo feature above was written specifically to avoid. Requires
  a physical device (the scanner API isn't available in the Simulator) and
  an `NSCameraUsageDescription` entry in Info.plist.

### Round 4: pregnancy safety, a guided "Skin Assessment," and in-store scan scoring

Three more requests, one deliberate substitution worth calling out explicitly:

- **Pregnancy/nursing ingredient safety flags.** `UserProfile` gained an
  opt-in `isPregnantOrNursing` toggle (off by default, in both onboarding
  and the new Skin Assessment flow below). `PregnancySafety` is a small,
  explicit table of commonly-cited flags — retinoids as a hard "avoid"
  (most OB/dermatology guidance says stop use), salicylic acid as a softer
  "check with your provider" (guidance varies by concentration). When the
  toggle is on, `RoutineEngine` both surfaces a named warning for any
  flagged active already in the bag and stops *recommending* retinoids for
  an otherwise-unaddressed concern — same "no black box" pattern as every
  other warning in the app: a reason string, never a bare flag. This is
  general, commonly-cited information, explicitly not medical advice, and
  the copy says so.
- **"Scan your face and ask more questions" → a guided Skin Assessment,
  not a fake AI analyzer.** This one deserves the honest explanation: the
  app does **not** point the camera at your face and claim to detect skin
  conditions. Identifying acne, redness, pore size, or fine lines from a
  photo needs a trained dermatology-specific image model this project
  doesn't have — and a home-grown stand-in (say, averaging pixel redness)
  would *look* like an analysis without being one. In a health-adjacent
  app, that's a worse outcome than not having the feature, and it's
  exactly the kind of overclaim the disclaimer and progress-photo framing
  elsewhere in this app were written to avoid. What genuinely does make
  recommendations more accurate — and was fully buildable — is better
  questions. `SkinAssessmentView` is a 5-step guided flow (skin-type quiz →
  concerns → age range + pregnancy toggle → personal allergens → summary)
  that consolidates every input the app already collects, which used to be
  scattered across the Profile screen, into one sequence that ends by
  saving straight into the routine. Step 5 offers an optional reference
  photo purely for the user's own before/after use in Progress — captioned
  explicitly as **not analyzed by anything** here, to avoid even implying
  otherwise.
- **In-store scan → personalized fit percentage.** The existing barcode
  scanner (`ProductScannerView`) no longer auto-adds a matched product to
  the bag. Instead, `ProductFitScorer` scores it against the user's actual
  profile — skin type, concerns, personal allergens, pregnancy/nursing
  status, age range, and what's already in the bag — and a new
  `FitResultView` shows the result as a percentage ring, a verdict (Avoid /
  Use Caution / Good Fit / Great Fit), and a bulleted list of every reason
  behind the number, before the user chooses to add it or not. A personal
  allergen match or a pregnancy-flagged active is a hard stop (capped at a
  low percentage, regardless of anything else); everything else is
  additive scoring from a neutral baseline. Explicitly labeled a rule-based
  estimate, not medical advice — it only catches what's in the app's own
  ingredient/active list.

## Disclaimer

`Views/Legal/DisclaimerView.swift` is a full disclaimer screen — not
medical advice, allergy/patch-test guidance, data-accuracy caveats for
both the live API and the curated set, age-based guidance limitations, no
outcome guarantees, and a use-at-your-own-risk statement — reachable any
time from the Profile tab ("Legal & Disclaimer"). A short version of it is
also a **required checkbox during onboarding**: the "Let's Go!" button
stays disabled until it's checked (`UserProfile.acknowledgedDisclaimer`,
enforced by `ProfileSetupView.canContinue`), and there's a "Read the full
disclaimer" link right next to the checkbox. The one-line caption already
on the Routine screen ("General educational guidance... not dermatological
advice") stays too — the idea is layered visibility: unmissable once at
signup, always reachable from Profile, and restated at the point where
recommendations are actually shown.

This is a reasonable, honest disclaimer for a portfolio/demo project. It
is explicitly **not a substitute for actual legal review** — if this were
heading toward a real public App Store release, an actual lawyer (ideally
one experienced with health-adjacent consumer apps) should review and
likely rewrite this text before it's relied on for liability protection.

## Other requirements worth having (researched, not all implemented)

Age-gating raised the obvious next question — what else does an app in
this space typically need? A non-exhaustive list, roughly in the order
a reviewer or a real launch would actually hit them:

- **App Store Review Guidelines.** Guideline 1.4.1 (physical harm) is the
  relevant one for anything that reads as medical/health advice — the
  in-app disclaimer ("General educational guidance... not dermatological
  advice") already visible on the Routine screen is the right shape of
  mitigation, and should stay prominent rather than buried in Settings.
  Guideline 5.1.1 covers the privacy requirements below.
- **Privacy policy + App Store privacy "nutrition label."** Required for
  submission even though this app is local-only today (no account, no
  analytics, no data leaves the device except product search queries to
  Open Beauty Facts). The privacy label should say exactly that — "no
  data collected" is a real, valid answer, but it has to be declared.
- **Data minimization.** Age is stored as a 6-value bucket instead of a
  birthdate for exactly this reason — collect the coarsest data that
  still does the job. The same principle would apply if a real ingredient
  or allergy history were ever added.
- **Allergy / patch-test guidance.** Implemented — `PersonalAllergen`
  entries are cross-referenced against both bag warnings and the in-store
  scan scorer (`ProductFitScorer`), as a natural extension of the
  conflict-detection system.
- **Pregnancy/breastfeeding caution.** Implemented — see "Round 4" above
  (`PregnancySafety`, the `UserProfile.isPregnantOrNursing` toggle, and the
  routine/scan warnings it drives). Still worth a real clinician's review
  of the wording and the flag list before this went anywhere beyond a
  portfolio project.
- **Accessibility.** VoiceOver labels for icon-only buttons, Dynamic Type
  support for the custom `.cute*` fonts, and sufficient color contrast on
  the pastel palette (some of the lighter tints are borderline against
  white text) haven't been audited yet.
- **App Tracking Transparency / analytics.** Not applicable today since
  there's no analytics SDK — but the moment one is added (crash
  reporting, usage analytics), an ATT prompt and a privacy label update
  are both required before that data leaves the device.
- **Account deletion / data export.** More relevant now that CloudKit sync
  is wired up (see "CloudKit sync" above) — data lives in the user's own
  private iCloud database rather than a server this app controls, so
  there's no third-party account to delete, but App Store review still
  expects an in-app way to clear synced data, not just uninstalling. Not
  implemented yet; a "Delete all my data" action in Profile that removes
  every local + synced record would close this.

## Known limitations / good next steps to mention in an interview

- Ingredient detection is substring-based, not a real INCI ontology — a
  product with an unusual ingredient name spelling won't be detected.
- Open Beauty Facts' category tagging is crowd-sourced and inconsistent, so
  `ProductCategory.infer` is a best-effort heuristic; the UI lets users
  correct a product's category after adding it.
- CloudKit sync is wired up (see "CloudKit sync" above) but untested against
  a real second device — no Mac/Xcode in this environment to verify
  multi-device merge behavior or `CKAsset` photo syncing actually round-trip
  correctly. Still no backend account system — this is the user's own
  private iCloud database, not a server-side account.
- Conflict rules and concern-to-active mappings are hardcoded in Swift, not
  data-driven — fine for a portfolio project, but a real product would likely
  move this to a remote-configurable dataset so it can be corrected without a
  release.
- No real photographic skin analysis, by design — see "Round 4" above.
  `SkinAssessmentView` improves accuracy through better questions instead of
  claiming to read skin condition from a photo, which would need a trained
  dermatology-specific image model this project doesn't have. Worth stating
  plainly in an interview as a deliberate scope call, not a gap.
- `ProductFitScorer`'s percentage is only as good as the app's own
  active/ingredient list and the user's declared allergens — an unusual or
  newly-studied ingredient concern won't be caught, and the score is a
  heuristic estimate, not a clinical one.
