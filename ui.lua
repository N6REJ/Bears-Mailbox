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
    for name, color in pairs(theme.colors) do
        C[name] = color
    end
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
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetFont(FONT_FILE, FONT_SIZES[font] or 15, "")
    fs:SetTextColor(unpack(color or C.text))
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function NewButton(parent, label, w, h)
    local b = CreateFrame("Button", nil, parent, BACKDROP)
    b:SetSize(w, h)
    Box(b, C.button, C.border)
    b.label = Text(b, "GameFontNormal", C.text, "CENTER")
    b.label:SetPoint("CENTER")
    b.label:SetText(label)
    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then self:SetBackdropBorderColor(unpack(C.gold)) end
    end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    b:SetScript("OnEnable", function(self) self.label:SetTextColor(unpack(C.text)) end)
    b:SetScript("OnDisable", function(self) self.label:SetTextColor(unpack(C.disabled)) end)
    return b
end

local function NewLink(parent, label, w, h, color, justify, font)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
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
    Box(eb, C.panel, C.border)
    eb:SetFont(FONT_FILE, FONT_SIZES.GameFontHighlight, "")
    eb:SetAutoFocus(false)
    eb:SetTextInsets(8, 8, 0, 0)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEnterPressed", eb.ClearFocus)
    eb:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(C.gold)) end)
    eb:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    if placeholder then
        eb.placeholder = Text(eb, "GameFontDisable", C.muted)
        eb.placeholder:SetPoint("LEFT", 8, 0)
        eb.placeholder:SetText(placeholder)
        eb:SetScript("OnTextChanged", function(self)
            self.placeholder:SetShown(self:GetText() == "")
        end)
    end
    return eb
end

local function NewCheck(parent, label)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(120, 20)
    b.box = NewBox(b, C.panel, C.border)
    b.box:SetSize(16, 16)
    b.box:SetPoint("LEFT")
    b.mark = b.box:CreateTexture(nil, "OVERLAY")
    b.mark:SetTexture(WHITE)
    b.mark:SetVertexColor(unpack(C.gold))
    b.mark:SetSize(8, 8)
    b.mark:SetPoint("CENTER")
    b.mark:Hide()
    b.label = Text(b, "GameFontNormal", C.text)
    b.label:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
    b.label:SetText(label)
    b.checked = false
    function b:SetChecked(v)
        self.checked = v and true or false
        self.mark:SetShown(self.checked)
    end
    function b:GetChecked() return self.checked end
    b:SetScript("OnClick", function(self) self:SetChecked(not self.checked) end)
    return b
end

local function FormatMoney(copper)
    copper = math.floor(tonumber(copper) or 0)
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100)
end

