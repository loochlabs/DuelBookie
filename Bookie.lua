local AddonName,addon = ...
_G.Bookie = LibStub('AceAddon-3.0'):NewAddon(addon, AddonName, "AceComm-3.0", "AceSerializer-3.0")

Bookie.playerName = nil
Bookie.debug = false
Bookie.autoAcceptTrades = false
Bookie.isBookie = false

Bookie.clientStatus = {
	Inactive = 1,
	WaitingForWager = 2,
	WaitingForTrade = 3,
	WaitingForResults = 4,
	WaitingForPayout = 5,
	ConclusionLost = 6,
	ConclusionPaid = 7,
}

Bookie.clientStatusShort = {
	"DONE",
	"PENDING",
	"NEEDS TO TRADE",
	"WAGERED",
	"NEEDS",
	"LOST",
	"WAS PAID",
}

Bookie.betStatus = {
	Open = 0,
	BetsClosed = 1,
	PendingPayout = 2,
	Complete = 3,
	Cancelled = 4,
}


function Bookie:OnInitialize()
	self.playerName = UnitName("player")
	self:RegisterComm("Bookie")
	self:GUIInit()

	if addon.debug then 
		addon:GUI_ShowRootFrame() 
	else
		addon:GUI_HideRootFrame()
	end
end


event_handlers = {
	TRADE_SHOW = {
		handler = function(...) 
			if addon.isBookie then
				addon.BookieBets:InitiateTrade()
			else
				addon.ClientBets:InitiateTrade()
			end
		end,
	},
	TRADE_ACCEPT_UPDATE = {
		handler = function(...) 
			local args = { ... }
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
		end,
	},
	PLAYER_TRADE_MONEY = {
		handler = function(...) 
			if addon.isBookie then
				addon.BookieBets:HandleTrade()	
			else
				addon.ClientBets:HandleTrade()	
			end
		end,
	},
	TRADE_CLOSED = {
		handler = function(...) 
			if addon.isBookie then
				addon.BookieBets:FinalizeTrade()	
			else
				addon.ClientBets:FinalizeTrade()	
			end
		end,
	},
	GROUP_JOINED = {
		handler = function(...) 
			if not addon.isBookie and not addon.ClientBets.activeBet then
				addon.ClientBets:GetAvailableBets()	
			end
		end,
	},
}


function Bookie_OnLoad(self)
	for event,_ in pairs(event_handlers) do
		self:RegisterEvent(event)
	end
end

function Bookie_OnEvent(self, event, ...)
	local eventHandler = event_handlers[event]
	if eventHandler then
		eventHandler.handler(...)
	end
end

comm_msgs = {
	new_bet = {
		callback = function(data) ClientBets:GetAvailableBets() end
	}, 
	get_available_bets = {
		callback = function(data) BookieBets:SendAvailableBet(data) end
	},
	get_active_bet = {
		callback = function(data) BookieBets:SendActiveBet(data) end
	},
	send_available_bet = {
		callback = function(data) ClientBets:ReceiveAvailableBet(data) end
	},
	join_bet = {
		callback = function(data) BookieBets:ReceiveClientJoin(data) end
	},
	quit_bet = {
		callback = function(data) BookieBets:ReceiveClientQuit(data) end
	},
	send_choice = {
		callback = function(data) BookieBets:ReceiveChoice(data) end
	},
	update_client_status = {
		callback = function(data) ClientBets:ReceiveUpdate(data) end
	}, 
	send_client_trade = {
		callback = function(data) BookieBets:ReceieveClientTrade(data) end
	},
	--send_payout = {
	--	callback = function(data) ClientBets:ReceivePayout(data) end
	--},
	cancel_bet = {
		callback = function(data) ClientBets:ReceiveCancelledBet(data) end
	},
	broadcast_bet_close = {
		callback = function(data) ClientBets:ReceiveBetClosed(data) end
	},
}

--- Send a Bookie Comm Message using AceComm-3.0
-- See Bookie:OnCommReceived() on how to receive these messages.
-- @param target The receiver of the message. Can be "group", "guild" or "playerName".
-- @param command The command to send.
-- @param ... Any number of arguments to send along. Will be packaged as a table.
function Bookie:SendCommand(command, data)
	local toSend = self:Serialize(command, data)

	if IsInRaid() then 
		self:SendCommMessage("Bookie", toSend, "RAID")
	elseif IsInGroup() then 
		self:SendCommMessage("Bookie", toSend, "PARTY")
	elseif IsInGuild() then
		self:SendCommMessage("Bookie", toSend, "GUILD")
	else
		addon:Debug("No comm methods are available.")
	end
end

--- Receives Bookie commands.
-- Params are delivered by AceComm-3.0, but we need to extract our data created with the
-- Bookie:SendCommand function.
-- @usage
-- --To extract the original data using AceSerializer-3.0:
-- local success, command, data = self:Deserialize(serializedMsg)
-- --'data' is a table containing the varargs delivered to Bookie:SendCommand().
function Bookie:OnCommReceived(prefix, serializedMsg, distri, sender)
	if prefix ~= "Bookie" then
		addon:Debug("Error: Invalid comm prefix.")
		return
	end

	-- data is always a table to be unpacked
	local test, command, data = self:Deserialize(serializedMsg)

	if not test then self:Debug("Error with com received!"); return end
	if not comm_msgs[command] then self:Debug("Invalid command message"); return end

	comm_msgs[command].callback(data)
end

function Bookie:Debug(msg, ...)
	if self.debug then print(msg) end
end

function Bookie:FormatMoney(money)
	if not string.match(money, "%d") then return money end
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

function Bookie:GetClientStatusText(status)
	for k,v in pairs(self.clientStatus) do
		if v == status then return k end
	end
end

function Bookie:GetClientStatusTextShort(status)
	return self.clientStatusShort[status]
end

function Bookie:GetBetStatusText(status)
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
