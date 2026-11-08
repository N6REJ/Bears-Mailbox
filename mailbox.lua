local addonName = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local BearsMailbox = _G.BearsMailbox

local MailModule = {}
_G.BearsMailboxMail = MailModule

local function Notify(msg)
    MailModule:Notify(msg)
end

local ATTACHMENTS_MAX_SEND = _G.ATTACHMENTS_MAX_SEND or 12

-- Compatibility helpers for retail + classic (forever)
local function CompatContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    if GetContainerNumSlots then
        return GetContainerNumSlots(bag) or 0
    end
    return 0
end

local function CompatContainerItemLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    end
    if GetContainerItemLink then
        return GetContainerItemLink(bag, slot)
    end
    return nil
end

local function CompatContainerItemCount(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            return info.stackCount or info.count or info.quantity or 1
        end
        return 0
    end
    if GetContainerItemInfo then
        local _, count = GetContainerItemInfo(bag, slot)
        return count or 0
    end
    return 0
end

local function CompatPickupContainerItem(bag, slot)
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(bag, slot)
    elseif PickupContainerItem then
        PickupContainerItem(bag, slot)
    end
end

local function CompatSplitContainerItem(bag, slot, amount)
    if C_Container and C_Container.SplitContainerItem then
        C_Container.SplitContainerItem(bag, slot, amount)
    elseif SplitContainerItem then
        SplitContainerItem(bag, slot, amount)
    end
end

local function CompatGetFriends()
    local list = {}
    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, C_FriendList.GetNumFriends() do
            local fi = C_FriendList.GetFriendInfoByIndex(i)
            if fi and fi.name then table.insert(list, fi.name) end
        end
    elseif GetNumFriends and GetFriendInfo then
        for i = 1, GetNumFriends() do
            local name = GetFriendInfo(i)
            if name then table.insert(list, name) end
        end
    end
    if C_BattleNet and C_BattleNet.GetNumFriends then
        for i = 1, C_BattleNet.GetNumFriends() do
            local info = C_BattleNet.GetFriendAccountInfo(i)
            local game = info and info.gameAccountInfo
            if game and game.characterName and game.characterName ~= "" then
                local name = game.characterName
                if game.realmName and game.realmName ~= "" and game.realmName ~= GetRealmName() then
                    name = name .. "-" .. (game.realmName:gsub("%s", ""))
                end
                table.insert(list, name)
            end
        end
    end
    return list
end

MailModule.CompatGetFriends = CompatGetFriends

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

MailModule.addon = nil
MailModule.eventFrame = nil
MailModule.opening = false
MailModule.sending = false
MailModule.sendQueue = {}
MailModule.sendIndex = 1
MailModule.sendRecipient = nil
MailModule.sendSubject = "Bears Mailbox"
MailModule.hooked = false

local function ReadInboxHeader(i)
    local _, _, sender, subject, money, cod, days, hasItem = GetInboxHeaderInfo(i)
    return sender, subject, money, cod, days, hasItem
end

function MailModule:SavePosition(frame, key)
    local db = self.addon and self.addon.db
    if not db then return end
    local point, _, relPoint, x, y = frame:GetPoint(1)
    db.profile[key] = { point, relPoint, x, y }
end

function MailModule:RestorePosition(frame, key)
    local db = self.addon and self.addon.db
    local pos = db and db.profile[key]
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        frame:SetPoint("CENTER")
    end
end

function MailModule:Init(addon)
    self.addon = addon
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("MAIL_SUCCESS")
    self.eventFrame:RegisterEvent("MAIL_FAILED")
    self.eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
    self.eventFrame:RegisterEvent("MAIL_SHOW")
    self.eventFrame:RegisterEvent("MAIL_CLOSED")
    self.eventFrame:RegisterEvent("UI_ERROR_MESSAGE")
    self.eventFrame:RegisterEvent("ADDON_LOADED")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "ADDON_LOADED" then
            local name = ...
            if name == "Blizzard_MailUI" or MailFrame then
                self:HookMailFrame()
            end
        else
            self:OnEvent(event, ...)
        end
    end)
    self:HookMailFrame()
    C_Timer.NewTicker(1, function(ticker)
        if MailFrame then
            self:HookMailFrame()
            if self.hooked then ticker:Cancel() end
        end
    end)