local function FormatMoneyText(copper)
    copper = math.floor(tonumber(copper) or 0)
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100)
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

    local function nextBatch()
        local taken = 0
        local num = GetInboxNumItems() or 0
        for i = 1, num do
            if taken >= BATCH then break end
            if filter(i) then
                local sender, _, money, _, _, hasItem = ReadHeader(i)
                if money > 0 and taken < BATCH then
                    local key = i .. "|money|" .. tostring(money)
                    if (tries[key] or 0) < 3 then
                        tries[key] = (tries[key] or 0) + 1
                        if sender ~= "" then self:ClearPending(sender) end
                        TakeInboxMoney(i)
                        taken = taken + 1
                    end
                end
                for j = 1, ATTACHMENTS_MAX_RECEIVE do
                    if taken >= BATCH then break end
                    if GetInboxItem(i, j) then
                        local key = i .. "|" .. j .. "|" .. tostring(hasItem)
                        if (tries[key] or 0) < 3 then
                            tries[key] = (tries[key] or 0) + 1
                            if sender ~= "" then self:ClearPending(sender) end
                            TakeInboxItem(i, j)
                            taken = taken + 1
                        end
                    end
                end
            end
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
        if steps > 400 or nextBatch() == 0 then
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
    local w = CreateFrame("Frame", "BearsMailboxContactWindow", ui.frame, BACKDROP)
    w:SetSize(360, 430)
    w:SetPoint("CENTER", ui.frame, "CENTER")
    w:SetFrameStrata("DIALOG")
    w:EnableMouse(true)
    Box(w, C.bg, C.gold)
    w:Hide()

    w.title = Text(w, "GameFontNormalLarge", C.text)
    w.title:SetPoint("TOPLEFT", 14, -12)

    local close = NewLink(w, "X", 24, 24, C.text, "CENTER", "GameFontNormalLarge")
    close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() w:Hide() end)

    w.scroll = CreateFrame("ScrollFrame", nil, w)
    w.scroll:SetPoint("TOPLEFT", w, "TOPLEFT", 10, -44)
    w.scroll:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -10, 10)
    w.scroll:EnableMouseWheel(true)
    w.scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, w.content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 28)))
    end)

    w.content = CreateFrame("Frame", nil, w.scroll)
    w.content:SetSize(340, 28)
    w.scroll:SetScrollChild(w.content)

    w.empty = Text(w, "GameFontNormal", C.muted, "CENTER")
    w.empty:SetPoint("CENTER", 0, 0)
    w.empty:SetText(L["Nobody to show"])

    w.rows = {}
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
            row:SetSize(340, 28)
            row:SetPoint("TOPLEFT", w.content, "TOPLEFT", 0, -((i - 1) * 28))
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetTexture(WHITE)
            row.bg:SetAllPoints()
            row.bg:SetVertexColor(0, 0, 0, 0)
            row.label = Text(row, "GameFontNormal", C.text)
            row.label:SetPoint("LEFT", 10, 0)
            row:SetScript("OnEnter", function(self) self.bg:SetVertexColor(0.2, 0.18, 0.04, 1) end)
            row:SetScript("OnLeave", function(self) self.bg:SetVertexColor(0, 0, 0, 0) end)
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
    if not ui or not ui.frame:IsShown() then return end

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

    ui.statusText:SetText(string.format(L["|cffffd11a%d/%d|r Mail      |cffffd11a%d|r Items      Gold: %s"],
        withContent, #data, items, FormatMoney(gold)))

    local maxOffset = math.max(0, #visible - ROWS)
    ui.offset = math.min(math.max(ui.offset or 0, 0), maxOffset)

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
    return ui and ui.frame:IsShown() and ui.activeTab == "Send" and MailFrame and MailFrame:IsShown()
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
    for i, e in ipairs(queue) do
        local cell = ui.queueCells[i] or NewQueueCell(ui, i)
        cell.index = i
        cell.entry = e
        cell.icon:SetTexture(e.icon)
        cell.count:SetText(e.count > 1 and e.count or "")
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", ui.queueContent, "TOPLEFT",
            ((i - 1) % QUEUE_COLS) * QUEUE_STEP, -math.floor((i - 1) / QUEUE_COLS) * QUEUE_STEP)
        cell:Show()
    end
    for i = #queue + 1, #ui.queueCells do ui.queueCells[i]:Hide() end
    ui.queueContent:SetHeight(math.max(QUEUE_STEP, math.ceil(#queue / QUEUE_COLS) * QUEUE_STEP))
    local maxScroll = math.max(0, ui.queueContent:GetHeight() - ui.queueScroll:GetHeight())
    if ui.queueScroll:GetVerticalScroll() > maxScroll then ui.queueScroll:SetVerticalScroll(maxScroll) end
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
    if subject == "" then subject = "Bears Mailbox" end
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
    if ui and ui.frame:IsShown() then
        ui.message:SetText(msg)
    else
        print(msg)
    end
end

local function BuildInbox(parent, ui)
    ui.search = NewInput(parent, 860, 34, L["Search items in mailbox"])
    ui.search:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    ui.search:SetTextInsets(34, 8, 0, 0)
    ui.search.placeholder:ClearAllPoints()
    ui.search.placeholder:SetPoint("LEFT", 34, 0)
    local searchIcon = parent:CreateTexture(nil, "OVERLAY")
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("LEFT", ui.search, "LEFT", 10, 0)
    ui.search:HookScript("OnTextChanged", function() MailModule:RefreshInbox() end)

    local headerBar = NewBox(parent, C.row, C.border)
    headerBar:SetSize(860, 26)
    headerBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -44)
    local hItems = Text(headerBar, "GameFontNormalSmall", C.muted)
    hItems:SetPoint("LEFT", 12, 0)
    hItems:SetText(L["Items"])
    local hExpires = Text(headerBar, "GameFontNormalSmall", C.muted)
    hExpires:SetPoint("RIGHT", headerBar, "RIGHT", -190, 0)
    hExpires:SetText(L["Expires"])
    local hGold = Text(headerBar, "GameFontNormalSmall", C.muted)
    hGold:SetPoint("RIGHT", headerBar, "RIGHT", -12, 0)
    hGold:SetText(L["Gold"])

    ui.list = NewBox(parent, C.panel, C.border)
    ui.list:SetSize(860, ROWS * ROW_H)
    ui.list:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -70)
    ui.list:EnableMouse(true)
    ui.list:EnableMouseWheel(true)
    ui.list:SetScript("OnMouseWheel", function(_, delta)
        ui.offset = (ui.offset or 0) - delta
        MailModule:RefreshInbox()
    end)
    ui.offset = 0

    ui.empty = Text(ui.list, "GameFontNormal", C.muted, "CENTER")
    ui.empty:SetPoint("CENTER")

    ui.rows = {}
    for r = 1, ROWS do
        local row = CreateFrame("Button", nil, ui.list)
        row:SetSize(858, ROW_H)
        row:SetPoint("TOPLEFT", ui.list, "TOPLEFT", 1, -((r - 1) * ROW_H) - 1)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetTexture(WHITE)
        row.bg:SetAllPoints()
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", 8, 0)
        row.itemsClip = CreateFrame("Frame", nil, row)
        row.itemsClip:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.itemsClip:SetSize(440, ROW_H)
        row.itemsClip:SetClipsChildren(true)
        row.items = Text(row.itemsClip, "GameFontNormal", C.text)
        row.items:SetPoint("LEFT", row.itemsClip, "LEFT", 0, 0)
        row.items:SetWordWrap(false)
        row.expires = Text(row, "GameFontNormal", C.muted, "RIGHT")
        row.expires:SetPoint("RIGHT", row, "RIGHT", -190, 0)
        row.gold = Text(row, "GameFontNormal", C.text, "RIGHT")
        row.gold:SetPoint("RIGHT", row, "RIGHT", -12, 0)
        row:SetScript("OnClick", function(self)
            if self.mail then
                ui.selected = self.mail.index
                MailModule:RefreshInbox()
            end
        end)
        ui.rows[r] = row
    end

    ui.status = NewBox(parent, C.panel, C.border)
    ui.status:SetSize(860, 36)
    ui.status:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -442)
    ui.statusText = Text(ui.status, "GameFontNormal", C.text, "CENTER")
    ui.statusText:SetPoint("CENTER")

    ui.openBtn = NewButton(parent, L["Open Mail"], 860, 40)
    ui.openBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -488)
    ui.openBtn:SetScript("OnClick", function() MailModule:OpenSelected(ui.selected) end)

    local cats = { "Sold", "Bought", "Cancelled", "Expired", "Other" }
    for k, name in ipairs(cats) do
        local b = NewButton(parent, L["All " .. name], 165, 40)
        b:SetPoint("TOPLEFT", parent, "TOPLEFT", (k - 1) * 173, -538)
        b:SetScript("OnClick", function() MailModule:OpenCategory(name) end)
    end

    local openAll = NewButton(parent, L["Open All"], 209, 36)
    openAll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -588)
    openAll:SetScript("OnClick", function() MailModule:OpenAllMail() end)

    local delEmpty = NewButton(parent, L["Delete Empty"], 209, 36)
    delEmpty:SetPoint("TOPLEFT", parent, "TOPLEFT", 217, -588)
    delEmpty:SetScript("OnClick", function() MailModule:DeleteEmptyMail() end)

    ui.autoBtn = NewButton(parent, L["Auto-Open: Off"], 209, 36)
    ui.autoBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 434, -588)
    ui.autoBtn:SetScript("OnClick", function()
        MailModule:SetAutoOpen(not MailModule.addon.db.profile.autoOpen)
        MailModule:RefreshInbox()
    end)

    local replyBtn = NewButton(parent, L["Reply to Selected"], 209, 36)
    replyBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 651, -588)
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
    cell.icon:SetPoint("TOPLEFT", 4, -4)
    cell.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    cell.count = Text(cell, "GameFontNormal", C.text, "RIGHT")
    cell.count:SetPoint("BOTTOMRIGHT", -6, 4)
    cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cell:SetScript("OnClick", function(self)
        if self.index and not CursorHasItem() then MailModule:RemoveQueued(self.index) end
    end)
    cell:SetScript("OnReceiveDrag", function() MailModule:QueueFromCursor() end)
    cell:SetScript("OnEnter", function(self)
        if self.entry then
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
    local recipientLabel = Text(parent, "GameFontNormal", C.text)
    recipientLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -2)
    recipientLabel:SetText(L["Recipient"])

    ui.recipient = NewInput(parent, 480, 32)
    ui.recipient:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -22)

    ui.suggest = NewBox(parent, C.row, C.gold)
    ui.suggest:SetWidth(480)
    ui.suggest:SetPoint("TOPLEFT", ui.recipient, "BOTTOMLEFT", 0, -2)
    ui.suggest:SetFrameLevel(parent:GetFrameLevel() + 50)
    ui.suggest:Hide()
    ui.suggestRows = {}
    for i = 1, SUGGEST_MAX do
        local row = CreateFrame("Button", nil, ui.suggest)
        row:SetSize(478, 28)
        row:SetPoint("TOPLEFT", ui.suggest, "TOPLEFT", 1, -((i - 1) * 28) - 1)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetTexture(WHITE)
        row.bg:SetAllPoints()
        row.bg:SetVertexColor(0, 0, 0, 0)
        row.label = Text(row, "GameFontNormal", C.text)
        row.label:SetPoint("LEFT", 10, 0)
        row:SetScript("OnEnter", function(self) self.bg:SetVertexColor(0.2, 0.18, 0.04, 1) end)
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
    ui.contacts:SetPoint("LEFT", ui.recipient, "RIGHT", 4, 0)
    local arrow = ui.contacts:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetSize(12, 12)
    arrow:SetPoint("CENTER")
    ui.contacts:SetScript("OnClick", function(self) MailModule:ShowContactsMenu(self, ui) end)

    ui.addDetails = NewLink(parent, L["+ Add subject & description (optional)"], 340, 32, C.gold, "RIGHT")
    ui.addDetails:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -22)
    ui.addDetails:SetScript("OnClick", function() ui.setDetails(not ui.detailsShown) end)

    ui.subjectLabel = Text(parent, "GameFontNormal", C.text)
    ui.subjectLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -70)
    ui.subjectLabel:SetText(L["Subject"])
    ui.subject = NewInput(parent, 860, 30)
    ui.subject:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -88)

    ui.bodyLabel = Text(parent, "GameFontNormal", C.text)
    ui.bodyLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -128)
    ui.bodyLabel:SetText(L["Body"])
    ui.bodyBox = NewBox(parent, C.panel, C.border)
    ui.bodyBox:SetSize(860, 110)
    ui.bodyBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -146)
    local bodyScroll = CreateFrame("ScrollFrame", nil, ui.bodyBox)
    bodyScroll:SetPoint("TOPLEFT", ui.bodyBox, "TOPLEFT", 8, -8)
    bodyScroll:SetPoint("BOTTOMRIGHT", ui.bodyBox, "BOTTOMRIGHT", -8, 8)
    ui.body = CreateFrame("EditBox", nil, bodyScroll)
    ui.body:SetMultiLine(true)
    ui.body:SetFont(FONT_FILE, FONT_SIZES.GameFontHighlight, "")
    ui.body:SetAutoFocus(false)
    ui.body:SetWidth(840)
    ui.body:SetHeight(400)
    ui.body:SetScript("OnEscapePressed", ui.body.ClearFocus)
    bodyScroll:SetScrollChild(ui.body)
    bodyScroll:EnableMouseWheel(true)
    bodyScroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, self:GetVerticalScroll() - delta * 20))
    end)

    ui.itemsBox = NewBox(parent, C.panel, C.border)
    ui.itemsBox:SetSize(860, 256)
    local itemsHeader = NewBox(ui.itemsBox, C.row, C.border)
    itemsHeader:SetSize(860, 26)
    itemsHeader:SetPoint("TOPLEFT", ui.itemsBox, "TOPLEFT", 0, 0)
    local hItems = Text(itemsHeader, "GameFontNormalSmall", C.muted)
    hItems:SetPoint("LEFT", 12, 0)
    hItems:SetText(L["Items"])
    local hAmount = Text(itemsHeader, "GameFontNormalSmall", C.muted, "RIGHT")
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
    ui.queueCells = {}
    local footer = NewBox(ui.itemsBox, C.row, C.border)
    footer:SetSize(860, 30)
    footer:SetPoint("BOTTOMLEFT", ui.itemsBox, "BOTTOMLEFT", 0, 0)
    ui.postage = Text(footer, "GameFontNormal", C.text)
    ui.postage:SetPoint("LEFT", 12, 0)
    ui.postage:SetText(string.format(L["Total Postage: %s"], FormatMoneyText(30)))
    local allBags = NewButton(footer, L["Send all in bags"], 190, 24)
    allBags:SetPoint("RIGHT", footer, "RIGHT", -4, 0)
    allBags:SetScript("OnClick", function() MailModule:QueueAllBags() end)

    ui.goldLabel = Text(parent, "GameFontNormal", C.text)
    ui.goldLabel:SetText(L["Gold"])
    local function MoneyBox(suffix)
        local eb = NewInput(parent, 100, 30)
        eb:SetNumeric(true)
        eb:SetJustifyH("RIGHT")
        eb:SetTextInsets(8, 24, 0, 0)
        eb:SetText("0")
        local s = Text(eb, "GameFontNormal", { 0.85, 0.5, 0.2 }, "RIGHT")
        s:SetPoint("RIGHT", -8, 0)
        s:SetText(suffix)
        return eb
    end
    ui.goldG = MoneyBox("g")
    ui.goldS = MoneyBox("s")
    ui.goldC = MoneyBox("c")
    ui.cod = NewCheck(parent, L["Make COD"])

    ui.sendBtn = NewButton(parent, L["Send Mail"], 700, 40)
    ui.sendBtn:SetScript("OnClick", function() MailModule:SendFromUI() end)

    local clear = NewLink(parent, L["Clear All"], 140, 40, C.gold, "CENTER", "GameFontNormalLarge")
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
        ui.subject:SetShown(shown)
        ui.bodyLabel:SetShown(shown)
        ui.bodyBox:SetShown(shown)
        local itemsTop = shown and -270 or -70
        ui.itemsBox:ClearAllPoints()
        ui.itemsBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, itemsTop)
        local goldY = itemsTop - 270
        ui.goldLabel:ClearAllPoints()
        ui.goldLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, goldY - 8)
        ui.goldG:ClearAllPoints()
        ui.goldG:SetPoint("TOPLEFT", parent, "TOPLEFT", 60, goldY)
        ui.goldS:ClearAllPoints()
        ui.goldS:SetPoint("TOPLEFT", parent, "TOPLEFT", 170, goldY)
        ui.goldC:ClearAllPoints()
        ui.goldC:SetPoint("TOPLEFT", parent, "TOPLEFT", 280, goldY)
        ui.cod:ClearAllPoints()
        ui.cod:SetPoint("TOPLEFT", parent, "TOPLEFT", 400, goldY - 6)
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
        ui.relayout()
    end

    ui.setDetails(false)
