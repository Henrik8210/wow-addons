# wow-addons

World of Warcraft addon development workspace.

## Addons

### GemOrder

Guild gem ordering for **TBC Anniversary Phase 3** (Black Temple / Mount Hyjal).

Jewelcrafters receive gem orders from guild members who got new socketed gear from raids. Orders sync across the guild via addon messages.

**Commands:**
| Command | Description |
|---------|-------------|
| `/gemorder` or `/go` | Open the order window |
| `/go jc` | Toggle JC mode (manage order queue) |
| `/go sync` | Request a full sync from guild members |

**Install:** Copy or symlink `GemOrder/` into your TBC Anniversary AddOns folder:
```
C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\
```

**Open the addon:**
- Click the **gem icon** on the minimap (left-click)
- Or type `/gemorder`, `/gorder`, or `/gor`
- Right-click the minimap icon to toggle JC mode
- Shift + drag the icon to reposition it

### GemOrderTest

Parallel **bisect/debug build** of GemOrder for tracking down issues (e.g. logout taint). Uses separate saved variables and addon messages so it can run alongside development without touching main GemOrder data.

**Important:** Disable main **GemOrder** when testing GemOrderTest logout issues.

**Commands:**
| Command | Description |
|---------|-------------|
| `/gotest` or `/got` | Open the test window |
| `/gott` | Short alias |

**Install:** Copy or symlink `GemOrderTest/` into the same AddOns folder as GemOrder.

See `GemOrderTest/BISECT.txt` for version bisect notes.

See **[GEMORDER-GUIDELINES.md](GEMORDER-GUIDELINES.md)** for versioning, git sync, WoW deploy, and GemOrderTest sync workflow.

## Development

Update `## Interface:` in each `.toc` when WoW patches. Reload with `/reload`.
