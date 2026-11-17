# Market (UGC)

**What it is.** The creator market on the sky islands. Each of the six stalls is either free (CLAIM STALL) or held by a player in the server, who lists up to 8 Roblox avatar items they made. Visitors buy through Roblox's own prompt; the creator gets paid and the game earns its in-experience commission. A sign over each stall shows who holds it and what it sells.

**Where.** `StarterGui.Menu.Root.Holder.Market`. Bound by `UI/Screens/MarketPanel.luau`; `Controllers/MarketController.luau` sends claims, listings and purchases; `World/StallBoards.luau` draws the island signs. Server: `Services/StallService.luau`.

**Names the code needs** (under `Market`).

| Path | Notes |
| --- | --- |
| `Tabs.Tab1..Tab6` (each with `TabLabel`), `CloseButton` | `Tabs` may carry `TabImage` and `PickedTabImage` attributes |
| `Grid.List`, `Grid.List.RowTemplate` | |
| `DetailIcon.Glyph`, `DetailName`, `DetailTag`, `DetailState`, `StatusLabel` | `DetailState` also shows the result of the last request |
| `BuyButton.BuyLabel` | one action: CLAIM STALL, R$ price, REMOVE, or a disabled reason |
| `ManageBar.IdBox` (TextBox), `ManageBar.AddButton`, `ManageBar.MyItemsButton` (TextButton), `ManageBar.ReleaseButton` | shown only on your own stall; MY ITEMS swaps the rack for your creations |

**States.** Closed ("coming soon"); free stall; someone's stall; your stall (ManageBar shown); your items (MY ITEMS: ADD TO STALL, ON YOUR STALL or SHOP ONLY); item picked.

**Rules.** One stall per player, claimed standing within 24 studs of it, kept until they leave the server. Listings are saved on the profile and follow the player to any stall. Only clothing and accessories that the player (or a group they own) created and has on sale. Studio playtests always open the market; live servers wait for `UGCPolicy.Day0Status = "open"`.

**Roblox rules this depends on.**

- The server opens the purchase prompt (`BuyListing`), so a sale only counts when it started from a stall, cost Robux, and `PlayerOwnsAssetAsync` confirms the buyer owns it afterwards. `PromptPurchaseFinished` alone is not proof.
- An item only sells here if its sale location is **Marketplace and All Experiences** (the default). "Experience By Place ID" items need this place's id on the item and the owner enabling them under Creator Dashboard > Monetization > Avatar Items. `GetProductInfoAsync` does not report the sale location, but a catalog search (`AvatarEditorService:SearchCatalogAsync`) does (`SaleLocationType`), so MY ITEMS marks the rest SHOP ONLY and listing refuses them. A group's items are not in that search, so they list unchecked.
- In-experience sales split 30% creator, 40% game owner, 30% Roblox, held for 30 days ([fees and commissions](https://create.roblox.com/docs/marketplace/marketplace-fees-and-commissions)).

**Still needed.** A sale celebration on the stall; MY ITEMS lists the first 30 of your items only.
