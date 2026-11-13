local addonName = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local BearsMailbox = _G.BearsMailbox
local MailModule = _G.BearsMailboxMail

local ATTACHMENTS_MAX_RECEIVE = _G.ATTACHMENTS_MAX_RECEIVE or 16
local ATTACHMENTS_MAX_SEND = _G.ATTACHMENTS_MAX_SEND or 12
local BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT_FILE = "Fonts\\FRIZQT__.TTF"
local FONT_SIZES = {
    GameFontNormal = 17,
    GameFontHighlight = 17,
    GameFontDisable = 17,
    GameFontNormalSmall = 15,
    GameFontNormalLarge = 20,
    GameFontNormalHuge = 24,
}
local ROWS = 13
local QUEUE_COLS = 12
local QUEUE_STEP = 66
local ROW_H = 28

local C = {}

local function ApplyTheme(key)
    local theme = MailModule:FindTheme(key) or MailModule:FindTheme("default")
    -- Clear stale keys so per-theme overrides (e.g. itemText) don't leak
    -- into themes that don't define them.
    for k in pairs(C) do C[k] = nil end
    for name, color in pairs(theme.colors) do
        C[name] = color
    end
    C.background = theme.background
    C.backgroundRight = theme.backgroundRight
    C.tint = theme.tint or { 1, 1, 1, 1 }
    C.texcoord = theme.texcoord
    C.texcoordRight = theme.texcoordRight
end
ApplyTheme("default")

local function Box(f, bg, border)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(unpack(bg or C.bg))
    f:SetBackdropBorderColor(unpack(border or C.border))
end

local function NewBox(parent, bg, border)
    local f = CreateFrame("Frame", nil, parent, BACKDROP)
    Box(f, bg, border)
    return f
end

local function Text(parent, font, color, justify)
    font = font or "GameFontNormal"
    color = color or C.text
    -- (No hard outline on gold text; the drop shadow provides contrast.)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetFont(FONT_FILE, FONT_SIZES[font] or 15, "")
    fs:SetTextColor(unpack(color))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetShadowOffset(0, 0)
    return fs
end

local function NewButton(parent, label, w, h)
    local b = CreateFrame("Button", nil, parent, BACKDROP)
    b:SetSize(w, h)
    Box(b, { C.button[1], C.button[2], C.button[3], 1 }, C.border)
    b.label = Text(b, "GameFontNormal", C.buttonText or C.text, "CENTER")
    b.label:SetPoint("CENTER")
    b.label:SetText(label)
    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then self:SetBackdropBorderColor(unpack(C.gold)) end
    end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    b:SetScript("OnEnable", function(self) self.label:SetTextColor(unpack(C.buttonText or C.text)) end)
    b:SetScript("OnDisable", function(self) self.label:SetTextColor(unpack(C.disabled)) end)
    return b
end

local function NewLink(parent, label, w, h, color, justify, font, bg)
    local b = CreateFrame("Button", nil, parent, bg and BACKDROP or nil)
    b:SetSize(w, h)
    if bg then Box(b, bg, C.border) end
    b.label = Text(b, font or "GameFontNormal", color or C.gold, justify or "CENTER")
    b.label:SetAllPoints()
    b.label:SetText(label)
    b:SetScript("OnEnter", function(self) self.label:SetAlpha(0.7) end)
    b:SetScript("OnLeave", function(self) self.label:SetAlpha(1) end)
    return b
end

local function NewInput(parent, w, h, placeholder)
    local eb = CreateFrame("EditBox", nil, parent, BACKDROP)
    eb:SetSize(w, h)
    Box(eb, { 0.92, 0.88, 0.78, 1 }, { 0, 0, 0, 1 })
    eb:SetFont(FONT_FILE, FONT_SIZES.GameFontHighlight, "")
    eb:SetTextColor(0, 0, 0, 1)
    eb:SetShadowOffset(0, 0)
    eb:SetAutoFocus(false)
    eb:SetTextInsets(8, 8, 0, 0)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEnterPressed", eb.ClearFocus)
    eb:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(C.gold)) end)
    eb:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(0, 0, 0, 1) end)
    if placeholder then
        eb.placeholder = Text(eb, "GameFontDisable", { 0, 0, 0, 1 })
        eb.placeholder:SetPoint("LEFT", 8, 0)
        eb.placeholder:SetShadowOffset(0, 0)
        eb.placeholder:SetText(placeholder)
        eb:SetScript("OnTextChanged", function(self)
            self.placeholder:SetShown(self:GetText() == "")
        end)
    end
    return eb
end

local function NewCheck(parent, label)
    local b = CreateFrame("Button", nil, parent, BACKDROP)
    Box(b, { C.button[1], C.button[2], C.button[3], 1 }, C.border)
    b.box = NewBox(b, C.panel, C.border)
    b.box:SetSize(16, 16)
    b.box:SetPoint("LEFT", 6, 0)
    b.innerBorder = NewBox(b.box, { 0, 0, 0, 0 }, { 1, 1, 1, 1 })
    b.innerBorder:SetPoint("TOPLEFT", b.box, "TOPLEFT", 1, -1)
    b.innerBorder:SetPoint("BOTTOMRIGHT", b.box, "BOTTOMRIGHT", -1, 1)
    b.label = Text(b, "GameFontNormal", { 1, 1, 1, 1 })
    b.label:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
    b.label:SetText(label)
    b:SetSize(b.label:GetStringWidth() + 44, 30)
    b.checked = false
    function b:SetChecked(v)
        self.checked = v and true or false
        if self.checked then
            self.box:SetBackdropColor(1, 1, 1, 1)
        else
            self.box:SetBackdropColor(unpack(C.panel))
        end
    end
    function b:GetChecked() return self.checked end
    b:SetScript("OnClick", function(self) self:SetChecked(not self:GetChecked()) end)
    return b
end

local function FormatMoney(copper)
    copper = math.floor(tonumber(copper) or 0)
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100)
end

local function FormatMoneyText(copper)
    copper = math.floor(tonumber(copper) or 0)
    local g = math.floor(copper / 10000)
    local s = math.floor(copper % 10000 / 100)
    local c = copper % 100
    return string.format("|cff333333%d|r|TInterface/MoneyFrame/UI-GoldIcon:12:12|t |cff333333%d|r|TInterface/MoneyFrame/UI-SilverIcon:12:12|t |cff333333%d|r|TInterface/MoneyFrame/UI-CopperIcon:12:12|t", g, s, c)
end

local function CopperFromFields(ui)
    return (tonumber(ui.goldG:GetText()) or 0) * 10000
        + (tonumber(ui.goldS:GetText()) or 0) * 100
        + (tonumber(ui.goldC:GetText()) or 0)
end

local function ReadHeader(i)
    local _, _, sender, subject, money, cod, days, hasItem = GetInboxHeaderInfo(i)
    return sender or "", subject or "", money or 0, cod or 0, days or 0, hasItem
end

