local AddonName,addon = ...
_G.DuelBookie = LibStub('AceAddon-3.0'):NewAddon(addon, AddonName, "AceComm-3.0", "AceSerializer-3.0")

DuelBookie.playerName = UnitName("player")
DuelBookie.debug = false
DuelBookie.autoAcceptTrades = false
DuelBookie.bookieStatus = {}
DuelBookie.activeTrade = {}

--Enums TODO: find cleaner way for client/bookie statuses
DuelBookie.clientStatus = {
	Inactive = 1,
	WaitingForWager = 2,
	WaitingForTrade = 3,
	WaitingForResults = 4,
	WaitingForPayout = 5,
	ConclusionLost = 6,
	ConclusionPaid = 7,
}

DuelBookie.clientStatusShort = {
	"DONE",
	"PENDING",
	"OWES",
	"WAGERED",
	"NEEDS",
	"LOST",
	"WAS PAID",
}

DuelBookie.betStatus = {
	Open = 0,
	BetsClosed = 1,
	PendingPayout = 2,
	Complete = 3,
	Cancelled = 4,
}


function DuelBookie:OnInitialize()
	self:Debug("MDB initialized")
	self:RegisterComm("DuelBookie")
	self:GUIInit()

	if addon.debug then 
		addon:GUI_ShowRootFrame() 
	else
		addon:GUI_HideRootFrame()
	end
end

function DuelBookie_OnLoad(self)
	addon:Debug("onload")

	self:RegisterEvent("TRADE_ACCEPT_UPDATE")
	self:RegisterEvent("PLAYER_TRADE_MONEY")
	self:RegisterEvent("TRADE_SHOW")
	self:RegisterEvent("TRADE_CLOSED")
end

function DuelBookie_OnEvent(self, event, ...)
	if event == "TRADE_SHOW" then
		if addon.isBookie then
			addon.BookieBets:InitiateTrade()
		else
			addon.ClientBets:InitiateTrade()
		end
	end

	if event == "TRADE_ACCEPT_UPDATE" then
		args = { ... }
		if addon.isBookie and addon.autoAcceptTrades and args[2] == 1 then
			AcceptTrade()
		end

		if args[1] == 1 then
			if addon.isBookie then
				addon.BookieBets:SetTradeAmount()	
			else
				addon.ClientBets:SetTradeAmount()	
			end
		end
	end

	if event == "PLAYER_TRADE_MONEY" then
		if addon.isBookie then
			addon.BookieBets:HandleTrade()	
		else
			addon.ClientBets:HandleTrade()	
		end
	end

	if event == "TRADE_CLOSED" then
		if addon.isBookie then
			addon.BookieBets:FinalizeTrade()	
		else
			addon.ClientBets:FinalizeTrade()	
		end
	end
end

comm_msgs = {
	new_bet = {
		callback = function(data) ClientBets:RefreshAvailableBets() end
	}, 
	get_available_bets = {
		callback = function(data) BookieBets:SendAvailableBet(data) end
	},
	refresh_bets = {
		callback = function(data) ClientBets:RefreshBets(data) end
	},
	send_wager = {
		callback = function(data) BookieBets:ReceiveWager(data) end
	},
	update_client_status = {
		callback = function(data) ClientBets:UpdateStatus(data) end
	}, 
	send_client_trade = {
		callback = function(data) BookieBets:ReceieveClientTrade(data) end
	},
	send_odds = {
		callback = function(data) ClientBets:ReceiveOdds(data) end
	},
	cancel_bet = {
		callback = function(data) ClientBets:ReceiveCancelledBet(data) end
	}
}

--- Send a DuelBookie Comm Message using AceComm-3.0
-- See DuelBookie:OnCommReceived() on how to receive these messages.
-- @param target The receiver of the message. Can be "group", "guild" or "playerName".
-- @param command The command to send.
-- @param ... Any number of arguments to send along. Will be packaged as a table.
function DuelBookie:SendCommand(target, command, data)
	-- send all data as a table, and let receiver unpack it
	local toSend = self:Serialize(command, data)

	if target == "group" then
		if IsInRaid() then -- Raid
			self:SendCommMessage("DuelBookie", toSend, "RAID")
		elseif IsInGroup() then -- Party
			self:SendCommMessage("DuelBookie", toSend, "PARTY")
		else--if self.testMode then -- Alone (testing)
			self:SendCommMessage("DuelBookie", toSend, "WHISPER", self.playerName)
		end

	elseif target == "guild" then
		self:SendCommMessage("DuelBookie", toSend, "GUILD")
	end
end

--- Receives DuelBookie commands.
-- Params are delivered by AceComm-3.0, but we need to extract our data created with the
-- DuelBookie:SendCommand function.
-- @usage
-- --To extract the original data using AceSerializer-3.0:
-- local success, command, data = self:Deserialize(serializedMsg)
-- --'data' is a table containing the varargs delivered to DuelBookie:SendCommand().
function DuelBookie:OnCommReceived(prefix, serializedMsg, distri, sender)
	if prefix ~= "DuelBookie" then
		addon:Debug("Error: Invalid comm prefix.")
		return
	end

	-- data is always a table to be unpacked
	local test, command, data = self:Deserialize(serializedMsg)

	if not test then self:Debug("Error with com received!"); return end
	if not comm_msgs[command] then self:Debug("Invalid command message"); return end

	comm_msgs[command].callback(data)
end

function DuelBookie:Debug(msg, ...)
	if self.debug then print(msg) end
end

function DuelBookie:FormatMoney(money)
	if money == 0 then return "0g" end

    local ret = ""
    local gold = floor(money/10000)
    local silver = floor((money - (gold * 10000)) / 100)
    local copper = floor(mod(money, 100))
    if gold > 0 then
        ret = gold .. "g "
    end
    if silver > 0 or copper > 0 then
        ret = ret .. silver .. "s "
    end
    if copper > 0 then
    	ret = ret .. copper .. "c"
    end
    return ret
end

function DuelBookie:GetClientStatusText(status)
	for k,v in pairs(self.clientStatus) do
		if v == status then return k end
	end
end

function DuelBookie:GetClientStatusTextShort(status)
	return self.clientStatusShort[status]
end

function DuelBookie:GetBetStatusText(status)
	for k,v in pairs(self.betStatus) do
		if v == status then return k end
	end
end

function MDB_ShowRootFrame()
	addon:GUI_ShowRootFrame()
end

function MDB_HideRootFrame()
	addon:GUI_HideRootFrame()
end


local slash_cmds = {
	show = {
		cmd = "show",
		func = MDB_ShowRootFrame,
		description = "Shows the main window."
	},
	hide = {
		cmd = "hide",
		func = MDB_HideRootFrame,
		description = "Hides the main window."
	},
}

function MDB_SlashCmd(msg)
	if not msg or msg == "" then
		msg = "show"
	end

	args = {} 
	idx = 0
	for arg in string.gmatch(msg, "([^".." ".."]+)") do
		args[idx] = arg
		idx = idx + 1
	end

	if slash_cmds[args[0]] ~= nil then
		slash_cmds[args[0]].func(args)
	end
end

SLASH_MDB1 = "/mdb"
SLASH_MDB2 = "/bookie"
SlashCmdList["MDB"] = MDB_SlashCmd
