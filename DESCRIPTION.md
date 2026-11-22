# ProfRoute — Cheapest Profession Leveling Route

Stop guessing what to craft. ProfRoute calculates the cheapest way to level your profession using live auction house prices, checks what's already in your bags, and hands you a shopping list.

## Features

- **Dynamic cheapest-path routing** — for every skill point, ProfRoute picks the recipe with the lowest expected cost (craft price ÷ skill-up chance). Sometimes grinding a "green" recipe is cheaper than switching — the addon does that math for you.
- **Built-in auction scanner** — scans only the items your route actually needs (10–40 items, seconds instead of minutes). Works with the auction house window open.
- **Auctionator & TSM integration** — if you already use them, ProfRoute reads their price databases first. Vendor prices are used as a fallback and a price cap.
- **Bag & bank analysis** — counts your reagents automatically and shows exactly what to buy: needed / have / missing, with per-item and total cost.
- **Clean, localized UI** — dark modern window with the route on the left and the shopping list on the right. English and Russian, auto-detected from the game client, with a manual switch in settings (⚙ button).
- **Minimap button** — one click to open, drag around the minimap to reposition.

## Supported professions (1–300)

Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring, Cooking, First Aid.

## Usage

1. Open the window via the minimap button or `/proute`
2. Pick your profession — your current skill is detected automatically
3. Press **Build plan**
4. At the auction house, press **Scan prices** to refresh reagent costs

**Commands:** `/proute` · `/proute scan` · `/proute minimap` · `/proute reset`

## Feedback & feature requests

Found a bug, a wrong recipe, or have an idea? Open an issue:
**https://github.com/LinkinDM85/ProfRoute-Forever/issues**

## Notes

ProfRoute analyzes and plans — it never crafts or buys for you (that's against Blizzard's rules). The recipe database is based on classic guides; if a recipe differs on your server, it's a one-line fix in `Data/Recipes.lua` — pull requests welcome.

**Support the project:** https://boosty.to/linkindm/donate

*World of Warcraft is a trademark of Blizzard Entertainment. This addon is not affiliated with or endorsed by Blizzard.*