local function ReadItems(i)
    local names, icon = {}, nil
    for j = 1, ATTACHMENTS_MAX_RECEIVE do
        local name, _, tex, count = GetInboxItem(i, j)
        if name then
            icon = icon or tex
            names[#names + 1] = name .. ((count or 1) > 1 and (" x" .. count) or "")
        end
    end
    return names, icon
end

local function SubjectPrefix(fmt, fallback)
    local p = (fmt or fallback):match("^(.-)%%s")
    if p and p ~= "" then return p end
    return nil
end

local CATEGORY_PREFIX = {
    Sold = SubjectPrefix(_G.AUCTION_SOLD_MAIL_SUBJECT, "Auction successful: %s"),
    Bought = SubjectPrefix(_G.AUCTION_WON_MAIL_SUBJECT, "Auction won: %s"),
    Cancelled = SubjectPrefix(_G.AUCTION_CANCELLED_MAIL_SUBJECT, "Auction cancelled: %s"),
    Expired = SubjectPrefix(_G.AUCTION_EXPIRED_MAIL_SUBJECT, "Auction expired: %s"),
}
local CATEGORY_ORDER = { "Sold", "Bought", "Cancelled", "Expired" }

local function CategoryOf(subject)
    for _, key in ipairs(CATEGORY_ORDER) do
        local p = CATEGORY_PREFIX[key]
        if p and subject:sub(1, #p) == p then return key end
    end
    return "Other"
end

local function ExpiresText(days)
    if days >= 1 then return string.format("%d days", math.floor(days)) end
    return string.format("%d hrs", math.max(1, math.floor(days * 24)))
end

local function ItemsText(m)
    if #m.items == 0 then return m.money > 0 and "" or L["Empty"] end
    local shown = {}
    for k = 1, math.min(2, #m.items) do shown[k] = m.items[k] end
    local s = table.concat(shown, ", ")
    if #m.items > 2 then s = s .. " (+" .. (#m.items - 2) .. ")" end
    return s
end

local function MailMatches(m, q)
    if string.find(string.lower(m.sender), q, 1, true) or string.find(string.lower(m.subject), q, 1, true) then
        return true
    end
    for _, n in ipairs(m.items) do
        if string.find(string.lower(n), q, 1, true) then return true end
    end
    return false
end

function MailModule:GetInboxData()
    local list = {}
    if self.testMode then
        local senders = { "Auction House", "Guild Bank", "Thrall", "Jaina", "Mailbox", "Postmaster" }
        local subjects = { "Auction successful", "Guild deposit", "Hello", "Re: our raid", "Your mailbox", "COD payment", "Gift", "Reminder" }
        local icons = { "Interface\\Icons\\INV_Misc_Coin_01", "Interface\\Icons\\INV_Misc_Bag_08", "Interface\\Icons\\INV_Letter_15", "Interface\\Icons\\INV_Sword_04", "Interface\\Icons\\INV_Misc_Gem_01" }
        for i = 1, 24 do
            local hasItem = (i % 2 == 0)
            local items = {}
            if hasItem then
                items = { "Item " .. i .. " x" .. ((i % 3) + 1), "Extra " .. i }
            end
            list[#list + 1] = {
                index = i, sender = senders[(i % 6) + 1], subject = subjects[((i - 1) % 8) + 1],
                money = (i % 3 == 0) and (i * 1234) or 0, cod = 0,
                days = 30 - (i % 29), items = items, icon = icons[(i % 5) + 1],
                category = "Other",
            }
        end
        return list
    end
    local num = GetInboxNumItems() or 0
    for i = 1, num do
        local sender, subject, money, cod, days = ReadHeader(i)
        local items, icon = ReadItems(i)
        list[#list + 1] = {
            index = i, sender = sender, subject = subject, money = money, cod = cod,
            days = days, items = items, icon = icon, category = CategoryOf(subject),
        }
    end
    return list
end

function MailModule:CategoryFilter(category)
    return function(i)
        local _, subject, money, cod, _, hasItem = ReadHeader(i)
        return (cod or 0) == 0 and (money > 0 or (hasItem or 0) > 0) and CategoryOf(subject) == category
    end
end

function MailModule:OpenFiltered(filter, limit)
    if self.opening then return end
    self.opening = true
    self.addon.opening = true
    local steps = 0
    local tries = {}
    local BATCH = 4
    local step

    local function finish()
        self.opening = false
        self.addon.opening = false
        self.openResume = nil
        C_Timer.After(0.5, function()
            self:DeleteEmptyMail()
            MailModule:Notify(L["Bears Mailbox: done."])
            self:RefreshInbox()
        end)
    end

    local function takeOne()
        local num = GetInboxNumItems() or 0
        for i = 1, num do
            if filter(i) then
                local sender, _, money, _, _, hasItem = ReadHeader(i)
                if money > 0 then
                    local key = i .. "|money|" .. tostring(money)
                    if (tries[key] or 0) < 10 then
                        tries[key] = (tries[key] or 0) + 1
                        if sender ~= "" then self:ClearPending(sender) end
                        TakeInboxMoney(i)
                        return true
                    end
                end
                for j = 1, ATTACHMENTS_MAX_RECEIVE do
                    if GetInboxItem(i, j) then
                        local key = i .. "|" .. j .. "|" .. tostring(hasItem)
                        if (tries[key] or 0) < 10 then
                            tries[key] = (tries[key] or 0) + 1
                            if sender ~= "" then self:ClearPending(sender) end
                            TakeInboxItem(i, j)
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    local function nextBatch()
        local taken = 0
        while taken < BATCH and takeOne() do
            taken = taken + 1
        end
        return taken
    end

    local function wait()
        local resumed = false
        local function resume()
            if resumed or not self.opening then return end
            resumed = true
            self.openResume = nil
            C_Timer.After(0.05, step)
        end
        self.openResume = resume
        C_Timer.After(0.2, resume)
    end

    step = function()
        if not self.opening then return end
        steps = steps + 1
        if steps > 100000 or nextBatch() == 0 then
            finish()
            return
        end
        wait()
    end

    step()
end

function MailModule:OpenCategory(category)
    self:OpenFiltered(self:CategoryFilter(category))
end

function MailModule:OpenSelected(index)
    if not index then return end
    if self.ui then self.ui.selected = nil end
    self:OpenFiltered(function(i) return i == index end, 1)
end

local function SortedCopy(list)
    local copy = {}
    for _, name in ipairs(list) do
        if name and name ~= "" then table.insert(copy, name) end
    end
    table.sort(copy, function(a, b) return string.lower(a) < string.lower(b) end)
    return copy
end

local function GuildMemberNames()
    local names = {}
    if IsInGuild and IsInGuild() then
        if GuildRoster then GuildRoster() end
        local num = GetNumGuildMembers and GetNumGuildMembers() or 0
        for i = 1, num do
            local name = GetGuildRosterInfo(i)
            if name then table.insert(names, name) end
        end
    end
    return names
end

local SUGGEST_MAX = 8

function MailModule:GetSuggestions(query)
    local q = string.lower(query)
    local seen, prefix, contains = {}, {}, {}
    local function consider(name)
        if not name or seen[name] then return end
        local pos = string.find(string.lower(name), q, 1, true)
        if pos then
            seen[name] = true
            if pos == 1 then
                table.insert(prefix, name)
            else
                table.insert(contains, name)
            end
        end
    end
    for _, n in ipairs(self:GetRecentRecipients()) do consider(n) end
    for _, n in ipairs(self.CompatGetFriends()) do consider(n) end
    for _, n in ipairs(GuildMemberNames()) do consider(n) end
    local result = {}
    for _, list in ipairs({ SortedCopy(prefix), SortedCopy(contains) }) do
        for _, name in ipairs(list) do
            if #result < SUGGEST_MAX then table.insert(result, name) end
        end
    end
    return result
end

function MailModule:UpdateSuggestions(box)
    local ui = self.ui
    if not ui then return end
    local text = strtrim(box:GetText() or "")
    if text == "" or not box:HasFocus() then
        ui.suggest:Hide()
        return
    end
    local list = self:GetSuggestions(text)
    if #list == 0 then
        ui.suggest:Hide()
        return
    end
    for i, row in ipairs(ui.suggestRows) do
        if list[i] then
            row.name = list[i]
            row.label:SetText(list[i])
            row:Show()
        else
            row:Hide()
        end
    end
    ui.suggest:SetHeight(#list * 28 + 2)
    ui.suggest:Show()
end

local function NewContactWindow(ui)
    local textured = C.background and (MailModule.addon.db.profile.theme ~= "blizzard")
    local ci = textured and 50 or 10
    if textured and MailModule.addon.db.profile.theme == "horde" then ci = ci + 6 end
    if textured and MailModule.addon.db.profile.theme == "bloodelf" then ci = ci + 15 end
    local ct = textured and 30 or 0
    local wh = textured and (MailModule.addon.db.profile.theme == "earthen" and 450 or 430) or 430
    local w = CreateFrame("Frame", "BearsMailboxContactWindow", ui.frame, BACKDROP)
    w:SetSize(360, wh)
    w:SetPoint("CENTER", ui.frame, "CENTER")
    w:SetFrameStrata("DIALOG")
    w:EnableMouse(true)
    if C.background then
        Box(w, { C.bg[1], C.bg[2], C.bg[3], 0 }, C.gold)
        if w.Center then
            w.Center:SetTexture(C.background)
            if C.texcoord then w.Center:SetTexCoord(unpack(C.texcoord)) end
            w.Center:SetVertexColor(C.tint[1], C.tint[2], C.tint[3], C.tint[4] or 1)
        end
    else
        Box(w, C.bg, C.gold)
    end
    w:Hide()

    w.inner = CreateFrame("Frame", nil, w, BACKDROP)
    w.inner:SetPoint("TOPLEFT", w, "TOPLEFT", ci, -40 - ct)
    w.inner:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -ci, 10)
    w.inner:SetFrameLevel(w:GetFrameLevel() + 5)
    Box(w.inner, { 0, 0, 0, 0 }, { C.border[1] * 0.6, C.border[2] * 0.6, C.border[3] * 0.6, C.border[4] })

    w.titleBg = CreateFrame("Frame", nil, w, BACKDROP)
    Box(w.titleBg, { C.button[1], C.button[2], C.button[3], 0.9 }, C.border)
    w.titleBg:SetPoint("TOPLEFT", w, "TOPLEFT", ci, -20 - ct)
    w.titleBg:SetPoint("TOPRIGHT", w, "TOPRIGHT", -ci, -20 - ct)
    w.titleBg:SetHeight(24)

    w.title = Text(w.titleBg, "GameFontNormalLarge", C.buttonText or C.text)
    w.title:SetDrawLayer("OVERLAY", 7)
    w.title:SetPoint("LEFT", w.titleBg, "LEFT", 4, 0)

    local closeColor = (MailModule.addon.db.profile.theme == "default") and C.text or { 1, 1, 1, 1 }
    local close = NewLink(w, "X", 24, 24, closeColor, "CENTER", "GameFontNormalLarge")
    close:SetPoint("RIGHT", w.titleBg, "RIGHT", -4, 0)
    close:SetScript("OnClick", function() w:Hide() end)

    w.scroll = CreateFrame("ScrollFrame", nil, w)
    w.scroll:SetPoint("TOPLEFT", w, "TOPLEFT", ci, -44 - ct)
    w.scroll:SetSize(360 - 2 * ci, 308)
    w.scroll:EnableMouseWheel(true)
    w.scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, w.content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 28)))
    end)

    w.content = CreateFrame("Frame", nil, w.scroll)
    w.content:SetSize(360 - 2 * ci, 28)
    w.scroll:SetScrollChild(w.content)

    w.empty = Text(w, "GameFontNormal", { 0, 0, 0, 1 }, "CENTER")
    w.empty:SetPoint("CENTER", 0, 0)
    w.empty:SetText(L["Nobody to show"])

    w.rows = {}
    w.ci = ci
    w.ct = ct
    -- Catcher so clicking anywhere outside the contacts window closes it.
    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:SetFrameLevel(0)
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown", function() w:Hide() end)
    catcher:Hide()
    w._catcher = catcher
    w:HookScript("OnShow", function() if w._catcher then w._catcher:Show() end end)
    w:HookScript("OnHide", function() if w._catcher then w._catcher:Hide() end end)
    return w
end

