local addonName = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)

local BearsMailbox = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")
_G.BearsMailbox = BearsMailbox

BearsMailbox.opening = false
BearsMailbox.sending = false

function BearsMailbox:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("BearsMailboxDB", { profile = { autoOpen = false, autoShowWindow = true, minimap = { hide = false, minimapPos = 90 } } }, true)
    self:RegisterChatCommand("bmailbox", "SlashCmd")
    self:RegisterChatCommand("bm", "SlashCmd")
    self:RegisterChatCommand("mailbox", "SlashCmd")
end

function BearsMailbox:OnEnable()
    if _G.BearsMailboxMail and _G.BearsMailboxMail.Init then
        _G.BearsMailboxMail:Init(self)
    end
    -- Minimap button
    local LDB = LibStub("LibDataBroker-1.1", true)
    local icon = LibStub("LibDBIcon-1.0", true)
    if LDB and icon then
        local dataObj = LDB:NewDataObject("BearsMailbox", {
            type = "launcher",
            icon = "Interface\\Icons\\inv_letter_18",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    if _G.BearsMailboxMail and _G.BearsMailboxMail.ShowMailingWindow then
                        _G.BearsMailboxMail:ShowMailingWindow()
                    elseif ToggleMailFrame then
                        ToggleMailFrame()
                    end
                elseif button == "RightButton" then
                    local cur = self.db.profile.autoOpen
                    self:SetAutoOpen(not cur)
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("Bears Mailbox")
                tooltip:AddLine(L["Left-click: Toggle mail frame"], 0.8, 0.8, 0.8)
                tooltip:AddLine(L["Right-click: Toggle auto-open"], 0.8, 0.8, 0.8)
            end,
        })
        self.db.profile.minimap = self.db.profile.minimap or {}
        if self.db.profile.minimap.minimapPos == nil then
            self.db.profile.minimap.minimapPos = 90
        end
        icon:Register("BearsMailbox", dataObj, self.db.profile.minimap)
    end
end

function BearsMailbox:SlashCmd(input)
    input = (input or ""):trim()
    if input == "" then
        print(L["Bears Mailbox commands:"])
        print(L["  /bm openall | /bm takeall"])
        print(L["  /bm send <recipient>"])
        print(L["  /bm sendgold <recipient> <amount> [subject]"])
        print(L["  /bm sendletter <recipient> <subject> | <body>"])
        print(L["  /bm sendcod <recipient> <amount> [subject]"])
        print(L["  /bm return <index>"])
        print(L["  /bm deleteempty"])
        print(L["  /bm reply <index>"])
        print(L["  /bm search <text>"])
        print(L["  /bm pending | /bm pending clear"])
        print(L["  /bm window | /bm mail  (standalone window)"])
        print(L["  /bm test  (open window with test data)"])


        print(L["  /bm autoopen on|off"])
        return
    elseif input == "openall" or input == "takeall" then
        self:OpenAllMail()
    elseif input:match("^sendgold ") then
        local recip, amt, subj = input:match("^sendgold (%S+) (%S+)%s*(.*)$")
        self:SendGold(recip, amt, subj)
    elseif input:match("^sendletter ") then
        local rest = input:match("^sendletter (.+)$")
        local recip, subject, body = rest:match("^(%S+)%s+(.-)%s*|%s*(.*)$")
        if not recip then recip, subject = rest:match("^(%S+)%s+(.+)$") body = "" end
        self:SendLetter(recip, subject or "", body or "", 0)
    elseif input:match("^send ") then
        local recip = input:match("^send (.+)$")
        self:SendAll(recip)
    elseif input:match("^return ") then
        self:ReturnMail(input:match("^return (.+)$"))
    elseif input == "deleteempty" then
        self:DeleteEmptyMail()
    elseif input:match("^reply ") then
        self:ReplyToMail(input:match("^reply (.+)$"))
    elseif input:match("^search ") then
        self:SearchInbox(input:match("^search (.+)$"))
    elseif input == "debug" then
        if _G.BearsMailboxMail and _G.BearsMailboxMail.ShowDebug then
            _G.BearsMailboxMail:ShowDebug()
        end
    elseif input == "window" or input == "mail" or input == "mailbox" then
        if _G.BearsMailboxMail and _G.BearsMailboxMail.ShowMailingWindow then
            _G.BearsMailboxMail:ShowMailingWindow()
        end
    elseif input == "test" then
        if _G.BearsMailboxMail and _G.BearsMailboxMail.ShowTestWindow then
            _G.BearsMailboxMail:ShowTestWindow()
        end
    elseif input:match("^theme") then
        local key = input:match("^theme%s+(%S+)$")
        if key then
            _G.BearsMailboxMail:SetTheme(key)
        else
            _G.BearsMailboxMail:Notify(string.format(L["Bears Mailbox: unknown theme. Available: %s"], _G.BearsMailboxMail:ThemeList()))
        end
    elseif input == "pending" then
        self:ListPending()
    elseif input == "pending clear" then
        self:ClearPending()
    elseif input:match("^sendcod ") then
        local recip, amt, subj = input:match("^sendcod (%S+) (%S+)%s*(.*)$")
        self:SendCOD(recip, amt, subj)
    elseif input:match("^autoopen ") then
        local v = input:match("^autoopen (.+)$")
        self:SetAutoOpen(v == "on")
    else
        print(L["Bears Mailbox: unknown command"])
    end
end

-- Forward declarations filled by mailbox.lua
function BearsMailbox:OpenAllMail() end
function BearsMailbox:SendAll(recipient) end