end

function MailModule:OnEvent(event, ...)
    local parts = { event }
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    self:Debug(table.concat(parts, " | "))
    if event == "MAIL_SUCCESS" then
        if self.sending then
            C_Timer.After(0.6, function() self:SendNextBatch() end)
        elseif self.sendingGold then
            self.sendingGold = false
            Notify(L["Bears Mailbox: gold sent."])
        elseif self.sendingLetter then
            self.sendingLetter = false
            Notify(L["Bears Mailbox: letter sent."])
        end
    elseif event == "MAIL_FAILED" then
        if self.sending then
            self.sending = false
            self.addon.sending = false
            self.sendExtras = nil
            ClearSendMail()
            local reason = self.lastUIError or L["unknown reason (see /bm debug)"]
            Notify(string.format(L["Bears Mailbox: send failed: %s Items were returned to your bags."], reason))
        end
    elseif event == "UI_ERROR_MESSAGE" then
        local _, msg = ...
        self.lastUIError = msg
        if self.sending and msg then Notify(string.format(L["Bears Mailbox: %s"], msg)) end
    elseif event == "MAIL_INBOX_UPDATE" then
        if self.openResume then self.openResume() end
        self:CheckExpiring()
        self:RefreshInbox()
    elseif event == "MAIL_SHOW" then
        self:OnMailShow()
    elseif event == "MAIL_CLOSED" then
        self:OnMailClosed()
    end
end

function MailModule:Debug(msg)
    self.debugLog = self.debugLog or {}
    table.insert(self.debugLog, tostring(msg))
    if #self.debugLog > 300 then table.remove(self.debugLog, 1) end
end

function MailModule:ShowMailingWindow()
    return self:ShowMainWindow()
end

function MailModule:ShowDebug()
    if not self.debugFrame then
        local f = CreateFrame("Frame", "BearsMailboxDebugFrame", UIParent, BACKDROP_TEMPLATE)
        f:SetSize(440, 320)
        self:RestorePosition(f, "debugPos")
        f:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = {left=2, right=2, top=2, bottom=2}})
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", function(frame)
            frame:StopMovingOrSizing()
            self:SavePosition(frame, "debugPos")
        end)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
        sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 8)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetSize(390, 300)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal)
        eb:SetAutoFocus(false)
        eb:EnableMouse(true)
        sf:SetScrollChild(eb)
        self.debugFrame = f
        self.debugEditBox = eb
    end
    self.debugEditBox:SetText(table.concat(self.debugLog or {}, "\n"))
    self.debugFrame:Show()
end

function MailModule:HookMailFrame()
    if self.hooked then return end
    if not MailFrame then return end
    self.hooked = true
    self:Debug("Bears Mailbox: hooked MailFrame")
    MailFrame:HookScript("OnShow", function()
        C_Timer.After(0.1, function() self:CreateButtons() end)
    end)
    self:CreateButtons()
end

function MailModule:CreateButtons()
    if self.openButton then return end
    local parent = InboxFrame
    if not parent then return end

    local btn = CreateFrame("Button", "BearsMailboxOpenAllButton", parent, "UIPanelButtonTemplate")
    btn:SetSize(100, 22)
    btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 8)
    btn:SetText(L["Open All"])
    btn:SetScript("OnClick", function() self:OpenAllMail() end)
    self.openButton = btn
end