end

function MailModule:ShowThemeMenu(anchor)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        self:Notify(string.format(L["Bears Mailbox: unknown theme. Available: %s"], self:ThemeList()))
        return
    end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        for _, theme in ipairs(self.THEMES) do
            root:CreateButton(theme.name, function() self:SetTheme(theme.key) end)
        end
    end)
end

function MailModule:ThemeList()
    local names = {}
    for _, theme in ipairs(self.THEMES) do table.insert(names, theme.key) end
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
        self.ui.frame:Hide()
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
    Box(f, C.bg, C.border)
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
    logo:SetSize(20, 20)
    logo:SetPoint("TOPLEFT", 20, -18)
    local _, raceFile = UnitRace("player")
    local sex = UnitSex("player") == 3 and "female" or "male"
    local raceAtlas = raceFile and ("raceicon-" .. string.lower(raceFile) .. "-" .. sex)
    if raceAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(raceAtlas) then
        logo:SetAtlas(raceAtlas)
    else
        logo:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    end
    local title = Text(f, "GameFontNormalHuge", C.text)
    title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    title:SetText("Bears Mailbox")

    local x = 270
    local tabNames = { "Inbox", "Send" }
    for _, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", nil, f)
        tab.label = Text(tab, "GameFontNormalLarge", C.muted, "CENTER")
        tab.label:SetText(L[name])
        tab:SetSize(tab.label:GetStringWidth() + 2, 30)
        tab.label:SetAllPoints()
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", x, -14)
        x = x + tab:GetWidth() + 28
        tab:SetScript("OnClick", function() ui.selectTab(name) end)
        ui.tabs[name] = tab
    end

    local close = NewLink(f, "X", 28, 28, C.text, "CENTER", "GameFontNormalLarge")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -14)
    close:SetScript("OnClick", function() f:Hide() end)

    local themeBtn = NewButton(f, L["Theme"], 130, 30)
    themeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -176, -13)
    themeBtn:SetScript("OnClick", function(self) MailModule:ShowThemeMenu(self) end)
    themeBtn.label:ClearAllPoints()
    themeBtn.label:SetPoint("CENTER", 12, 0)
    local themeIcon = themeBtn:CreateTexture(nil, "OVERLAY")
    themeIcon:SetSize(22, 22)
    themeIcon:SetPoint("LEFT", 8, 0)
    local themeAtlas = "raceicon-" .. (self.addon.db.profile.theme or "default") .. "-male"
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(themeAtlas) then
        themeIcon:SetAtlas(themeAtlas)
    else
        themeIcon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    end

    local wowUI = NewButton(f, L["WoW UI"], 110, 30)
    wowUI:SetPoint("TOPRIGHT", f, "TOPRIGHT", -56, -13)
    wowUI:SetScript("OnClick", function()
        f:Hide()
        MailModule:RestoreBlizzardMail()
    end)

    local sep = f:CreateTexture(nil, "BORDER")
    sep:SetTexture(WHITE)
    sep:SetVertexColor(unpack(C.border))
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -56)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -56)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -72)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 28)

    ui.message = Text(f, "GameFontNormal", C.gold)
    ui.message:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 6)
    ui.message:SetWidth(860)

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
        if MailFrame and MailFrame:IsShown() then
            local tab = (name == "Send" and MailFrameTab2) or (name == "Inbox" and MailFrameTab1)
            if tab then tab:Click() end
        end
        MailModule:RefreshQueue()
        for n, t in pairs(ui.tabs) do
            t.label:SetTextColor(unpack(n == name and C.gold or C.muted))
        end
    end

    self.ui = ui
    self.mainFrame = f
    ui.selectTab("Inbox")
    f:Show()
end

if C_Container then
    local originalUseContainerItem = C_Container.UseContainerItem
    C_Container.UseContainerItem = function(bag, slot, ...)
        if MailModule:IsQueuing() then
            MailModule:QueueItem(bag, slot)
            return
        end
        return originalUseContainerItem(bag, slot, ...)
    end
    hooksecurefunc(C_Container, "PickupContainerItem", function(bag, slot)
        if MailModule.ui then
            MailModule.ui.lastPickup = { bag = bag, slot = slot }
        end
    end)
end
