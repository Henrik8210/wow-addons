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
- After meaningful work on GemOrder or GemOrderTest:
  1. Commit with a short message focused on **why** (not just what changed).
  2. Push to `origin/main`.
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

## Logout / taint rules (learned from bisect)

These patterns **broke logout** and must not return without a retest:

| Pattern | Why |
|---------|-----|
| `BAG_UPDATE` / bank watcher auto-sharing stock at login | Taints before UI opens |
| `PrepareForLogout` hooks on `PLAYER_LEAVING_WORLD` / `LOGOUT` | Fighting Blizzard logout |
| Registering frames in `UISpecialFrames` at load | Taints escape/logout |
| `StaticPopupDialogs[...] =` at **file load** in `UI.lua` | Runs at login even if UI never opens |
| `SetScript` on Blizzard `DropDownList` buttons | Taints protected dropdown UI |

**Safe patterns:**

- **Lazy UI:** `GemOrder_EnsureUI()` — build UI only on first `/gemorder` or minimap click
- **Lazy StaticPopup:** register dialog only when first needed (e.g. close workshop)
- **Dropdown row tooltips:** `hooksecurefunc("UIDropDownMenuButton_OnEnter", …)` scoped to GemOrder dropdown names — not `SetScript` on list buttons
- **Recipe events:** start trade-skill watcher when Recipes panel is built, not at login

When re-adding features, test logout in this order:

1. `/reload` → logout **without** opening GemOrder
2. Open UI, use dropdowns → logout
3. Only then treat the change as safe

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
- [ ] Logout smoke-test (main GemOrder)
- [ ] Committed and pushed to `origin/main`

---

## Cursor / agent rules

The file `.cursor/rules/git-sync.mdc` points agents at this workflow: deploy to WoW, keep versions aligned, commit and push after meaningful GemOrder work.