function MailModule:ShowContactList(ui, title, names)
    local w = ui.contactWindow or NewContactWindow(ui)
    ui.contactWindow = w
    w.title:SetText(title)
    for i, name in ipairs(names) do
        local row = w.rows[i]
        if not row then
            row = CreateFrame("Button", nil, w.content)
            row:SetSize((w.ci and (360 - 2 * w.ci)) or 340, 28)
            row:SetPoint("TOPLEFT", w.content, "TOPLEFT", 0, -((i - 1) * 28))
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetTexture(WHITE)
            row.bg:SetAllPoints()
            row._even = (i % 2 == 0)
            if row._even then
                row.bg:SetVertexColor(0.32, 0.32, 0.32, 0.15)
            else
                row.bg:SetVertexColor(0, 0, 0, 0)
            end
            row.label = Text(row, "GameFontNormal", { 0, 0, 0, 1 })
            row.label:SetPoint("LEFT", 10, 0)
            row:SetScript("OnEnter", function(self) self.bg:SetVertexColor(0.5, 0.5, 0.5, 0.5) end)
            row:SetScript("OnLeave", function(self)
                if self._even then
                    self.bg:SetVertexColor(0.32, 0.32, 0.32, 0.15)
                else
                    self.bg:SetVertexColor(0, 0, 0, 0)
                end
            end)
            row:SetScript("OnClick", function(self)
                ui.recipient:SetText(self.name)
                w:Hide()
            end)
            w.rows[i] = row
        end
        row.name = name
        row.label:SetText(name)
        row:Show()
    end
    w.empty:SetShown(#names == 0)
    for i = #names + 1, #w.rows do w.rows[i]:Hide() end
    w.content:SetHeight(math.max(28, #names * 28))
    w.empty:SetShown(#names == 0)
    w.scroll:SetVerticalScroll(0)
    w:Show()
end

function MailModule:ShowContactsMenu(anchor, ui)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        MailModule:Notify(L["Bears Mailbox: type a recipient name."])
        return
    end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateButton(L["Friends"], function()
            self:ShowContactList(ui, L["Friends"], SortedCopy(self.CompatGetFriends()))
        end)
        root:CreateButton(L["Recent"], function()
            self:ShowContactList(ui, L["Recent"], SortedCopy(self:GetRecentRecipients()))
        end)
    end)
end

function MailModule:RefreshInbox()
    local ui = self.ui
    if not ui or not ui.frame or not ui.frame:IsShown() then return end

    local data = self:GetInboxData()
    local query = string.lower(strtrim(ui.search:GetText() or ""))
    local visible, byIndex = {}, {}
    local withContent, items, gold = 0, 0, 0
    for _, m in ipairs(data) do
        byIndex[m.index] = m
        if #m.items > 0 or m.money > 0 then withContent = withContent + 1 end
        items = items + #m.items
        gold = gold + m.money
        if query == "" or MailMatches(m, query) then visible[#visible + 1] = m end
    end

    if ui.selected and not byIndex[ui.selected] then ui.selected = nil end

    local _g = math.floor(gold / 10000)
    local _s = math.floor(gold % 10000 / 100)
    local _c = gold % 100
    ui.statusText:SetText(string.format(L["|cff333333%d/%d Mail      %d Items      Gold: |cff996600%d|r|TInterface/MoneyFrame/UI-GoldIcon:12:12|t |cff666666%d|r|TInterface/MoneyFrame/UI-SilverIcon:12:12|t |cff804000%d|r|TInterface/MoneyFrame/UI-CopperIcon:12:12|t"],
        withContent, #data, items, _g, _s, _c))

    local maxOffset = math.max(0, #visible - ROWS)
    ui.offset = math.min(math.max(ui.offset or 0, 0), maxOffset)

    if ui.inboxScrollBar then
        ui._inboxScrolling = true
        ui.inboxScrollBar:SetMinMaxValues(0, maxOffset)
        ui.inboxScrollBar:SetValue(ui.offset or 0)
        ui.inboxScrollBar:SetShown(maxOffset > 0)
        ui._inboxScrolling = false
    end

    for r = 1, ROWS do
        local row = ui.rows[r]
        local m = visible[ui.offset + r]
        row.mail = m
        if m then
            row:Show()
            row.icon:SetTexture(m.icon)
            row.icon:SetShown(m.icon ~= nil)
            row.items:SetText(ItemsText(m))
            row.expires:SetText(ExpiresText(m.days))
            row.gold:SetText(m.money > 0 and FormatMoney(m.money) or "")
            if ui.selected == m.index then
                row.bg:SetVertexColor(unpack(C.selected))
            elseif r % 2 == 0 then
                row.bg:SetVertexColor(unpack(C.row))
            else
                row.bg:SetVertexColor(unpack(C.rowAlt))
            end
        else
            row:Hide()
        end
    end

    ui.empty:SetText(#data == 0 and L["Your mailbox is empty"] or L["No mail matches your search"])
    ui.empty:SetShown(#visible == 0)

    local sel = ui.selected and byIndex[ui.selected]
    local canOpen = sel and sel.cod == 0 and (#sel.items > 0 or sel.money > 0) and not self.opening
    ui.openBtn:SetEnabled(canOpen and true or false)

    local on = self.addon.db.profile.autoOpen
    ui.autoBtn.label:SetText(on and L["Auto-Open: On"] or L["Auto-Open: Off"])
end

function MailModule:IsQueuing()
    local ui = self.ui
    return ui and ui.frame and ui.frame:IsShown() and ui.activeTab == "Send" and MailFrame and MailFrame:IsShown()
end

function MailModule:QueueItem(bag, slot)
    local ui = self.ui
    if not ui then return end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or not info.hyperlink then return end
    for _, e in ipairs(ui.queue) do
        if e.bag == bag and e.slot == slot then return end
    end
    table.insert(ui.queue, {
        bag = bag, slot = slot, link = info.hyperlink, itemID = info.itemID,
        icon = info.iconFileID, count = info.stackCount or 1,
    })
    self:RefreshQueue()
end

function MailModule:QueueFromCursor()
    local ui = self.ui
    if not ui or not CursorHasItem() then return end
    local pick = ui.lastPickup
    ui.lastPickup = nil
    local cursorType, itemID = GetCursorInfo()
    if pick and cursorType == "item" then
        local info = C_Container.GetContainerItemInfo(pick.bag, pick.slot)
        if info and info.itemID == itemID then
            self:QueueItem(pick.bag, pick.slot)
            ClearCursor()
        end
    end
end

function MailModule:QueueAllBags()
    local ui = self.ui
    if not ui then return end
    local before = #ui.queue
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            self:QueueItem(bag, slot)
        end
    end
    MailModule:Notify(string.format(L["Bears Mailbox: queued %d items. Press Send Mail to send."], #ui.queue - before))
end

function MailModule:RemoveQueued(index)
    local ui = self.ui
    if not ui then return end
    table.remove(ui.queue, index)
    self:RefreshQueue()
end

function MailModule:RefreshQueue()
    local ui = self.ui
    if not ui or not ui.queueContent then return end
    local queue = ui.queue
    -- Jump to the bottom only when new items are actually added.
    local prevCount = ui._queueCount or 0
    local added = #queue > prevCount
    ui._queueCount = #queue
    -- Fit the grid inside the (possibly inset) item panel, reserving 16px
    -- on the right for the scrollbar.
    local itemsW = (ui.itemsBox and ui.itemsBox:GetWidth()) or 860
    if itemsW < QUEUE_STEP then itemsW = 860 end
    local availW = itemsW - 16
    if availW < QUEUE_STEP then availW = itemsW end
    local cols = math.max(1, math.min(QUEUE_COLS, math.floor(availW / QUEUE_STEP)))
    ui.queueContent:SetWidth(availW)
    for i, e in ipairs(queue) do
        local cell = ui.queueCells[i] or NewQueueCell(ui, i)
        cell.index = i
        cell.entry = e
        cell.icon:SetTexture(e.icon)
        cell.count:SetText(e.count > 1 and e.count or "")
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", ui.queueContent, "TOPLEFT",
            ((i - 1) % cols) * QUEUE_STEP, -math.floor((i - 1) / cols) * QUEUE_STEP)
        cell:Show()
    end
    for i = #queue + 1, #ui.queueCells do ui.queueCells[i]:Hide() end
    local contentH = math.max(QUEUE_STEP, math.ceil(#queue / cols) * QUEUE_STEP)
    ui.queueContent:SetHeight(contentH)
    local maxScroll = math.max(0, contentH - (ui.queueScroll and ui.queueScroll:GetHeight() or 0))
    if added and ui.queueScroll then
        ui.queueScroll:SetVerticalScroll(maxScroll)
    elseif ui.queueScroll and ui.queueScroll:GetVerticalScroll() > maxScroll then
        ui.queueScroll:SetVerticalScroll(maxScroll)
    end
    if ui.queueScrollBar then
        ui._scrolling = true
        ui.queueScrollBar:SetMinMaxValues(0, maxScroll)
        ui.queueScrollBar:SetValue(ui.queueScroll and ui.queueScroll:GetVerticalScroll() or 0)
        ui.queueScrollBar:SetShown(maxScroll > 0)
        ui._scrolling = false
    end
    ui.attachEmpty:SetShown(#queue == 0)
    local mails = math.max(1, math.ceil(#queue / ATTACHMENTS_MAX_SEND))
    ui.postage:SetText(string.format(L["Total Postage: %s"], FormatMoneyText(30 * mails)))
end

function MailModule:SendFromUI()
    local ui = self.ui
    local recipient = strtrim(ui.recipient:GetText() or "")
    if recipient == "" then
        MailModule:Notify(L["Bears Mailbox: enter a recipient name first."])
        return
    end
    local copper = CopperFromFields(ui)
    local subject = ui.detailsShown and strtrim(ui.subject:GetText() or "") or ""
    if subject == "" then subject = MailModule:DefaultSubject() end
    local body = ui.detailsShown and (ui.body:GetText() or "") or ""
    local cod = ui.cod:GetChecked()

    if #ui.queue == 0 then
        if cod then
            self:SendCOD(recipient, copper, subject, body)
        else
            self:SendLetter(recipient, subject, body, copper)
        end
        return
    end

    if self.sending then
        MailModule:Notify(L["Bears Mailbox: still sending."])
        return
    end

    local entries = {}
    for _, e in ipairs(ui.queue) do
        local info = C_Container.GetContainerItemInfo(e.bag, e.slot)
        if info and info.hyperlink == e.link then
            table.insert(entries, { bag = e.bag, slot = e.slot })
        end
    end
    ui.queue = {}
    self:RefreshQueue()
    if #entries == 0 then
        MailModule:Notify(L["Bears Mailbox: queued items are no longer in your bags."])
        return
    end

    self:AddRecentRecipient(recipient)
    self.sendQueue = entries
    self.sendIndex = 1
    self.sendRecipient = recipient
    self.sendSubject = subject
    self.sendExtras = { body = body, money = copper, cod = cod }
    self.sending = true
    self.addon.sending = true
    MailModule:Notify(string.format(L["Bears Mailbox: sending %d items to %s..."], #entries, recipient))
    ClearSendMail()
    self:SendNextBatch()
end

function MailModule:HideBlizzardMail()
    if not MailFrame then return end
    if not MailModule.mailFrameHideHooked then
        MailModule.mailFrameHideHooked = true
        -- Blizzard's MailFrame stays "shown" (alpha 0, off-screen) while our
        -- window is open, so pressing Escape closes MailFrame first and the
        -- mailbox window would otherwise stay open. Mirror its close.
        MailFrame:HookScript("OnHide", function()
            local ui = MailModule.ui
            if ui and ui.frame and ui.frame:IsShown() then
                ui.frame:Hide()
            end
        end)
    end
    if not self.blizzAnchor then
        local point, rel, relPoint, x, y = MailFrame:GetPoint(1)
        if point then self.blizzAnchor = { point, rel, relPoint, x, y } end
    end
    MailFrame:SetAlpha(0)
    MailFrame:ClearAllPoints()
    MailFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 0)
end

function MailModule:RestoreBlizzardMail()
    if not MailFrame then return end
    MailFrame:SetAlpha(1)
    if self.blizzAnchor then
        local a = self.blizzAnchor
        MailFrame:ClearAllPoints()
        MailFrame:SetPoint(a[1], a[2], a[3], a[4], a[5])
    end
end

function MailModule:Notify(msg)
    local ui = self.ui
    if ui and ui.frame and ui.frame:IsShown() then
        ui.message:SetText(msg)
    else
        print(msg)
    end
end

local function BuildInbox(parent, ui)
    local function _inboxPad(side)
        local t = MailModule.addon.db.profile.theme
        if t == "default" or t == "blizzard" or t == "darkirondwarf" or t == "draenei" or t == "dwarf" or t == "gnome" or t == "human" or t == "lightforgeddraenei" or t == "nightelf" or t == "vulpera" then return 0 end
        local base = 75
        if t == "horde" then base = base + 50 end
        if t == "earthen" or t == "goblin" then base = 85 end
        if side == "l" and t == "earthen" then base = base + 20 end
        if side == "r" and t == "earthen" then base = base + 20 end
        if t == "highmountaintauren" then base = 70 end
        if t == "skyborne" then base = base - 15 end
        if t == "tauren" then
            base = base + 70
            if side == "l" then base = base - 30 end
            if side == "r" then base = base + 5 end
        end
        if t == "troll" then
            if side == "l" then base = base + 24 end
            if side == "r" then base = base + 32 end
        end
        if side == "r" and t == "kultiran" then base = base + 10 end
        if side == "r" and t == "orc" then base = base + 20 end
        if side == "r" and t == "undead" then base = base + 16 end
        if side == "r" and t == "worgen" then base = base + 32 end
        if t == "zandalaritroll" then base = base + 32 end
        return base
    end
    local inboxPadL = _inboxPad("l")
    local inboxPadR = _inboxPad("r")
    local earthenY = (MailModule.addon.db.profile.theme == "earthen") and 12 or 0
    local allianceY = (MailModule.addon.db.profile.theme == "alliance") and 10 or 0
    local alliancePanelY = (MailModule.addon.db.profile.theme == "alliance") and 15 or 0
    local allianceStatusY = (MailModule.addon.db.profile.theme == "alliance") and 10 or 0
    local isEarthen = (MailModule.addon.db.profile.theme == "earthen")
    local hasInset = (inboxPadL > 0 or inboxPadR > 0)
    local searchPadL, searchPadR = inboxPadL, inboxPadR
    local searchOffY = -2
    if MailModule.addon.db.profile.theme == "alliance" then
        searchPadL, searchPadR = searchPadL + 60, searchPadR + 60
        searchOffY = -12 - allianceY
    end
    local searchW, searchX, searchY, searchH
    if isEarthen then
        searchW, searchX, searchY, searchH = 860 - inboxPadL - inboxPadR - 64, inboxPadL + 32, -26, 28
    elseif hasInset then
        searchW, searchX, searchY, searchH = 860 - searchPadL - searchPadR, searchPadL, searchOffY, 34
    else
        searchW, searchX, searchY, searchH = 860, 0, searchOffY, 34
    end
    ui.search = NewInput(parent, searchW, searchH, L["Search items in mailbox"])
    ui.search:SetPoint("TOPLEFT", parent, "TOPLEFT", searchX, searchY)
    -- Slightly recessed look: darker fill plus a soft inner shadow on the top/left.
    if isEarthen then
        -- Deeper recess so it reads against the parchment artwork.
        ui.search:SetBackdropColor(0.70, 0.64, 0.53, 1)
    else
        ui.search:SetBackdropColor(0.82, 0.77, 0.66, 1)
    end
    local recessAlpha = isEarthen and 0.45 or 0.30
    local recessTop = ui.search:CreateTexture(nil, "BORDER")
    recessTop:SetTexture(WHITE)
    recessTop:SetVertexColor(0, 0, 0, recessAlpha)
    recessTop:SetPoint("TOPLEFT", ui.search, "TOPLEFT", 1, -1)
    recessTop:SetPoint("TOPRIGHT", ui.search, "TOPRIGHT", -1, -1)
    recessTop:SetHeight(2)
    local recessLeft = ui.search:CreateTexture(nil, "BORDER")
    recessLeft:SetTexture(WHITE)
    recessLeft:SetVertexColor(0, 0, 0, recessAlpha)
    recessLeft:SetPoint("TOPLEFT", ui.search, "TOPLEFT", 1, -3)
    recessLeft:SetPoint("BOTTOMLEFT", ui.search, "BOTTOMLEFT", 1, 1)
    recessLeft:SetWidth(2)
    ui.search:SetTextInsets(34, 8, 0, 0)
    ui.search.placeholder:ClearAllPoints()
    ui.search.placeholder:SetPoint("LEFT", 34, 0)
    local searchIcon = parent:CreateTexture(nil, "OVERLAY")
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetSize(18, 18)
    searchIcon:SetPoint("LEFT", ui.search, "LEFT", 10, 0)
    ui.search:HookScript("OnTextChanged", function() MailModule:RefreshInbox() end)

    local headerBar = NewBox(parent, { 0.92, 0.88, 0.78, 0.65 }, C.border)
    headerBar:SetSize(860 - inboxPadL - inboxPadR, 26)
    headerBar:SetPoint("TOPLEFT", parent, "TOPLEFT", inboxPadL, -44 - earthenY - alliancePanelY)
    local EXPIRES_W = 102
    local EXPIRES_RIGHT = 140
    local taurenItemInset = (MailModule.addon.db.profile.theme == "tauren") and 11 or 0
    local hItems = Text(headerBar, "GameFontNormalSmall", { 0, 0, 0, 1 })
    hItems:SetPoint("LEFT", 12 + taurenItemInset, 0)
    hItems:SetText(L["Items"])
    local hExpires = Text(headerBar, "GameFontNormalSmall", { 0, 0, 0, 1 }, "RIGHT")
    hExpires:SetWidth(EXPIRES_W)
    hExpires:SetPoint("RIGHT", headerBar, "RIGHT", -EXPIRES_RIGHT, 0)
    hExpires:SetText(L["Expires"])
    local hGold = Text(headerBar, "GameFontNormalSmall", { 0, 0, 0, 1 })
    hGold:SetPoint("RIGHT", headerBar, "RIGHT", -12, 0)
    hGold:SetText(L["Gold"])

    ui.list = NewBox(parent, C.panel, C.border)
    ui.list:SetSize(860 - inboxPadL - inboxPadR, ROWS * ROW_H)
    ui.list:SetPoint("TOPLEFT", parent, "TOPLEFT", inboxPadL, -70 - earthenY - alliancePanelY)
    ui.list:EnableMouse(true)
    ui.list:EnableMouseWheel(true)
    ui.list:SetScript("OnMouseWheel", function(_, delta)
        ui.offset = (ui.offset or 0) - delta
        MailModule:RefreshInbox()
    end)
    -- Visible scrollbar on the outside right edge of the list frame.
    local inboxThumbColor = (MailModule.addon.db.profile.theme == "default" or MailModule.addon.db.profile.theme == "blizzard") and { 0.2, 0.2, 0.2, 0.9 } or { 0, 0, 0, 0.95 }
    ui.inboxScrollBar = CreateFrame("Slider", nil, parent, BACKDROP)
    Box(ui.inboxScrollBar, C.panel, C.border)
    ui.inboxScrollBar:SetOrientation("VERTICAL")
    ui.inboxScrollBar:SetWidth(12)
    ui.inboxScrollBar:SetPoint("TOPLEFT", ui.list, "TOPRIGHT", 4, -2)
    ui.inboxScrollBar:SetPoint("BOTTOMLEFT", ui.list, "BOTTOMRIGHT", 4, 2)
    ui.inboxScrollBar:SetMinMaxValues(0, 0)
    ui.inboxScrollBar:SetValue(0)
    ui.inboxScrollBar:SetValueStep(1)
    local isbThumb = ui.inboxScrollBar:CreateTexture(nil, "ARTWORK")
    isbThumb:SetTexture(WHITE)
    isbThumb:SetVertexColor(unpack(inboxThumbColor))
    isbThumb:SetSize(8, 24)
    ui.inboxScrollBar:SetThumbTexture(isbThumb)
    ui.inboxScrollBar:EnableMouse(true)
    ui.inboxScrollBar:SetShown(false)
    ui._inboxScrolling = false
    ui.inboxScrollBar:SetScript("OnMouseWheel", function(self, delta)
        ui.offset = (ui.offset or 0) - delta
        MailModule:RefreshInbox()
    end)
    ui.inboxScrollBar:SetScript("OnValueChanged", function(self, value)
        if not ui._inboxScrolling then
            ui._inboxScrolling = true
            ui.offset = math.floor(value + 0.5)
            MailModule:RefreshInbox()
            ui._inboxScrolling = false
        end
    end)
    ui.offset = 0

    ui.empty = Text(ui.list, "GameFontNormal", C.muted, "CENTER")
    ui.empty:SetPoint("CENTER")

    ui.rows = {}
    for r = 1, ROWS do
        local row = CreateFrame("Button", nil, ui.list)
        row:SetSize((860 - inboxPadL - inboxPadR) - 2, ROW_H)
        row:SetPoint("TOPLEFT", ui.list, "TOPLEFT", 1, -((r - 1) * ROW_H) - 1)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetTexture(WHITE)
        row.bg:SetAllPoints()
        local taurenItemInset = (MailModule.addon.db.profile.theme == "tauren") and 11 or 0
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(28, 28)
        row.icon:SetPoint("LEFT", 8 + taurenItemInset, 0)
        local rowWidth = (860 - inboxPadL - inboxPadR) - 2
        local itemsClipWidth = rowWidth - (8 + taurenItemInset) - 28 - 8 - (EXPIRES_RIGHT + EXPIRES_W + 10)
        if itemsClipWidth < 80 then itemsClipWidth = 80 end
        row.itemsClip = CreateFrame("Frame", nil, row)
        row.itemsClip:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.itemsClip:SetSize(itemsClipWidth, ROW_H)
        row.itemsClip:SetClipsChildren(true)
        row.items = Text(row.itemsClip, "GameFontNormal", C.buttonText or C.text)
        row.items:SetShadowOffset(0, 0)
        row.items:SetPoint("LEFT", row.itemsClip, "LEFT", 0, 0)
        row.items:SetWordWrap(false)
        row.expires = Text(row, "GameFontNormal", C.buttonText or C.text, "RIGHT")
        row.expires:SetWidth(EXPIRES_W)
        row.expires:SetPoint("RIGHT", row, "RIGHT", -EXPIRES_RIGHT, 0)
        row.gold = Text(row, "GameFontNormal", C.buttonText or C.text, "RIGHT")
        row.gold:SetShadowOffset(0, 0)
        row.gold:SetPoint("RIGHT", row, "RIGHT", -12, 0)
        row:SetScript("OnClick", function(self)
            if self.mail then
                ui.selected = self.mail.index
                MailModule:RefreshInbox()
            end
        end)
        ui.rows[r] = row
    end

    ui.status = NewBox(parent, { 0.92, 0.88, 0.78, 0.65 }, C.border)
    ui.status:SetSize(860 - inboxPadL - inboxPadR, 36)
    ui.status:SetPoint("TOPLEFT", parent, "TOPLEFT", inboxPadL, -436 - earthenY - allianceStatusY)
    ui.statusText = Text(ui.status, "GameFontNormal", C.text, "CENTER")
    ui.statusText:SetPoint("CENTER")

    ui.openBtn = NewButton(parent, L["Open Mail"], 860 - inboxPadL - inboxPadR, 40)
    ui.openBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", inboxPadL, -484)
    ui.openBtn:SetScript("OnClick", function() MailModule:OpenSelected(ui.selected) end)

    local catGroupW = 5 * 155 + 4 * 8
    local catBase = math.max(0, math.floor((860 - catGroupW) / 2))
    local cats = { "Sold", "Bought", "Cancelled", "Expired", "Other" }
    for k, name in ipairs(cats) do
        local b = NewButton(parent, L["All " .. name], 155, 40)
        b:SetPoint("TOPLEFT", parent, "TOPLEFT", catBase + (k - 1) * 163, -534)
        b:SetScript("OnClick", function() MailModule:OpenCategory(name) end)
    end

    local bottomGroupW = 4 * 199 + 3 * 8
    local bottomBase = math.max(0, math.floor((860 - bottomGroupW) / 2))
    local openAll = NewButton(parent, L["Open All"], 199, 36)
    openAll:SetPoint("TOPLEFT", parent, "TOPLEFT", bottomBase, -582)
    openAll:SetScript("OnClick", function() MailModule:OpenAllMail() end)

    local delEmpty = NewButton(parent, L["Delete Empty"], 199, 36)
    delEmpty:SetPoint("TOPLEFT", parent, "TOPLEFT", bottomBase + 207, -582)
    delEmpty:SetScript("OnClick", function() MailModule:DeleteEmptyMail() end)

    ui.autoBtn = NewButton(parent, L["Auto-Open: Off"], 199, 36)
    ui.autoBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", bottomBase + 414, -582)
    ui.autoBtn:SetScript("OnClick", function()
        MailModule:SetAutoOpen(not MailModule.addon.db.profile.autoOpen)
        MailModule:RefreshInbox()
    end)

    local replyBtn = NewButton(parent, L["Reply to Selected"], 199, 36)
    replyBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", bottomBase + 621, -582)
    replyBtn:SetScript("OnClick", function()
        if not ui.selected then
            MailModule:Notify(L["Bears Mailbox: select a mail in the Inbox first."])
            return
        end
        local sender, subject = ReadHeader(ui.selected)
        ui.recipient:SetText(sender)
        ui.subject:SetText(string.format(L["Re: %s"], subject))
        ui.setDetails(true)
        ui.selectTab("Send")
    end)
end

function NewQueueCell(ui, i)
    local cell = CreateFrame("Button", nil, ui.queueContent, BACKDROP)
    cell:SetSize(56, 56)
    Box(cell, C.panel, C.border)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetPoint("TOPLEFT", 2, -2)
    cell.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    cell.count = Text(cell, "GameFontNormal", { 1, 1, 1, 1 }, "RIGHT")
    cell.count:SetPoint("BOTTOMRIGHT", -6, 4)
    cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cell:SetScript("OnClick", function(self)
        if self.index and not CursorHasItem() then MailModule:RemoveQueued(self.index) end
    end)
    cell:SetScript("OnReceiveDrag", function() MailModule:QueueFromCursor() end)
    cell:SetScript("OnEnter", function(self)
        if self.entry and self.entry.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.entry.link)
            GameTooltip:Show()
        end
    end)
    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.queueCells[i] = cell
    return cell
end

local function BuildSend(parent, ui)
    local function _sendBodyPad(side)
        local t = MailModule.addon.db.profile.theme
        if t == "default" or t == "blizzard" or t == "darkirondwarf" or t == "draenei" or t == "dwarf" or t == "gnome" or t == "human" or t == "lightforgeddraenei" or t == "nightelf" or t == "vulpera" then return 0 end
        local base = 75
        if t == "horde" then base = base + 50 end
        if t == "earthen" or t == "goblin" then base = 85 end
        if side == "l" and t == "earthen" then base = base + 15 end
        if side == "r" and t == "earthen" then base = base + 21 end
        if t == "highmountaintauren" then base = 70 end
        if t == "skyborne" then base = base - 15 end
        if t == "tauren" then
            base = base + 30
            if side == "l" then base = base + 10 end
            if side == "r" then base = base - 15 end
        end
        if t == "troll" then
            if side == "l" then base = base + 16 end
            if side == "r" then base = base + 8 end
        end
        if side == "r" and t == "kultiran" then base = base + 10 end
        if t == "magharorc" or t == "mechagnome" then base = base + 10 end
        if side == "l" and t == "orc" then base = base + 20 end
        if side == "r" and t == "orc" then base = base + 20 end
        if side == "l" and t == "undead" then base = base + 16 end
        if side == "r" and t == "undead" then base = base + 16 end
        if side == "l" and t == "worgen" then base = base + 24 end
        if side == "r" and t == "worgen" then base = base + 32 end
        if t == "zandalaritroll" then base = base + 32 end
        if t == "voidelf" then
            if side == "l" then base = base - 8 end
            if side == "r" then base = base - 16 end
        end
        return base
    end
    local sendBodyPadL = _sendBodyPad("l")
    local sendBodyPadR = _sendBodyPad("r")
    ui.recipientLabelBg = CreateFrame("Frame", nil, parent, BACKDROP)
    Box(ui.recipientLabelBg, { C.button[1], C.button[2], C.button[3], 1 }, C.border)
    local recipientLabel = Text(ui.recipientLabelBg, "GameFontNormal", C.buttonText or C.text)
    recipientLabel:SetPoint("LEFT", ui.recipientLabelBg, "LEFT", 4, 0)
    recipientLabel:SetText(L["Recipient"])
    recipientLabel:SetShadowOffset(0, 0)
    ui.recipientLabelBg:SetSize(recipientLabel:GetStringWidth() + 8, 20)
    ui.recipientLabelBg:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -4)

    ui.recipient = NewInput(parent, 394, 32)
    ui.recipient:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -22)

    ui.suggest = NewBox(parent, { 0.92, 0.88, 0.78, 1 }, C.gold)
    ui.suggest:SetWidth(394)
    ui.suggest:SetPoint("TOPLEFT", ui.recipient, "BOTTOMLEFT", 0, -2)
    ui.suggest:SetFrameLevel(parent:GetFrameLevel() + 50)
    ui.suggest:Hide()
    ui.suggestRows = {}
    for i = 1, SUGGEST_MAX do
        local row = CreateFrame("Button", nil, ui.suggest)
        row:SetSize(392, 28)
        row:SetPoint("TOPLEFT", ui.suggest, "TOPLEFT", 1, -((i - 1) * 28) - 1)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetTexture(WHITE)
        row.bg:SetAllPoints()
        row.bg:SetVertexColor(0, 0, 0, 0)
        row.label = Text(row, "GameFontNormal", { 0, 0, 0, 1 })
        row.label:SetPoint("LEFT", 10, 0)
        row:SetScript("OnEnter", function(self) self.bg:SetVertexColor(0.85, 0.75, 0.55, 0.5) end)
        row:SetScript("OnLeave", function(self) self.bg:SetVertexColor(0, 0, 0, 0) end)
        row:SetScript("OnClick", function(self)
            ui.recipient:ClearFocus()
            ui.recipient:SetText(self.name)
            ui.suggest:Hide()
        end)
        row:Hide()
        ui.suggestRows[i] = row
    end
    ui.recipient:HookScript("OnTextChanged", function(self) MailModule:UpdateSuggestions(self) end)
    ui.recipient:HookScript("OnEditFocusGained", function(self)
        if IsInGuild and IsInGuild() and GuildRoster then GuildRoster() end
        MailModule:UpdateSuggestions(self)
    end)
    ui.recipient:HookScript("OnEditFocusLost", function()
        C_Timer.After(0.2, function()
            if not ui.recipient:HasFocus() then ui.suggest:Hide() end
        end)
    end)

    ui.contacts = NewButton(parent, "", 32, 32)
    ui.contacts:SetPoint("LEFT", ui.recipient, "RIGHT", 0, 0)
    local arrow = ui.contacts:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetSize(16, 16)
    arrow:SetPoint("CENTER")
    ui.contacts:SetScript("OnClick", function(self) MailModule:ShowContactsMenu(self, ui) end)

    ui.addDetails = NewLink(parent, L["+ Add subject & description (optional)"], 400, 32, C.buttonText or C.text, "RIGHT", nil, { C.button[1], C.button[2], C.button[3], C.button[4] or 1 })
    ui.addDetails.label:ClearAllPoints()
    ui.addDetails.label:SetPoint("LEFT", ui.addDetails, "LEFT", 4, 0)
    ui.addDetails.label:SetPoint("RIGHT", ui.addDetails, "RIGHT", -4, 0)
    ui.addDetails.label:SetShadowOffset(0, 0)
    ui.addDetails:SetSize(ui.addDetails.label:GetStringWidth() + 8, 32)
    ui.addDetails:ClearAllPoints()
    ui.addDetails:SetPoint("TOPLEFT", ui.contacts, "TOPRIGHT", 8, 0)
    ui.addDetails:SetScript("OnClick", function() ui.setDetails(not ui.detailsShown) end)

    ui.subjectLabelBg = CreateFrame("Frame", nil, parent, BACKDROP)
    Box(ui.subjectLabelBg, { C.button[1], C.button[2], C.button[3], 1 }, C.border)
    ui.subjectLabel = Text(ui.subjectLabelBg, "GameFontNormal", C.buttonText or C.text)
    ui.subjectLabel:SetPoint("LEFT", ui.subjectLabelBg, "LEFT", 4, 0)
    ui.subjectLabel:SetText(L["Subject"])
    ui.subjectLabel:SetShadowOffset(0, 0)
    ui.subjectLabelBg:SetSize(ui.subjectLabel:GetStringWidth() + 8, 20)
    ui.subjectLabelBg:SetPoint("TOPLEFT", parent, "TOPLEFT", 8 + sendBodyPadL, -72)
    ui.subject = NewInput(parent, 860 - sendBodyPadL - sendBodyPadR, 30)
    ui.subject:SetPoint("TOPLEFT", parent, "TOPLEFT", sendBodyPadL, -92)

    ui.bodyLabelBg = CreateFrame("Frame", nil, parent, BACKDROP)
    Box(ui.bodyLabelBg, { C.button[1], C.button[2], C.button[3], 1 }, C.border)
    ui.bodyLabel = Text(ui.bodyLabelBg, "GameFontNormal", C.buttonText or C.text)
    ui.bodyLabel:SetPoint("LEFT", ui.bodyLabelBg, "LEFT", 4, 0)
    ui.bodyLabel:SetText(L["Body"])
    ui.bodyLabel:SetShadowOffset(0, 0)
    ui.bodyLabelBg:SetSize(ui.bodyLabel:GetStringWidth() + 8, 20)
    ui.bodyLabelBg:SetPoint("TOPLEFT", parent, "TOPLEFT", 8 + sendBodyPadL, -138)
    ui.bodyBox = NewBox(parent, C.panel, C.border)
    ui.bodyBox:SetSize(860 - sendBodyPadL - sendBodyPadR, 110)
    ui.bodyBox:SetPoint("TOPLEFT", parent, "TOPLEFT", sendBodyPadL, -158)
    local bodyScroll = CreateFrame("ScrollFrame", nil, ui.bodyBox)
    bodyScroll:SetPoint("TOPLEFT", ui.bodyBox, "TOPLEFT", 8, -8)
    bodyScroll:SetPoint("BOTTOMRIGHT", ui.bodyBox, "BOTTOMRIGHT", -8, 8)
    ui.body = CreateFrame("EditBox", nil, bodyScroll)
    ui.body:SetMultiLine(true)
    ui.body:SetFont(FONT_FILE, FONT_SIZES.GameFontHighlight, "")
    ui.body:SetTextInsets(0, 0, 8, 8)
    ui.body:SetTextColor(unpack(C.text))
    ui.body:SetShadowOffset(0, 0)
    ui.body:SetAutoFocus(false)
    if MailModule.testMode then ui.body:SetText("Sample body text to visualize color and wrapping.\nSecond line here.") end
    ui.body:SetWidth(860 - sendBodyPadL - sendBodyPadR - 16)
    ui.body:SetHeight(400)
    ui.body:SetScript("OnEscapePressed", ui.body.ClearFocus)
    bodyScroll:SetScrollChild(ui.body)
    bodyScroll:EnableMouseWheel(true)
    bodyScroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, self:GetVerticalScroll() - delta * 20))
    end)

    ui.itemsBox = NewBox(parent, C.panel, C.border)
    ui.itemsBox:SetSize(860 - sendBodyPadL - sendBodyPadR, 256)
    local itemsHeader = NewBox(ui.itemsBox, { 0.92, 0.88, 0.78, 0.65 }, C.border)
    itemsHeader:SetSize(860 - sendBodyPadL - sendBodyPadR, 26)
    itemsHeader:SetPoint("TOPLEFT", ui.itemsBox, "TOPLEFT", 0, 0)
    local hItems = Text(itemsHeader, "GameFontNormalSmall", { 0, 0, 0, 1 })
    hItems:SetPoint("LEFT", 12, 0)
    hItems:SetText(L["Items"])
    local hAmount = Text(itemsHeader, "GameFontNormalSmall", { 0, 0, 0, 1 }, "RIGHT")
    hAmount:SetPoint("RIGHT", itemsHeader, "RIGHT", -12, 0)
    hAmount:SetText(L["Amount"])
    ui.attachEmpty = Text(ui.itemsBox, "GameFontNormal", C.muted, "CENTER")
    ui.attachEmpty:SetPoint("CENTER", 0, 0)
    ui.attachEmpty:SetText(L["Drag & drop an item in to attach"])
    ui.itemsBox:EnableMouse(true)
    ui.itemsBox:SetScript("OnReceiveDrag", function() MailModule:QueueFromCursor() end)
    ui.itemsBox:SetScript("OnMouseUp", function() MailModule:QueueFromCursor() end)
    ui.queueScroll = CreateFrame("ScrollFrame", nil, ui.itemsBox)
    ui.queueScroll:SetPoint("TOPLEFT", ui.itemsBox, "TOPLEFT", 0, -26)
    ui.queueScroll:SetPoint("BOTTOMRIGHT", ui.itemsBox, "BOTTOMRIGHT", 0, 30)
    ui.queueScroll:EnableMouse(true)
    ui.queueScroll:EnableMouseWheel(true)
    ui.queueScroll:SetScript("OnReceiveDrag", function() MailModule:QueueFromCursor() end)
    ui.queueScroll:SetScript("OnMouseUp", function() MailModule:QueueFromCursor() end)
    ui.queueScroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, ui.queueContent:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * QUEUE_STEP)))
    end)
    ui.queueContent = CreateFrame("Frame", nil, ui.queueScroll)
    ui.queueContent:SetSize(800, QUEUE_STEP)
    ui.queueScroll:SetScrollChild(ui.queueContent)
    -- Visible scrollbar on the right edge of the item panel.
    local queueThumbColor = (MailModule.addon.db.profile.theme == "default" or MailModule.addon.db.profile.theme == "blizzard") and { 0.2, 0.2, 0.2, 0.9 } or { 0, 0, 0, 0.95 }
    ui.queueScrollBar = CreateFrame("Slider", nil, ui.itemsBox, BACKDROP)
    Box(ui.queueScrollBar, C.panel, C.border)
    ui.queueScrollBar:SetOrientation("VERTICAL")
    ui.queueScrollBar:SetWidth(12)
    ui.queueScrollBar:SetPoint("TOPRIGHT", ui.itemsBox, "TOPRIGHT", -3, -28)
    ui.queueScrollBar:SetPoint("BOTTOMRIGHT", ui.itemsBox, "BOTTOMRIGHT", -3, -32)
    ui.queueScrollBar:SetMinMaxValues(0, 0)
    ui.queueScrollBar:SetValue(0)
    ui.queueScrollBar:SetValueStep(1)
    local sbThumb = ui.queueScrollBar:CreateTexture(nil, "ARTWORK")
    sbThumb:SetTexture(WHITE)
    sbThumb:SetVertexColor(unpack(queueThumbColor))
    sbThumb:SetSize(8, 24)
    ui.queueScrollBar:SetThumbTexture(sbThumb)
    ui.queueScrollBar:EnableMouse(true)
    ui.queueScrollBar:SetShown(false)
    ui._scrolling = false
    ui.queueScroll:HookScript("OnVerticalScroll", function(self, offset)
        if not ui._scrolling then
            ui._scrolling = true
            if ui.queueScrollBar then ui.queueScrollBar:SetValue(offset) end
            ui._scrolling = false
        end
    end)
    ui.queueScrollBar:SetScript("OnValueChanged", function(self, value)
        if not ui._scrolling then
            ui._scrolling = true
            if ui.queueScroll then ui.queueScroll:SetVerticalScroll(value) end
            ui._scrolling = false
        end
    end)
    ui.queueCells = {}
    local footer = NewBox(ui.itemsBox, { 0.92, 0.88, 0.78, 0.65 }, C.border)
    footer:SetSize(860 - sendBodyPadL - sendBodyPadR, 30)
    footer:SetPoint("BOTTOMLEFT", ui.itemsBox, "BOTTOMLEFT", 0, 0)
    ui.postage = Text(footer, "GameFontNormal", { 0, 0, 0, 1 })
    ui.postage:SetPoint("LEFT", 12, 0)
    ui.postage:SetText(string.format(L["Total Postage: %s"], FormatMoneyText(30)))
    local allBags = NewButton(footer, L["Send all in bags"], 190, 24)
    allBags:SetPoint("RIGHT", footer, "RIGHT", -4, 0)
    allBags:SetScript("OnClick", function() MailModule:QueueAllBags() end)

    ui.goldLabelBg = CreateFrame("Frame", nil, parent, BACKDROP)
    Box(ui.goldLabelBg, { C.button[1], C.button[2], C.button[3], 1 }, C.border)
    ui.goldLabel = Text(ui.goldLabelBg, "GameFontNormal", C.buttonText or C.text)
    ui.goldLabel:SetFont(FONT_FILE, (FONT_SIZES.GameFontNormal or 15) + 2, "")
    ui.goldLabel:SetPoint("LEFT", ui.goldLabelBg, "LEFT", 4, 0)
    ui.goldLabel:SetText(L["Gold"])
    ui.goldLabel:SetShadowOffset(0, 0)
    ui.goldLabelBg:SetSize(ui.goldLabel:GetStringWidth() + 8, ui.goldLabel:GetStringHeight() + 8)
    local function MoneyBox(suffix)
        local eb = NewInput(parent, 100, 30)
        eb:SetNumeric(true)
        eb:SetJustifyH("RIGHT")
        eb:SetTextInsets(8, 30, 0, 0)
        eb:SetText("0")
        local iconFile = (suffix == "g") and "UI-GoldIcon" or (suffix == "s") and "UI-SilverIcon" or "UI-CopperIcon"
        local ic = eb:CreateTexture(nil, "OVERLAY")
        ic:SetTexture("Interface/MoneyFrame/" .. iconFile)
        ic:SetSize(18, 18)
        ic:SetPoint("RIGHT", -12, 0)
        return eb
    end
    ui.goldG = MoneyBox("g")
    ui.goldS = MoneyBox("s")
    ui.goldC = MoneyBox("c")
    ui.cod = NewCheck(parent, L["Make COD"])

    ui.sendBtn = NewButton(parent, L["Send Mail"], 700, 40)
    ui.sendBtn:SetScript("OnClick", function() MailModule:SendFromUI() end)

    local clear = NewButton(parent, L["Clear All"], 140, 40)
    clear.label:SetFont(FONT_FILE, FONT_SIZES.GameFontNormalLarge, "")
    clear:SetPoint("TOPLEFT", parent, "TOPLEFT", 720, 0)
    clear:SetScript("OnClick", function()
        ui.recipient:SetText("")
        ui.subject:SetText("")
        ui.body:SetText("")
        ui.goldG:SetText("0")
        ui.goldS:SetText("0")
        ui.goldC:SetText("0")
        ui.cod:SetChecked(false)
        ui.queue = {}
        MailModule:RefreshQueue()
        if ClearSendMail then ClearSendMail() end
    end)
    ui.clearBtn = clear

    ui.pendingBtn = NewButton(parent, L["Pending"], 160, 30)
    ui.pendingBtn:SetScript("OnClick", function() MailModule:ListPending() end)

    function ui.relayout()
        local shown = ui.detailsShown
        ui.subjectLabel:SetShown(shown)
        ui.subjectLabelBg:SetShown(shown)
        ui.subject:SetShown(shown)
        ui.bodyLabel:SetShown(shown)
        ui.bodyLabelBg:SetShown(shown)
        ui.bodyBox:SetShown(shown)
        local itemsTop = shown and -270 or -70
        -- Without the subject/body fields, grow the item panel down to fill the
        -- space above the gold row so more queue rows are visible.
        local itemsH = shown and 256 or 456
        ui.itemsBox:ClearAllPoints()
        ui.itemsBox:SetPoint("TOPLEFT", parent, "TOPLEFT", sendBodyPadL, itemsTop)
        ui.itemsBox:SetSize(860 - sendBodyPadL - sendBodyPadR, itemsH)
        local goldY = itemsTop - itemsH - 14
        ui.goldLabelBg:ClearAllPoints()
        ui.goldLabelBg:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, goldY - math.floor((30 - ui.goldLabelBg:GetHeight()) / 2))
        ui.goldG:ClearAllPoints()
        ui.goldG:SetPoint("TOPLEFT", parent, "TOPLEFT", 70, goldY)
        ui.goldS:ClearAllPoints()
        ui.goldS:SetPoint("TOPLEFT", parent, "TOPLEFT", 180, goldY)
        ui.goldC:ClearAllPoints()
        ui.goldC:SetPoint("TOPLEFT", parent, "TOPLEFT", 290, goldY)
        ui.cod:ClearAllPoints()
        ui.cod:SetPoint("TOPLEFT", parent, "TOPLEFT", 410, goldY - math.floor((30 - ui.cod:GetHeight()) / 2))
        ui.pendingBtn:ClearAllPoints()
        ui.pendingBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 600, goldY)
        local sendY = goldY - 44
        ui.sendBtn:ClearAllPoints()
        ui.sendBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sendY)
        ui.clearBtn:ClearAllPoints()
        ui.clearBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 720, sendY)
    end

    function ui.setDetails(v)
        ui.detailsShown = v and true or false
        ui.addDetails.label:SetText(ui.detailsShown and L["- Hide subject & description"] or L["+ Add subject & description (optional)"])
        ui.addDetails:SetSize(ui.addDetails.label:GetStringWidth() + 8, 32)
        ui.relayout()
    end

    ui.setDetails(false)

    if MailModule.testMode then
        ui.queue = {}
        local icons = { "Interface\\Icons\\INV_Misc_Coin_01", "Interface\\Icons\\INV_Misc_Bag_08", "Interface\\Icons\\INV_Letter_15", "Interface\\Icons\\INV_Sword_04", "Interface\\Icons\\INV_Misc_Gem_01", "Interface\\Icons\\INV_Potion_51", "Interface\\Icons\\INV_Chest_Chain_04", "Interface\\Icons\\INV_Misc_Food_15" }
        for i = 1, 24 do
            ui.queue[#ui.queue + 1] = { icon = icons[(i % 8) + 1], count = (i % 4) + 1, link = nil }
        end
        MailModule:RefreshQueue()
    end
end

function MailModule:ShowThemeMenu(anchor)
    local ui = self.ui
    if not ui or not ui.frame then return end

    -- Toggle: clicking the Theme button again closes the dropdown.
    if ui.themeMenu then
        if ui.themeMenu:IsShown() then
            ui.themeMenu:Hide()
            if ui.themeCatcher then ui.themeCatcher:Hide() end
        else
            ui.themeMenu:Show()
            if ui.themeCatcher then ui.themeCatcher:Show() end
        end
        return
    end

    -- Build ordered list: Default, Blizzard, Alliance, Horde, then races sorted by name.
    local ordered = {}
    local first = { "default", "blizzard", "alliance", "horde" }
    for _, key in ipairs(first) do
        for _, t in ipairs(self.THEMES) do
            if t.key == key then table.insert(ordered, t) end
        end
    end
    local races = {}
    for _, t in ipairs(self.THEMES) do
        if t.key ~= "default" and t.key ~= "blizzard" and t.key ~= "alliance" and t.key ~= "horde" then
            table.insert(races, t)
        end
    end
    table.sort(races, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
    for _, t in ipairs(races) do table.insert(ordered, t) end

    local rowH = 32
    local contentH = #ordered * rowH
    local maxH = math.min(contentH, 540)

    local menu = CreateFrame("Frame", nil, UIParent, BACKDROP)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetSize(250, maxH + 12)
    Box(menu, { C.bg[1], C.bg[2], C.bg[3], 0.98 }, C.gold)
    menu:EnableMouse(true)
    menu:SetClampedToScreen(true)
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    ui.themeMenu = menu

    local scroll = CreateFrame("ScrollFrame", nil, menu)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(238, contentH)
    scroll:SetScrollChild(content)

    local function UpdateScrollThumb() end
    if contentH > maxH then
        local track = menu:CreateTexture(nil, "ARTWORK")
        track:SetColorTexture(0, 0, 0, 0.5)
        track:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -3, -8)
        track:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -3, 8)
        track:SetWidth(6)
        local thumb = menu:CreateTexture(nil, "OVERLAY")
        thumb:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.9)
        thumb:SetWidth(6)
        local function UpdateThumb()
            local viewH = scroll:GetHeight()
            local trackH = menu:GetHeight() - 16
            local thumbH = math.max(24, trackH * viewH / math.max(contentH, 1))
            local offset = scroll:GetVerticalScroll() or 0
            local maxOff = math.max(1, contentH - viewH)
            local y = -(offset / maxOff) * (trackH - thumbH)
            thumb:SetHeight(thumbH)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", track, "TOP", 0, y)
        end
        UpdateScrollThumb = UpdateThumb
        scroll:SetScript("OnVerticalScroll", UpdateThumb)
        scroll:SetScript("OnSizeChanged", UpdateThumb)
        menu:SetScript("OnShow", UpdateThumb)
        UpdateThumb()
    end
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, contentH - self:GetHeight())
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, (self:GetVerticalScroll() or 0) - delta * rowH)))
        UpdateScrollThumb()
    end)
    scroll:SetScript("OnSizeChanged", function(self, w)
        content:SetWidth(w)
        UpdateScrollThumb()
    end)

    local labelColor = C.buttonText or C.text
    local hoverColor = C.gold
    if (hoverColor[1] + hoverColor[2] + hoverColor[3]) < 1.2 then
        hoverColor = { 1, 0.93, 0.65, 1 }
    end

    for i, theme in ipairs(ordered) do
        local b = CreateFrame("Button", nil, content)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
        b:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * rowH)
        b:SetHeight(rowH - 2)
        local hl = b:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        hl:Hide()
        b.hl = hl
        b.label = Text(b, "GameFontNormal", labelColor)
        b.label:SetFont(FONT_FILE, (FONT_SIZES.GameFontNormal or 17) + 2, "")
        b.label:SetPoint("LEFT", 8, 0)
        b.label:SetText(theme.name)
        b:SetScript("OnEnter", function(self)
            self.hl:Show()
            self.label:SetTextColor(unpack(hoverColor))
        end)
        b:SetScript("OnLeave", function(self)
            self.hl:Hide()
            self.label:SetTextColor(unpack(labelColor))
        end)
        b:SetScript("OnClick", function()
            menu:Hide()
            MailModule:SetTheme(theme.key)
        end)
    end

    -- Close the dropdown when clicking elsewhere in the window or closing it.
    if not ui._themeMenuHooks then
        ui._themeMenuHooks = true
        ui.frame:HookScript("OnMouseDown", function()
            if ui.themeMenu then ui.themeMenu:Hide() end
        end)
        ui.frame:HookScript("OnHide", function()
            if ui.themeMenu then ui.themeMenu:Hide() end
        end)
    end

    -- Catcher frame so clicking anywhere in the main window (including on
    -- child panels/buttons) closes the dropdown instead of leaving it open.
    local catcher = CreateFrame("Frame", nil, ui.frame)
    catcher:SetAllPoints(ui.frame)
    catcher:SetFrameLevel((ui.frame:GetFrameLevel() or 0) + 1000)
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown", function()
        if ui.themeMenu then ui.themeMenu:Hide() end
    end)
    ui.themeCatcher = catcher
    menu:HookScript("OnHide", function()
        if ui.themeCatcher then ui.themeCatcher:Hide() end
    end)

    menu:Show()
    catcher:Show()
