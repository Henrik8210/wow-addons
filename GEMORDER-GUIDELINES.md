# GemOrder development guidelines

This repo ships two related addons from one codebase:

| Addon | Folder | Purpose |
|-------|--------|---------|
| **GemOrder** | `GemOrder/` | Production guild gem-order addon |
| **GemOrderTest** | `GemOrderTest/` | Parallel mirror for bisect/debug (logout taint, etc.) |

**GemOrderTest stays on the same version as GemOrder when you ship a release.** During experiments, Test can run **ahead** with its own suffix — see [Test-only development](#test-only-development) below.

---

## Versioning

1. Bump `## Version:` in `GemOrder/GemOrder.toc` and `GemOrder.VERSION` in `GemOrder/Core.lua` together.
2. Run the sync script (below) so `GemOrderTest` matches that version.
3. Never ship GemOrder without updating GemOrderTest to the same version (unless intentionally creating a bisect fork — document that in `GemOrderTest/BISECT.txt`).

Patch examples: `0.7.80` → `0.7.81` for small fixes; minor feature bumps can use `0.8.0` when appropriate.

When Test is **ahead of production**, use a suffix on Test only, e.g. `0.7.80-r1`, `0.7.80-bisect2`. Production stays at `0.7.80` until you promote the change.

---

## GitHub workflow

- **Remote:** https://github.com/Henrik8210/wow-addons.git — branch `main`
- **Always commit and push after every change** to GemOrder or GemOrderTest — no exceptions for “small” fixes. If it was worth deploying to WoW, it belongs in git.
- After each change:
  1. Commit with a short message focused on **why** (not just what changed).
  2. Push to `origin/main` unless the user explicitly asked not to push.
- Do not leave fixes only on disk or only deployed to WoW — GitHub is the source of truth.

Example commit message:

```
Fix logout taint: defer StaticPopup and use hooksecurefunc for dropdown tooltips (v0.7.80).
```

---

## WoW deploy path

Always copy updated addons here after changes so `/reload` picks them up immediately:

```
C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\
```

Deploy folders:

- `GemOrder/` → `...\AddOns\GemOrder\`
- `GemOrderTest/` → `...\AddOns\GemOrderTest\`

PowerShell example:

```powershell
$wow = "C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns"
Copy-Item -Path "GemOrder\*" -Destination "$wow\GemOrder\" -Recurse -Force
Copy-Item -Path "GemOrderTest\*" -Destination "$wow\GemOrderTest\" -Recurse -Force
```

---

## Syncing GemOrderTest from GemOrder

GemOrderTest is generated from GemOrder with automated renames:

| GemOrder | GemOrderTest |
|----------|--------------|
| `GemOrderDB` | `GemOrderTestDB` |
| `GemOrder_*` globals/functions | `GemOrderTest_*` |
| `GemOrder.*` tables | `GemOrderTest.*` |
| Frame names `GemOrderFrame`, … | `GemOrderTestFrame`, … |
| Addon message prefix `GemOrder` | `GemOrdT` |
| Commands `/gemorder`, `/go`, … | `/gotest`, `/got`, `/gott` |

**Run from repo root:**

```powershell
.\scripts\sync-gemordertest.ps1
```

Optional explicit version (defaults to reading `GemOrder/GemOrder.toc`):

```powershell
.\scripts\sync-gemordertest.ps1 -Version 0.7.80
```

Then deploy both folders to WoW and commit both addons together.

**Do not run the sync script** while you are actively experimenting in `GemOrderTest/` only — it overwrites Test with a copy of production.

---

## Test-only development

Use this when GemOrderTest is **ahead** of production (bisect, risky features, logout experiments).

### Rules

1. **Edit `GemOrderTest/` only** — leave `GemOrder/` unchanged.
2. **Do not run** `.\scripts\sync-gemordertest.ps1` until you are promoting a change to production (sync would wipe your experiment).
3. **Bump Test version with a suffix** in `GemOrderTest/GemOrderTest.toc` and `GemOrderTest/Core.lua`, e.g. `0.7.80-r1` (production stays `0.7.80`).
4. **Log what you changed** in `GemOrderTest/BISECT.txt` (hypothesis, pass/fail, logout result).
5. **In WoW:** disable GemOrder, enable GemOrderTest. Deploy only the Test folder:

```powershell
$wow = "C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns"
Copy-Item -Path "GemOrderTest\*" -Destination "$wow\GemOrderTest\" -Recurse -Force
```

### Git / push (Test-only)

Commit and push **only** the Test paths (and `BISECT.txt`):

```powershell
git add GemOrderTest/ GEMORDER-GUIDELINES.md
git commit -m "GemOrderTest 0.7.80-r1: try X for logout bisect."
git push
```

Production `GemOrder/` does not need to change on every Test experiment.

### When the experiment succeeds — promote to production

1. Port the fix into `GemOrder/` (by hand or by copying files and reversing the Test renames).
2. Bump **production** version, e.g. `0.7.80` → `0.7.81`.
3. Run `.\scripts\sync-gemordertest.ps1` so Test becomes a clean mirror at `0.7.81`.
4. Deploy **both** folders, smoke-test logout on **GemOrder**, commit and push everything.

### When the experiment fails

Revert or iterate in Test (`-r2`, `-r3`, …), update `BISECT.txt`, push Test-only commits if you want the history on GitHub. Production is untouched.

### Quick reference

| Situation | Edit | Run sync? | Version |
|-----------|------|-----------|---------|
| Normal release | `GemOrder/` | Yes, after | Same on both, e.g. `0.7.81` |
| Bisect / risky try | `GemOrderTest/` only | **No** | Test suffix, e.g. `0.7.80-r1` |
| Promote winning fix | `GemOrder/` then sync | Yes | Bump prod, then align Test |

---

### Files the sync script does not overwrite

Maintain manually:

- `GemOrderTest/BISECT.txt` — bisect notes and experiment log
- `GemOrderTest/Debug.lua` — optional; not in `.toc` by default
- `GemOrderTest/Commands.lua` — regenerated by sync, but safe to hand-edit between syncs if needed

---

## Logout taint case study (Aug 2026)

**Read this before adding UI hooks, bag watchers, or Blizzard frame integration to any WoW addon — not just GemOrder.**

### Symptom

On logout, WoW showed:

> *"&lt;AddonName&gt; has been blocked from an action only available to the Blizzard UI."*

Logout was blocked. The problem could appear **even if the player never opened the addon** after `/reload` — meaning **login-time code** was enough to taint the session.

### What “taint” means here

WoW marks code paths as **tainted** when addon Lua touches **protected Blizzard UI** (frames, dropdowns, popups, logout flow). Once tainted, the client blocks actions that must stay secure — logout/escape is a common victim.

Important implications:

- Taint can be set at **addon load** or **PLAYER_LOGIN**, not only when the user opens your window.
- “Cleanup on logout” hooks often **make it worse** — you are still running addon code during the protected logout sequence.
- Parsing a `.lua` file listed in `.toc` runs its top-level code at load, even if you never call `Init()`.

### How we found it (bisect summary)

We used a parallel **GemOrderTest** addon (separate saved vars, separate addon-message prefix) and stripped features until logout passed.

| Build | Logout | Notes |
|-------|--------|-------|
| Full GemOrder ~v0.7.73 | **FAIL** | Even without opening UI |
| GemOrderTest v0.6.0-r1 (stripped) | **PASS** | No stock watcher, lazy UI, no StaticPopup at load |
| Removed `stockWatcher` + lazy UI (v0.7.74) | Still fail | More culprits remained |
| Removed logout prep hooks (v0.7.75) | Still fail | |
| Deferred recipe events (v0.7.76) | Still fail | |
| Reinstated dropdown `SetScript` + StaticPopup at load (v0.7.79) | **FAIL again** | Confirmed regressions |
| Lazy StaticPopup + `hooksecurefunc` tooltips (v0.7.80) | **PASS** | Current production pattern |

**Lesson:** Never assume one fix is enough. Always run the [logout smoke test](#mandatory-logout-smoke-test) after re-adding features.

### Root causes we confirmed

#### 1. Bag/bank watcher at login (`BAG_UPDATE`, `PLAYERBANKSLOTS_CHANGED`)

```lua
-- BAD: runs as soon as bags are scanned at login
stockWatcher:RegisterEvent("BAG_UPDATE")
stockWatcher:SetScript("OnEvent", function()
    ScanBagsAndShareWithGuild()  -- addon logic + sync during login
end)
```

**Why it breaks:** Login triggers bag events. Addon code runs before the player touches your UI, tainting protected paths.

**Instead:** Scan/share only on explicit user action (button click) or when your own window is open — not on every bag change at login.

---

#### 2. “Helpful” logout cleanup hooks

```lua
-- BAD: fighting Blizzard during logout
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("LOGOUT")
frame:SetScript("OnEvent", function()
    PrepareForLogout()  -- hides frames, edits UISpecialFrames, clears scripts
end)
```

**Why it breaks:** Logout is a secure Blizzard action. Addon code that mutates `UISpecialFrames`, hides frames, or clears scripts on those events interferes with the client’s own teardown.

**Instead:** Do not hook logout to “clean up.” Hide your frames when the user closes them. If you must register in `UISpecialFrames`, avoid it entirely (see below).

---

#### 3. `UISpecialFrames` registration

```lua
-- BAD at load or Init: ties your frame into Blizzard’s escape/logout stack
tinsert(UISpecialFrames, frame:GetName())
```

**Why it breaks:** That list is part of protected UI handling (escape key, logout ordering).

**Instead:** Prefer closing your frame with your own close button. For **ESC-to-close**, register in `UISpecialFrames` when the frame is first created (lazy UI init), not at addon load — and **never** remove entries on `LOGOUT`. See `GemOrder_RegisterEscapeFrame` in `Tooltips.lua`.

**Long dropdown lists:** Top rows sit high on screen — tooltips anchored to the row (`ANCHOR_RIGHT`) can render **off-screen above the viewport** (looks like no tooltip). Fix: use cursor-anchored tooltips with `SetClampedToScreen(true)` for dropdown rows (`GemOrder_ShowDropdownItemTooltip`). Overlays blocking mouse was a separate issue; if hover highlight works but no tooltip, check placement first.

---

#### 4. `StaticPopupDialogs` at file load

```lua
-- BAD in UI.lua (loaded from .toc at login):
StaticPopupDialogs["MY_ADDON_CONFIRM"] = { ... }
```

**Why it breaks:** The table is Blizzard’s. Writing to it when the file parses runs at **login**, even if the user never opens your addon.

**Instead:** Register the dialog lazily — first time you need it:

```lua
local function EnsureMyPopupRegistered()
    if MyAddon.popupRegistered then return end
    MyAddon.popupRegistered = true
    StaticPopupDialogs = StaticPopupDialogs or {}
    StaticPopupDialogs["MY_ADDON_CONFIRM"] = { ... }
end
```

Call `EnsureMyPopupRegistered()` inside the button handler that shows the popup.

---

#### 5. `SetScript` on Blizzard dropdown list buttons

```lua
-- BAD: mutates DropDownList1Button3 etc.
local button = _G["DropDownList1Button" .. index]
button:SetScript("OnEnter", function(self)
    GameTooltip:SetHyperlink("item:" .. itemId)
end)
```

**Why it breaks:** Dropdown list buttons are Blizzard templates. Replacing their scripts taints the dropdown system; logout/escape can fail after the dropdown was opened once.

**Instead:** Use `hooksecurefunc` on `UIDropDownMenuButton_OnEnter` / `OnLeave`, and **scope** it to your addon’s dropdowns only (check `UIDROPDOWNMENU_OPEN_MENU:GetName()`). Show tooltips from the hook; do not replace the button’s script.

---

#### 6. Eager UI initialization on `ADDON_LOADED`

```lua
-- BAD: builds full UI + hooks at login
if event == "ADDON_LOADED" then
    MyAddon.UI:Init()
    HookAllDropdowns()
end
```

**Why it breaks:** Creates frames, hooks, and dropdown wiring before the player asked for UI — increases surface area for taint at login.

**Instead:** **Lazy UI** — init on first slash command or minimap click:

```lua
function MyAddon_EnsureUI()
    if MyAddon.UI.frame then return true end
    MyAddon.UI:Init()
    return MyAddon.UI.frame ~= nil
end
```

Files in `.toc` still **parse** at load; avoid top-level side effects in those files.

---

#### 7. Login-time recipe / trade-skill scanning

Auto-scanning professions or syncing recipe data on `PLAYER_LOGIN` kept failure modes alive until we deferred the trade-skill event watcher until the Recipes **panel** was first built.

**Instead:** Register `TRADE_SKILL_SHOW` / `TRADE_SKILL_UPDATE` only when the user opens the relevant tab.

---

### Mandatory logout smoke test

Run this **before every release** and after re-adding any UI integration:

1. `/reload`
2. **Do not open the addon** → try logout → must succeed
3. Open addon, use dropdowns / popups / order flow → try logout → must succeed
4. If either fails, treat the last change as suspect — bisect in GemOrderTest if needed

Record results in `GemOrderTest/BISECT.txt` when debugging.

---

### Red flags for code review (any addon)

Stop and plan a logout test if the diff includes:

- [ ] `RegisterEvent("BAG_UPDATE")` or bank slot events for automatic actions
- [ ] `RegisterEvent("LOGOUT")` or `PLAYER_LEAVING_WORLD` for cleanup
- [ ] `tinsert(UISpecialFrames, ...)` at file scope or on `ADDON_LOADED` (lazy UI init is OK — retest logout)
- [ ] `tremove(UISpecialFrames, ...)` or logout hooks that edit `UISpecialFrames`
- [ ] `StaticPopupDialogs[...] =` at file scope (outside a lazy registrar)
- [ ] `SetScript` on `DropDownList` / `DropDownList*Button*` frames
- [ ] `CloseDropDownMenus()` or hiding `DropDownList` from addon code during logout prep
- [ ] Full UI `Init()` on `ADDON_LOADED` or `PLAYER_LOGIN`
- [ ] `hooksecurefunc` on global UI without scoping to your frames only (lower risk than SetScript, still test)

### Safe patterns (checklist)

| Need | Safe approach |
|------|----------------|
| Main window | Lazy init on first open |
| Confirm dialog | Lazy `StaticPopupDialogs` registration |
| Dropdown item tooltips | `hooksecurefunc` + scope to your dropdown names |
| Selected item tooltip | `OnEnter` on **your** dropdown arrow button (you own it) |
| Stock / bag sync | Manual refresh button or scan when your UI opens |
| Recipe scan | Register trade events when relevant panel opens |
| Close on escape | Register in `UISpecialFrames` at lazy UI init; do not clean up on logout |

### Fixed version reference

Production **v0.7.80** is the first known-good build with all of the above applied. See git history around `f15eb4f` … `c300068` for the bisect trail.

---

## Logout / taint quick reference

Condensed list for day-to-day work:

| Pattern | Why |
|---------|-----|
| `BAG_UPDATE` / bank watcher auto-sharing stock at login | Taints before UI opens |
| `PrepareForLogout` hooks on `PLAYER_LEAVING_WORLD` / `LOGOUT` | Fighting Blizzard logout |
| Registering frames in `UISpecialFrames` at **login/file load** | Taints escape/logout before UI opens |
| Removing from `UISpecialFrames` on **logout** (`PrepareForLogout`) | Fights Blizzard during secure logout |
| `StaticPopupDialogs[...] =` at **file load** in `UI.lua` | Runs at login even if UI never opens |
| `SetScript` on Blizzard `DropDownList` buttons | Taints protected dropdown UI |

**Safe patterns:**

- **Lazy UI:** `GemOrder_EnsureUI()` — build UI only on first `/gemorder` or minimap click
- **Lazy StaticPopup:** register dialog only when first needed (e.g. close workshop)
- **Dropdown row tooltips:** `hooksecurefunc` on `UIDropDownMenuButton_OnEnter`, scoped to your dropdown names. Store `itemId` on each list button as `button.gemOrderItemId` when the menu builds — do **not** rely on `button.value` (Blizzard recycles buttons). Do **not** `SetScript` on list buttons.
- **Recipe events:** start trade-skill watcher when Recipes panel is built, not at login

When re-adding features, follow the [mandatory logout smoke test](#mandatory-logout-smoke-test) above.

---

## Bisect testing with GemOrderTest

1. **Disable GemOrder**, enable **GemOrderTest** at character select.
2. `/reload`
3. Test logout (with and without opening the UI).
4. Record results in `GemOrderTest/BISECT.txt`.

GemOrderTest uses separate saved variables and addon messages, so it does not corrupt main GemOrder data. It still shares the same guild channel traffic shape with prefix `GemOrdT` instead of `GemOrder`.

---

## Checklist for each release build

- [ ] Feature/fix implemented in `GemOrder/`
- [ ] Version bumped in `GemOrder.toc` and `Core.lua`
- [ ] `.\scripts\sync-gemordertest.ps1` run
- [ ] Both folders copied to WoW AddOns path
- [ ] Logout smoke-test (main GemOrder) — see [case study](#logout-taint-case-study-aug-2026)
- [ ] Committed and pushed to `origin/main` (required for every change, not only releases)

---

## Cursor / agent rules

The file `.cursor/rules/git-sync.mdc` points agents at this workflow: deploy to WoW, keep versions aligned, commit and push after meaningful GemOrder work.