function MailModule:OpenAllMail()
    if self.opening then
        Notify(L["Bears Mailbox: already opening mail, please wait."])
        return
    end
    Notify(L["Bears Mailbox: opening all mail..."])
    self:OpenFiltered(function(i)
        local _, _, money, cod, _, hasItem = ReadInboxHeader(i)
        return (cod or 0) == 0 and (money > 0 or (hasItem or 0) > 0)
    end)
end

function MailModule:SendAll(recipient)
    if self.sending then return end
    if not recipient or recipient == "" then
        Notify(L["Bears Mailbox: no recipient."])
        return
    end
    self.sendQueue = self:CollectSendableItems()
    if #self.sendQueue == 0 then
        Notify(L["Bears Mailbox: no items to send."])
        return
    end
    -- record pending items
    local pendingItems = {}
    for _, it in ipairs(self.sendQueue) do
        local link = CompatContainerItemLink(it.bag, it.slot)
        local count = CompatContainerItemCount(it.bag, it.slot)
        if count == 0 then count = 1 end
        if link then pendingItems[link] = (pendingItems[link] or 0) + count end
    end
    self:RecordPending(recipient, pendingItems)

    self.sending = true
    self.sendIndex = 1
    self.sendRecipient = recipient
    self.addon.sending = true
    Notify(string.format(L["Bears Mailbox: sending %d items to %s..."], #self.sendQueue, recipient))
    ClearSendMail()
    self:SendNextBatch()
end

function MailModule:CollectSendableItems()
    local list = {}
    for bag = 0, 4 do
        local slots = CompatContainerNumSlots(bag)
        for slot = 1, slots do
            local link = CompatContainerItemLink(bag, slot)
            if link then
                table.insert(list, { bag = bag, slot = slot })
            end
        end
    end
    return list
end

function MailModule:SendNextBatch()
    if not self.sending then return end
    if self.sendIndex > #self.sendQueue then
        self.sending = false
        self.addon.sending = false
        ClearSendMail()
        Notify(string.format(L["Bears Mailbox: sent %d items to %s."], #self.sendQueue, self.sendRecipient or "?"))
        return
    end
    self.lastUIError = nil
    Notify(string.format(L["Bears Mailbox: sending mail %d of %d..."], math.ceil(self.sendIndex / ATTACHMENTS_MAX_SEND), math.ceil(#self.sendQueue / ATTACHMENTS_MAX_SEND)))
    ClearSendMail()
    local attached = 0
    while attached < ATTACHMENTS_MAX_SEND and self.sendIndex <= #self.sendQueue do
        local it = self.sendQueue[self.sendIndex]
        self.sendIndex = self.sendIndex + 1
        CompatPickupContainerItem(it.bag, it.slot)
        ClickSendMailItemButton(attached + 1)
        attached = attached + 1
    end
    C_Timer.After(0.5, function()
        if not self.sending then return end
        local ex = self.sendExtras
        self.sendExtras = nil
        if ex and ex.money > 0 then
            if ex.cod then SetSendMailCOD(ex.money) else SetSendMailMoney(ex.money) end
        end
        SendMail(self.sendRecipient, self.sendSubject, ex and ex.body or "")
    end)
end


function MailModule:GetPending()
    local db = self.addon and self.addon.db
    if not db or not db.profile then return {} end
    db.profile.pendingMail = db.profile.pendingMail or {}
    return db.profile.pendingMail
end

function MailModule:RecordPending(recipient, items)
    if not recipient or not items or not next(items) then return end
    local pending = self:GetPending()
    pending[recipient] = pending[recipient] or {}
    for link, count in pairs(items) do
        pending[recipient][link] = (pending[recipient][link] or 0) + (count or 1)
    end
end

function MailModule:ClearPending(recipient)
    local pending = self:GetPending()
    if recipient then pending[recipient] = nil else wipe(pending) end
end

function MailModule:ListPending()
    local pending = self:GetPending()
    local any = false
    for recip, items in pairs(pending) do
        print(string.format(L["Pending to %s:"], recip))
        for link, count in pairs(items) do
            print("  " .. (link or "?") .. " x" .. (count or 1))
            any = true
        end
        any = true
    end
    if not any then Notify(L["Bears Mailbox: no pending mail."]) end
end

function MailModule:GetRecentRecipients()
    local db = self.addon and self.addon.db
    if not db or not db.profile then return {} end
    db.profile.recentRecipients = db.profile.recentRecipients or {}
    return db.profile.recentRecipients
end

function MailModule:AddRecentRecipient(name)
    if not name or name == "" then return end
    local list = self:GetRecentRecipients()
    -- remove existing
    for i = #list, 1, -1 do
        if list[i] == name then table.remove(list, i) end
    end
    table.insert(list, 1, name)
    while #list > 20 do table.remove(list) end
end

-- Store recipient as recent when sending
local _origSendAll = MailModule.SendAll
MailModule.SendAll = function(self, recipient)
    self:AddRecentRecipient(recipient)
    return _origSendAll(self, recipient)
end

MailModule.checkTicker = nil
MailModule.warnedExpiring = nil
MailModule.sendingGold = false
MailModule.sendingLetter = false

function MailModule:OnMailShow()
    self:Debug("Bears Mailbox: MAIL_SHOW (MailFrame=" .. tostring(MailFrame ~= nil) .. ", InboxFrame=" .. tostring(InboxFrame ~= nil) .. ")")
    if self.checkTicker then self.checkTicker:Cancel() end
    if CheckInbox then CheckInbox() end
    if not self.sending then ClearSendMail() end
    local db = self.addon and self.addon.db
    if db and db.profile and db.profile.autoShowWindow then
        C_Timer.After(0.1, function()
            self:ShowMainWindow()
            self:HideBlizzardMail()
        end)
    end
    self.checkTicker = C_Timer.NewTicker(15, function()
        if InboxFrame and InboxFrame:IsShown() then
            if CheckInbox then CheckInbox() end
        end
    end)
    local db = self.addon and self.addon.db
    if db and db.profile and db.profile.autoOpen then
        C_Timer.After(0.5, function() self:OpenAllMail() end)
    end
    C_Timer.After(0.1, function() self:CreateButtons() end)
end

function MailModule:OnMailClosed()
    self:RestoreBlizzardMail()
    if self.checkTicker then self.checkTicker:Cancel() self.checkTicker = nil end
end

function MailModule:CheckExpiring()
    self.warnedExpiring = self.warnedExpiring or {}
    local num = GetInboxNumItems()
    for i = 1, num do
        local sender, subject, money, COD, days, hasItem = ReadInboxHeader(i)
        if days and days <= 3 and not self.warnedExpiring[i] then
            self.warnedExpiring[i] = true
            self:Debug(string.format("mail from %s expires in %d day(s): %s", sender or "?", days, subject or ""))
        end
    end
end

function MailModule:SendGold(recipient, amount, subject)
    if not recipient or recipient == "" then Notify(L["Bears Mailbox: no recipient."]) return end
    amount = tonumber(amount) or 0
    if amount <= 0 then Notify(L["Bears Mailbox: invalid amount."]) return end
    self:AddRecentRecipient(recipient)
    ClearSendMail()
    if SetSendMailMoney then SetSendMailMoney(amount) end
    self.sendingGold = true
    SendMail(recipient, subject or L["Gold"], "")
    Notify(string.format(L["Bears Mailbox: sending gold to %s"], recipient))
end

function MailModule:SendLetter(recipient, subject, body, money)
    if not recipient or recipient == "" then Notify(L["Bears Mailbox: no recipient."]) return end
    self:AddRecentRecipient(recipient)
    ClearSendMail()
    if money and money > 0 and SetSendMailMoney then SetSendMailMoney(money) end
    self.sendingLetter = true
    SendMail(recipient, subject or "", body or "")
    Notify(string.format(L["Bears Mailbox: sending letter to %s"], recipient))
end

function MailModule:SendCOD(recipient, amount, subject, body, items)
    if not recipient or recipient == "" then Notify(L["Bears Mailbox: no recipient."]) return end
    amount = tonumber(amount) or 0
    if amount <= 0 then Notify(L["Bears Mailbox: invalid COD amount."]) return end
    self:AddRecentRecipient(recipient)
    ClearSendMail()
    if SetSendMailCOD then SetSendMailCOD(amount) end
    -- attach items if provided (whole stacks from bags) - optional
    if items and #items > 0 then
        self.sendQueue = items
        self.sendIndex = 1
        self.sending = true
        self.addon.sending = true
        Notify(string.format(L["Bears Mailbox: sending COD (%s copper) to %s..."], amount, recipient))
        self:SendNextBatch()
        -- SendMail will be called per batch; COD set once. Note: COD only on first mail ideally.
    else
        self.sendingLetter = true
        SendMail(recipient, subject or "COD", body or "")
        Notify(string.format(L["Bears Mailbox: sending COD letter to %s"], recipient))
    end
end

function MailModule:ReturnMail(index)
    index = tonumber(index)
    if not index then Notify(L["Bears Mailbox: specify mail index."]) return end
    if ReturnInboxItem then
        ReturnInboxItem(index)
        Notify(string.format(L["Bears Mailbox: returned mail %s"], index))
    else
        Notify(L["Bears Mailbox: return not supported."])
    end
end

function MailModule:DeleteEmptyMail()
    local deleted = 0
    local num = GetInboxNumItems()
    self.lastUIError = nil
    for i = num, 1, -1 do
        local sender, subject, money, COD, days, hasItem = ReadInboxHeader(i)
        if (not money or money == 0) and (not hasItem or hasItem == 0) then
            if DeleteInboxItem then DeleteInboxItem(i) deleted = deleted + 1 end
        end
    end
    local reason = self.lastUIError and string.format(L[" Game said: %s"], self.lastUIError) or ""
    Notify(string.format(L["Bears Mailbox: tried to delete %d empty mail(s)."], deleted) .. reason)
end

function MailModule:ReplyToMail(index)
    index = tonumber(index) or 1
    local sender = select(1, ReadInboxHeader(index))
    if sender and SendMailNameEditBox then
        SendMailNameEditBox:SetText(sender)
        if SendMailSubjectEditBox then
            local subject = select(2, ReadInboxHeader(index))
            SendMailSubjectEditBox:SetText(string.format(L["Re: %s"], subject or ""))
        end
        Notify(string.format(L["Bears Mailbox: reply to %s"], sender))
    end
end

function MailModule:SearchInbox(query)
    if not query or query == "" then Notify(L["Bears Mailbox: specify search text."]) return end
    local q = string.lower(query)
    local num = GetInboxNumItems()
    local found = 0
    for i = 1, num do
        local sender, subject, money, COD, days, hasItem = ReadInboxHeader(i)
        local itemMatch = false
        for j = 1, ATTACHMENTS_MAX_RECEIVE do
            local name = GetInboxItem(i, j)
            if name and string.find(string.lower(name), q, 1, true) then itemMatch = true end
        end
        if (sender and string.find(string.lower(sender), q, 1, true)) or
            (subject and string.find(string.lower(subject), q, 1, true)) or itemMatch then
            print(string.format("[%d] %s - %s", i, sender or "?", subject or ""))
            found = found + 1
        end
    end
    Notify(string.format(L["Bears Mailbox: %d match(es)."], found))
end

function MailModule:SendSelected(items, recipient)
    -- items: array of {bag, slot}
    if not recipient or recipient == "" then Notify(L["Bears Mailbox: no recipient."]) return end
    if not items or #items == 0 then Notify(L["Bears Mailbox: no items selected."]) return end
    local pendingItems = {}
    for _, it in ipairs(items) do
        local link = CompatContainerItemLink(it.bag, it.slot)
        local count = CompatContainerItemCount(it.bag, it.slot)
        if count == 0 then count = 1 end
        if link then pendingItems[link] = (pendingItems[link] or 0) + count end
    end
    self:RecordPending(recipient, pendingItems)
    self.sendQueue = items
    self.sendIndex = 1
    self.sendRecipient = recipient
    self.sending = true
    self.addon.sending = true
    self:AddRecentRecipient(recipient)
    Notify(string.format(L["Bears Mailbox: sending %d selected items to %s..."], #items, recipient))
    ClearSendMail()
    self:SendNextBatch()
end

function MailModule:FindEmptyBagSlot()
    for b = 0, 4 do
        local slots = CompatContainerNumSlots(b)
        for s = 1, slots do
            local link = CompatContainerItemLink(b, s)
            if not link then return b, s end
        end
    end
    return nil
end

function MailModule:SendPartialItems(recipient, list)
    if not recipient or recipient == "" then Notify(L["Bears Mailbox: no recipient."]) return end
    if not list or #list == 0 then Notify(L["Bears Mailbox: no items."]) return end
    local prepared = {}
    for _, req in ipairs(list) do
        local bag, slot, qty = req.bag, req.slot, req.quantity
        local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
        local stackCount = info and info.stackCount or 1
        qty = tonumber(qty) or stackCount
        if qty >= stackCount then
            table.insert(prepared, { bag = bag, slot = slot })
        else
            local eb, es = self:FindEmptyBagSlot()
            if not eb then Notify(L["Bears Mailbox: no empty bag slot for split."]) return end
            CompatSplitContainerItem(bag, slot, qty)
            CompatPickupContainerItem(eb, es)
            table.insert(prepared, { bag = eb, slot = es })
        end
    end
    self:SendSelected(prepared, recipient)
end

-- auto-open option helper
function MailModule:SetAutoOpen(enabled)
    local db = self.addon and self.addon.db
    if db and db.profile then db.profile.autoOpen = enabled and true or false end
    Notify(string.format(L["Bears Mailbox: auto-open %s"], enabled and L["enabled"] or L["disabled"]))
end

-- Expose to addon
BearsMailbox.OpenAllMail = function(self) MailModule:OpenAllMail() end
BearsMailbox.SendAll = function(self, recipient) MailModule:SendAll(recipient) end
BearsMailbox.SendGold = function(self, recipient, amount, subject) MailModule:SendGold(recipient, amount, subject) end
BearsMailbox.SendLetter = function(self, recipient, subject, body, money) MailModule:SendLetter(recipient, subject, body, money) end
BearsMailbox.ReturnMail = function(self, index) MailModule:ReturnMail(index) end
BearsMailbox.DeleteEmptyMail = function(self) MailModule:DeleteEmptyMail() end
BearsMailbox.ReplyToMail = function(self, index) MailModule:ReplyToMail(index) end
BearsMailbox.SearchInbox = function(self, query) MailModule:SearchInbox(query) end
BearsMailbox.SetAutoOpen = function(self, enabled) MailModule:SetAutoOpen(enabled) end
BearsMailbox.ShowDebug = function(self) MailModule:ShowDebug() end
BearsMailbox.ShowMailingWindow = function(self) MailModule:ShowMailingWindow() end
BearsMailbox.ShowMainWindow = function(self) MailModule:ShowMainWindow() end
BearsMailbox.SendPartialItems = function(self, recipient, list) MailModule:SendPartialItems(recipient, list) end
BearsMailbox.SendCOD = function(self, recipient, amount, subject, body) MailModule:SendCOD(recipient, amount, subject, body) end
BearsMailbox.ListPending = function(self) MailModule:ListPending() end
BearsMailbox.ClearPending = function(self, recipient) MailModule:ClearPending(recipient) end