end

function MailModule:ThemeList()
    local names = {}
    -- Default, Blizzard, Alliance, Horde, then races sorted by name
    local first = { "default", "blizzard", "alliance", "horde" }
    for _, key in ipairs(first) do
        for _, t in ipairs(self.THEMES) do
            if t.key == key then table.insert(names, t.key) end
        end
    end
    local races = {}
    for _, t in ipairs(self.THEMES) do
        if t.key ~= "default" and t.key ~= "blizzard" and t.key ~= "alliance" and t.key ~= "horde" then
            table.insert(races, t)
        end
    end
    table.sort(races, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
    for _, t in ipairs(races) do table.insert(names, t.key) end
    return table.concat(names, ", ")
end

function MailModule:SetTheme(key)
    local theme = self:FindTheme(key)
    if not theme then
        self:Notify(string.format(L["Bears Mailbox: unknown theme. Available: %s"], self:ThemeList()))
        return
    end
    self.addon.db.profile.theme = theme.key
    if self.ui then
        self._themeChanging = true
        self.ui.frame:Hide()
        self._themeChanging = false
        self.ui = nil
        self:ShowMainWindow()
    end
    self:Notify(string.format(L["Bears Mailbox: theme set to %s."], theme.name))
end

function MailModule:ShowMainWindow()
    if self.ui then
        self.ui.frame:Show()
        self:RefreshInbox()
        return
    end

    local ui = { tabs = {}, panels = {}, queue = {} }
    ApplyTheme(self.addon.db.profile.theme)

    local f = CreateFrame("Frame", "BearsMailboxMainFrame", UIParent, BACKDROP)
    f:SetSize(900, 724)
    MailModule:RestorePosition(f, "mainPos")
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    if C.background then
        -- Textured themes draw their own frame edge in the artwork, so the
        -- backdrop border is transparent to avoid a coloured line outside it.
        Box(f, { C.bg[1], C.bg[2], C.bg[3], 0 }, { 0, 0, 0, 0 })
        -- Full-frame parchment behind everything (covers the 1px backdrop gap).
        local bgTex = f:CreateTexture(nil, "BACKGROUND", nil, 0)
        bgTex:SetAllPoints(f)
        bgTex:SetTexture(C.background)
        if C.texcoord then bgTex:SetTexCoord(unpack(C.texcoord)) end
        local tint = C.tint or { 1, 1, 1, 1 }
        bgTex:SetVertexColor(tint[1], tint[2], tint[3], (tint[4] or 1))
    else
        Box(f, C.bg, C.border)
    end
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        MailModule:SavePosition(frame, "mainPos")
    end)
    f:SetScript("OnShow", function() MailModule:RefreshInbox() end)
    tinsert(UISpecialFrames, "BearsMailboxMainFrame")
    ui.frame = f
    f:RegisterEvent("GUILD_ROSTER_UPDATE")
    f:SetScript("OnEvent", function()
        if ui.recipient and ui.recipient:HasFocus() then MailModule:UpdateSuggestions(ui.recipient) end
    end)

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetSize(36, 36)
    logo:SetPoint("TOPLEFT", 20, -18)
    local _, raceFile = UnitRace("player")
    local sex = UnitSex("player") == 3 and "female" or "male"
    local raceAtlas = raceFile and ("raceicon-" .. string.lower(raceFile) .. "-" .. sex)
    if raceAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(raceAtlas) then
        logo:SetAtlas(raceAtlas)
    else
        logo:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    end
    local characterName = UnitName("player")
    local playerName = characterName and (characterName .. "'s Mailbox") or L["Mailbox"]
    local titleBg = CreateFrame("Frame", nil, f, BACKDROP)
    titleBg:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    Box(titleBg, { 0, 0, 0, 1 }, C.gold)
    ui.titleBg = titleBg
    local title = Text(titleBg, "GameFontNormalHuge", { 1, 1, 1, 1 }, "CENTER")
    title:SetPoint("CENTER")
    title:SetText(playerName)
    titleBg:SetSize(title:GetStringWidth() + 16, 28)

    local tabNames = { "Inbox", "Send" }
    for _, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", nil, f, BACKDROP)
        Box(tab, { C.button[1], C.button[2], C.button[3], 1 }, C.border)
        tab.label = Text(tab, "GameFontNormalLarge", C.muted, "CENTER")
        tab.label:SetText(L[name])
        tab:SetSize(tab.label:GetStringWidth() + 24, 30)
        tab.label:SetAllPoints()
        tab:SetScript("OnClick", function() ui.selectTab(name) end)
        ui.tabs[name] = tab
    end
    local function CenterTabs()
        local gap = 12
        local total = 0
        for i, name in ipairs(tabNames) do
            total = total + ui.tabs[name]:GetWidth()
            if i < #tabNames then total = total + gap end
        end
        -- Centre the tabs in the free space between the title block and the
        -- Theme button, so there is a gap on both sides instead of touching
        -- the title.
        local titleRight = 62 + ((ui.titleBg and ui.titleBg:GetWidth()) or 0)
        local themeLeft = f:GetWidth() - 176 - ((ui.themeBtn and ui.themeBtn:GetWidth()) or 130)
        local span = themeLeft - titleRight
        local x = math.floor(titleRight + math.max(0, (span - total) / 2))
        for _, name in ipairs(tabNames) do
            local tab = ui.tabs[name]
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", f, "TOPLEFT", x, -21)
            x = x + tab:GetWidth() + gap
        end
    end
    ui.centerTabs = CenterTabs
    CenterTabs()
    f:HookScript("OnSizeChanged", CenterTabs)

    local close = CreateFrame("Button", nil, f, BACKDROP)
    close:SetSize(28, 28)
    -- Black background, no border; the button is inset from the window corner.
    Box(close, { 0, 0, 0, 1 }, { 0, 0, 0, 0 })
    close.label = Text(close, "GameFontNormalLarge", (MailModule.addon.db.profile.theme == "default") and C.text or { 1, 1, 1, 1 }, "CENTER")
    close.label:SetPoint("CENTER")
    close.label:SetShadowOffset(0, 0)
    close.label:SetText("X")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -22, -22)
    close:SetScript("OnClick", function() f:Hide() end)

    local themeBtn = NewButton(f, L["Theme"], 130, 30)
    themeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -176, -21)
    themeBtn:SetScript("OnClick", function(self) MailModule:ShowThemeMenu(self) end)
    ui.themeBtn = themeBtn
    themeBtn.label:ClearAllPoints()
    themeBtn.label:SetPoint("CENTER", 12, 0)
    local themeIcon = themeBtn:CreateTexture(nil, "OVERLAY")
    themeIcon:SetSize(30, 30)
    themeIcon:SetPoint("LEFT", 8, 0)
    local themeKey = self.addon.db.profile.theme or "default"
    local themeDef = self:FindTheme(themeKey)
    if themeDef and themeDef.icon then
        themeIcon:SetSize(unpack(themeDef.iconSize or { 40, 24 }))
        themeIcon:SetTexture(themeDef.icon)
        if themeDef.iconTexCoord then themeIcon:SetTexCoord(unpack(themeDef.iconTexCoord)) end
    else
        local themeAtlas = "raceicon-" .. themeKey .. "-male"
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(themeAtlas) then
            themeIcon:SetAtlas(themeAtlas)
        else
            themeIcon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
        end
    end

    local wowUI = NewButton(f, L["WoW UI"], 110, 30)
    wowUI:SetPoint("TOPRIGHT", f, "TOPRIGHT", -56, -21)
    wowUI:SetScript("OnClick", function()
        f:Hide()
        MailModule:RestoreBlizzardMail()
    end)

    local sep = f:CreateTexture(nil, "BORDER")
    sep:SetTexture(WHITE)
    sep:SetVertexColor(unpack(C.border))
    sep:SetHeight(1)
    -- Match the search box width (content area, 20px in from each edge).
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -56)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -56)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -72)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 28)

    if C.background then
        ui.messageBg = CreateFrame("Frame", nil, f, BACKDROP)
        ui.messageBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 8)
        ui.messageBg:SetSize(868, 22)
        Box(ui.messageBg, { 0, 0, 0, 0.75 }, C.border)
    end
    local msgColor
    if not C.background then
        msgColor = C.text
    elseif C.background and string.find(C.background, "parchment") then
        msgColor = { 1, 1, 1, 1 }
    else
        msgColor = { 1, 1, 1, 1 }
    end
    ui.message = Text(ui.messageBg or f, "GameFontNormal", msgColor)
    if ui.messageBg then
        ui.message:SetPoint("LEFT", ui.messageBg, "LEFT", 6, 0)
        ui.message:SetWidth(856)
    else
        ui.message:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 6)
        ui.message:SetWidth(860)
    end

    for _, name in ipairs(tabNames) do
        local p = CreateFrame("Frame", nil, content)
        p:SetAllPoints(content)
        p:Hide()
        ui.panels[name] = p
    end

    BuildInbox(ui.panels.Inbox, ui)
    BuildSend(ui.panels.Send, ui)

    function ui.selectTab(name)
        ui.activeTab = name
        for n, p in pairs(ui.panels) do p:SetShown(n == name) end
        if MailModule.UpdateQueuingOverride then MailModule:UpdateQueuingOverride() end
        if MailFrame and MailFrame:IsShown() then
            local tab = (name == "Send" and MailFrameTab2) or (name == "Inbox" and MailFrameTab1)
            if tab then tab:Click() end
        end
        MailModule:RefreshQueue()
        for n, t in pairs(ui.tabs) do
            local inboxTab = (n == "Inbox")
            if n == name then
                t.label:SetFont(FONT_FILE, FONT_SIZES.GameFontNormalLarge, "")
                local active = (inboxTab and C.inboxTabTextActive) or { 0.95, 0.92, 0.85, 1 }
                t.label:SetTextColor(active[1], active[2], active[3], 1)
                t:SetBackdropColor(C.selected[1], C.selected[2], C.selected[3], 1)
                t:SetBackdropBorderColor(unpack(C.gold))
            else
                t.label:SetFont(FONT_FILE, FONT_SIZES.GameFontNormalLarge, "")
                local idle = (inboxTab and C.inboxTabText) or { 0.85, 0.82, 0.75, 1 }
                t.label:SetTextColor(idle[1], idle[2], idle[3], 1)
                t:SetBackdropColor(C.button[1], C.button[2], C.button[3], 1)
                t:SetBackdropBorderColor(unpack(C.border))
            end
            t:SetWidth(t.label:GetStringWidth() + 24)
        end
        if ui.centerTabs then ui.centerTabs() end
    end

    self.ui = ui
    self.mainFrame = f
    ui.selectTab("Inbox")
    f:Show()
    if MailModule.UpdateQueuingOverride then MailModule:UpdateQueuingOverride() end
