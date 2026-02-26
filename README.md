# ArenaNumbersAndTargets

A World of Warcraft TBC Anniversary addon that makes arena coordination fast and clear.

## Features

### Big numbers on nameplates
Displays a large **1 / 2 / 3** above each enemy's nameplate in arenas so you always know which target is which at a glance — no clicking, no targeting required.

### Comms panel
A small draggable button panel appears automatically when you enter an arena:

```
┌─────────────────────────┐
│ Kill  [1]  [2]  [3]     │
│ CC    [1]  [2]  [3]     │
└─────────────────────────┘
```

Click any button to instantly send a callout to your group chat — works in 2v2 and 3v3 arenas. Messages include the target's name and class so teammates without the addon can follow along too.

## Installation

Copy the `ArenaNumbersAndTargets` folder into:
```
World of Warcraft/_anniversary_/Interface/AddOns/
```
Then reload or restart the game client.

## Slash commands

| Command | Description |
|---|---|
| `/abn config` | Open the settings panel (font size, message templates) |
| `/abn status` | Show current nameplate tracking state |

## Configuration

`/abn config` lets you change:
- **Number size** — how large the nameplate numbers appear
- **Kill message template** — default: `Kill target %d`
- **CC message template** — default: `CC target %d`

`%d` is replaced by the arena target number (1, 2 or 3) when you click a button.

## License

MIT — see [LICENSE](LICENSE).

## Author

Coltsroot &lt;DS&gt;
