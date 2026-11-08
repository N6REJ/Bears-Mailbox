local addonName = ...
local MailModule = _G.BearsMailboxMail

local function Shade(c, k)
    return { math.min(1, c[1] * k), math.min(1, c[2] * k), math.min(1, c[3] * k), 1 }
end

local function RaceTheme(name, accent, bg)
    return {
        key = name:lower(),
        name = name,
        colors = {
            bg = { bg[1], bg[2], bg[3], 0.97 },
            panel = Shade(bg, 0.6),
            row = Shade(bg, 1.6),
            rowAlt = Shade(bg, 1.3),
            button = Shade(bg, 2.4),
            border = { accent[1] * 0.5, accent[2] * 0.5, accent[3] * 0.5, 1 },
            gold = { accent[1], accent[2], accent[3], 1 },
            text = { 0.94, 0.94, 0.94, 1 },
            muted = { 0.72, 0.72, 0.74, 1 },
            disabled = { 0.4, 0.4, 0.42, 1 },
            selected = { accent[1] * 0.35, accent[2] * 0.35, accent[3] * 0.35, 1 },
        },
    }
end

MailModule.THEMES = {
    {
        key = "default",
        name = "Default",
        colors = {
            bg = { 0.04, 0.055, 0.055, 0.97 },
            panel = { 0.02, 0.03, 0.03, 1 },
            row = { 0.06, 0.075, 0.075, 1 },
            rowAlt = { 0.045, 0.06, 0.06, 1 },
            button = { 0.11, 0.13, 0.13, 1 },
            border = { 0.16, 0.19, 0.19, 1 },
            gold = { 1, 0.82, 0.1, 1 },
            text = { 0.92, 0.94, 0.94, 1 },
            muted = { 0.72, 0.75, 0.75, 1 },
            disabled = { 0.38, 0.4, 0.4, 1 },
            selected = { 0.22, 0.18, 0.04, 1 },
        },
    },
    {
        key = "blizzard",
        name = "Blizzard",
        background = "Interface\\Stationery\\StationeryTest1",
        texcoord = { 0.16, 1, 0, 1 },
        tint = { 0.98, 0.92, 0.8, 1 },
        icon = "Interface\\ChatFrame\\UI-ChatIcon-WoW",
        iconSize = { 22, 22 },
        colors = {
            bg = { 0.55, 0.42, 0.24, 0.97 },
            panel = { 0.22, 0.14, 0.07, 0.22 },
            row = { 0.30, 0.20, 0.10, 0.22 },
            rowAlt = { 0.25, 0.16, 0.08, 0.12 },
            button = { 0.42, 0.30, 0.15, 0.45 },
            border = { 0.42, 0.29, 0.13, 1 },
            gold = { 0.45, 0.28, 0.02, 1 },
            text = { 0.14, 0.09, 0.04, 1 },
            muted = { 0.32, 0.22, 0.12, 1 },
            disabled = { 0.5, 0.44, 0.36, 1 },
            selected = { 0.55, 0.38, 0.1, 0.55 },
        },
    },
    RaceTheme("Human", { 0.2, 0.45, 0.9 }, { 0.05, 0.07, 0.14 }),
    RaceTheme("Orc", { 0.75, 0.2, 0.1 }, { 0.12, 0.05, 0.04 }),
    RaceTheme("Dwarf", { 0.85, 0.6, 0.2 }, { 0.1, 0.07, 0.04 }),
    RaceTheme("NightElf", { 0.55, 0.4, 0.9 }, { 0.06, 0.04, 0.12 }),
    RaceTheme("Undead", { 0.4, 0.8, 0.3 }, { 0.05, 0.08, 0.05 }),
    RaceTheme("Tauren", { 0.6, 0.4, 0.2 }, { 0.1, 0.08, 0.04 }),
    RaceTheme("Gnome", { 0.3, 0.8, 0.9 }, { 0.04, 0.09, 0.1 }),
    RaceTheme("Troll", { 0.2, 0.7, 0.7 }, { 0.04, 0.1, 0.1 }),
    RaceTheme("Goblin", { 0.9, 0.8, 0.2 }, { 0.1, 0.1, 0.04 }),
    RaceTheme("BloodElf", { 0.9, 0.2, 0.3 }, { 0.12, 0.04, 0.06 }),
    RaceTheme("Draenei", { 0.6, 0.5, 0.95 }, { 0.07, 0.05, 0.13 }),
    RaceTheme("Worgen", { 0.6, 0.6, 0.7 }, { 0.08, 0.08, 0.09 }),
    RaceTheme("Pandaren", { 0.3, 0.7, 0.4 }, { 0.05, 0.1, 0.06 }),
    RaceTheme("Nightborne", { 0.7, 0.3, 0.9 }, { 0.09, 0.04, 0.12 }),
    RaceTheme("HighmountainTauren", { 0.5, 0.35, 0.25 }, { 0.07, 0.06, 0.05 }),
    RaceTheme("VoidElf", { 0.5, 0.2, 0.8 }, { 0.06, 0.02, 0.1 }),
    RaceTheme("LightforgedDraenei", { 1, 0.95, 0.6 }, { 0.12, 0.12, 0.08 }),
    RaceTheme("ZandalariTroll", { 0.9, 0.6, 0.2 }, { 0.1, 0.06, 0.03 }),
    RaceTheme("KulTiran", { 0.3, 0.5, 0.85 }, { 0.04, 0.06, 0.12 }),
    RaceTheme("DarkIronDwarf", { 0.8, 0.3, 0.1 }, { 0.08, 0.05, 0.04 }),
    RaceTheme("Mechagnome", { 0.7, 0.75, 0.8 }, { 0.06, 0.07, 0.08 }),
    RaceTheme("Vulpera", { 0.9, 0.5, 0.1 }, { 0.1, 0.07, 0.04 }),
    RaceTheme("MagharOrc", { 0.5, 0.8, 0.2 }, { 0.06, 0.09, 0.04 }),
    RaceTheme("Dracthyr", { 0.2, 0.8, 0.6 }, { 0.04, 0.1, 0.08 }),
}

function MailModule:FindTheme(key)
    key = string.lower(key or "")
    for _, theme in ipairs(self.THEMES) do
        if theme.key == key then return theme end
    end
    return nil
end
