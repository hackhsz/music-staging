# Shop

**What it is.** The cosmetics shop as one long scrolling page: FEATURED (the Starter Pack banner and popular passes), GAME PASSES, BEAT COIN PACKS, then STYLE (everything worn or shown off: hand items, trails, auras, arenas, moves). The four tabs across the top jump to their section and light up while it is in view. Tapping a Style card opens the item popup: the item on the pedestal with your avatar trying it on, and its buy or equip button.

**Where.** `StarterGui.Menu.Root.Holder.Shop`. Bound by `UI/Screens/ShopPanel.luau` (tabs, scroll, popup) and `UI/Screens/ShopOffers.luau` (builds the page); `Controllers/ShopController.luau` builds the entries and sends purchases. Sections and offers are `Shared/Catalogs/ShopCatalog.luau`.

**Layout.** A standalone `Panel` at 1.35:1 (2:1 on touch), never larger than 980 x 740. Its height is 1.15 of the menu holder, so on a monitor it reaches past the holder to about 92% of the screen and the page shows two rows at a time (`PhoneSize` keeps it inside the holder on touch). Header row at 0.07: `TitleTag` left, `Balance` and `CloseButton` right. The tab bar (`Sidebar`, kept under its old name) at 0.135, 0.95 x 0.068, four `Pill` tabs. `Page` fills 0.225 to 0.98. `ItemPopup` covers the tabs and page (0.025, 0.135, 0.95 x 0.845): BACK top left, the pedestal and preview on the left, name, rarity, state and a `Pill` `BuyButton` on the right.

The page is built from `Templates`: `HeaderTemplate` (pink section title), `SubheaderTemplate` (POPULAR under the banner), `HeroTemplate`, `PassRowTemplate` (2 cards), `PackRowTemplate` (4 coin packs: badge, icon, pack name, gold amount with a coin, green bonus, price) and `ItemRowTemplate` (5 item cards). A row holds `Card1`, `Card2`... and the number of cards decides how many sit in a row.

**Names the code needs** (under `Shop`).

| Path | Notes |
| --- | --- |
| `Sidebar` | the tabs; each names its section in a `Section` attribute (`featured`, `passes`, `coin_packs`, `style`), ordered by LayoutOrder, and is `Primary` while its section is in view |
| `Balance.CoinLabel`, `CloseButton` | |
| `Page` (ScrollingFrame with a `UIListLayout`) | the page measures the layout, so it scrolls to the last row |
| `Templates.{HeaderTemplate, SubheaderTemplate, HeroTemplate, PassRowTemplate, PackRowTemplate, ItemRowTemplate}` | offer cards have `Glyph`, `NameLabel`, `DescLabel` or `AmountLabel`/`BonusLabel`, `Badge.BadgeLabel` and `BuyButton.PriceLabel`; item cards have `Icon.Glyph`, `NameLabel`, `TagLabel`, `Star`, `Check` |
| `ItemPopup.{BackButton, DetailIcon.Glyph, DetailName, DetailTag, DetailState, BuyButton.BuyLabel, Preview (ViewportFrame) with WorldModel}` | |

**States.** Tab lit for the section in view. Item cards read the price (red when you can't afford it), OWNED, EQUIPPED, LOCKED or COMING SOON. A buy button is `Primary` (pink) only when it can be pressed; Robux offers stay plain while `ShopCatalog.RobuxSalesOpen` is false. The popup button reads BUY price, EQUIP, EQUIPPED, LOCKED, SOON or CLAIM.

**Still needed.** The try-on preview has no arena view. The earned items (rank and group rewards) and track unlocks are no longer shop sections; the wardrobe shows owned items.
