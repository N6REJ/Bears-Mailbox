# Bears Mailbox

[![WoW Version](https://img.shields.io/badge/WoW-Retail%20%26%20Forever-darkgreen)](https://worldofwarcraft.blizzard.com/) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) [![GitHub](https://img.shields.io/badge/GitHub-Source-blue?logo=github)](https://github.com/N6REJ/Bears-Mailbox)

A World of Warcraft mailbox addon inspired by TradeSkillMaster's mail module. It opens all mail at once, lists your inbox with item names and gold, and sends far more than the default 12 items per mail by queuing items and splitting them into multiple mails automatically.

## Features

### Standalone mailbox window
A themematic, TSM-style window with **Inbox** and **Send** tabs. It opens automatically when you visit a mailbox, and the **WoW UI** button switches back to Blizzard's mail frame. The window remembers where you moved it. The **Theme** button in the header (with the current theme's icon) switches the look on the fly; the header icon shows your character's race icon.

### Themes
- **Default** — dark TSM-style window.
- **Blizzard** — a parchment background with dark ink text and the WoW "W" icon.
- **One per race** — colour sets tuned to each playable race.
- Switch with the **Theme** button, or `/bm theme <name>` (e.g. `/bm theme blizzard`). Theme names are not translated.

### Receiving mail (Inbox tab)
- **Inbox list** showing each mail's items, time left, and gold. Items are shown as a short list of names, with a count of anything beyond that.
- **Search** filters the list by sender, subject, or item name as you type.
- **Open Mail** takes everything from the selected mail.
- **Category buttons** — All Sold, All Bought, All Cancelled, All Expired, All Other — open every mail in that group (based on the auction subject).
- **Open All** takes money and attachments from every mail, a few items at a time, then removes the mail left empty.
- **Delete Empty** removes mail with no gold and no attachments. Mail the game still considers to have attachments is left alone.
- **Auto-Open** toggles opening all mail automatically when the mailbox opens (`/bm autoopen on|off`).
- **Reply to Selected** fills in the recipient and a "Re:" subject from the selected mail and switches to the Send tab.
- Expiring mail (3 days or fewer) is noted in the debug log.

### Sending mail (Send tab)
- **Queue** — drag items from your bags into the Items box, right-click them in your bags, or press **Send all in bags** to queue everything. Click a queued item to remove it. The queue can hold any number of items.
- **Send Mail** sends the queue in mails of up to 12 items each, one after another. Gold and COD go on the first mail. Postage is shown for the number of mails needed.
- **Gold** is entered in three boxes (gold, silver, copper). **Make COD** turns the send into cash-on-delivery.
- **Subject & description** are optional and hidden until you click "+ Add subject & description".
- **Clear All** empties the queue and the fields.
- **Pending** lists items you've sent per recipient. Opening mail from that sender clears their pending entries.
- Without a queue, Send Mail sends a letter or gold to the recipient.

### Recipient helpers
- **Recipient box** suggests matching names while you type, from recent recipients, friends, and your guild roster.
- **Arrow button** opens a menu of **Friends** or **Recent**, each in a scrollable list sorted alphabetically.
- Battle.net friends are included when they have a WoW character. Cross-realm names use the `Name-Realm` format.
- Recent recipients are tracked automatically.

### Slash commands
Use these in chat. Most of the same actions are also available in the window.

| Command | Description |
|---|---|
| `/bm`, `/bmailbox`, or `/mailbox` | Show command list |
| `/bm window` or `/bm mail` | Open the standalone mailbox window |
| `/bm openall` / `/bm takeall` | Open all mail |
| `/bm send <recipient>` | Send all bag items to recipient |
| `/bm sendgold <recipient> <amount> [subject]` | Send gold |
| `/bm sendletter <recipient> <subject> \| <body>` | Send a letter |
| `/bm sendcod <recipient> <amount> [subject]` | Send cash-on-delivery |
| `/bm return <index>` | Return a mail to its sender |
| `/bm deleteempty` | Delete empty mail |
| `/bm reply <index>` | Reply to a mail |
| `/bm search <text>` | Search inbox |
| `/bm pending` / `/bm pending clear` | List / clear pending mail |
| `/bm autoopen on\|off` | Toggle auto-open |
| `/bm debug` | Show the debug log (mail events and open progress) |
| `/bm theme <name>` | Set the UI theme (default, blizzard, or a race name) |

## Minimap button
A movable minimap button (mail icon) is provided:
- **Left-click**: toggle the Mail frame.
- **Right-click**: toggle auto-open.
- **Drag**: move around the minimap.

## Compatibility
Built for **retail** (12.0.x) with `## Interface: 120105`, plus Forever support via `## Interface-Forever: 16001` (the packager generates the Forever TOC). Container, friend, and backdrop APIs use compatibility fallbacks where possible.

## Installation
1. Download or clone into your `Interface/AddOns` folder as `Bears-Mailbox`.
2. Ensure the `Libs` folder (Ace3) is present (bundled).
3. Enable the addon in-game.

## Notes
- Open All and category buttons take attachments from every slot. The game leaves taken items as empty slots, so the addon checks all of them.
- Sending uses the game's connected-realm rules. If a realm can't receive mail from your character, the game shows its own error, which appears in the status line.
- Pending mail tracking is a lightweight record of what you've sent; it doesn't scan quantities the way TSM does.
- All user-facing text is localized (enUS, deDE, enGB, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW); missing translations fall back to English.

## License
MIT License — see `LICENSE`.