end

if C_Container then
    local originalUseContainerItem = C_Container.UseContainerItem
    -- Only override UseContainerItem while queuing, and restore the original
    -- otherwise, so we never call a protected function from addon code.
    MailModule._originalUseContainerItem = originalUseContainerItem
    MailModule._queuingOverrideActive = false
    function MailModule:UpdateQueuingOverride()
        if not C_Container then return end
        local want = self:IsQueuing()
        if want == self._queuingOverrideActive then return end
        self._queuingOverrideActive = want
        if want then
            C_Container.UseContainerItem = function(bag, slot, ...)
                if MailModule:IsQueuing() then
                    MailModule:QueueItem(bag, slot)
                    return
                end
                -- Queuing stopped mid-click; restore and do nothing (click again).
                if MailModule._originalUseContainerItem then
                    C_Container.UseContainerItem = MailModule._originalUseContainerItem
                    MailModule._queuingOverrideActive = false
                end
            end
        else
            if self._originalUseContainerItem then
                C_Container.UseContainerItem = self._originalUseContainerItem
            end
        end
    end
    hooksecurefunc(C_Container, "PickupContainerItem", function(bag, slot)
        if MailModule.ui then
            MailModule.ui.lastPickup = { bag = bag, slot = slot }
        end
    end)
end
