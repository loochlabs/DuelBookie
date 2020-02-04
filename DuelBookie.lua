local AddonName,addon = ...
_G.DuelBookie = LibStub('AceAddon-3.0'):NewAddon(addon, AddonName, "AceComm-3.0", "AceSerializer-3.0")

DuelBookie.playerName = UnitName("player")
DuelBookie.debug = true
DuelBookie.autoAcceptTrades = true

--Enums TODO: find cleaner way for client/bookie statuses
DuelBookie.clientStatus = {
	Inactive = 1,
	WaitingForWager = 2,
	WaitingForTrade = 3,
	WaitingForResults = 4,
	WaitingForPayout = 5,
	Conclusion = 6,
}

DuelBookie.clientStatusShort = {
	"DONE",
	"PENDING",
	"OWES",
	"PAID",
	"NEEDS",
	"DONE",
}

DuelBookie.betStatus = {
	Open = 0,
	BetsClosed = 1,
	PendingPayout = 2,
	Complete = 3,
}

DuelBookie.bookieStatus = {}
DuelBookie.activeTrade = {}

function DuelBookie:OnInitialize()
	self:Debug("MDB initialized")
	self:RegisterComm("DuelBookie")
	self:GUIInit()
end

function DuelBookie_OnLoad(self)
	addon:Debug("onload")

	self:RegisterEvent("TRADE_ACCEPT_UPDATE")
	self:RegisterEvent("PLAYER_TRADE_MONEY")
	self:RegisterEvent("TRADE_SHOW")
	self:RegisterEvent("TRADE_CLOSED")
	--self:RegisterEvent("TRADE_REQUEST")
	--self:RegisterEvent("PLAYER_MONEY")
	--self:RegisterEvent("TRADE_UPDATE")
end

function DuelBookie_OnEvent(self, event, ...)
	if event == "TRADE_SHOW" then
		addon.ClientBets:InitiateTrade()
	end

	if event == "TRADE_ACCEPT_UPDATE" then
		addon:Debug("trade accept")
		args = { ... }
		addon:Debug(args[1]..","..args[2])
		
		if addon.isBookie and addon.autoAcceptTrades and args[2] == 1 then
			AcceptTrade()
		end

		if not addon.isBookie and args[1] == 1 then
			addon.ClientBets:SetTradeAmount()	
		end
	end

	if event == "PLAYER_TRADE_MONEY" then
		addon:Debug("player trade money")
		addon.ClientBets:HandleTrade()
	end

	if event == "TRADE_CLOSED" then
		addon:Debug("player trade finalize")
		addon.ClientBets:FinalizeTrade()
	end


	--[[
	if event == "TRADE_REQUEST" then
		addon:Debug("trade req")
		args = { ... }
		addon:Debug(#args)
	end

	if event == "PLAYER_MONEY" then
		addon:Debug("PLAYER_MONEY")
		local msg = { ... }
		addon:Debug(#msg)
	end
	--]]


	--if event == "PLAYER_TRADE_MONEY" then
	--	addon:Debug("player trade money")
	--end


	--if event == "TRADE_UPDATE" then
	--	addon:Debug("UPDATE")
	--end

end


comm_msgs = {
	new_bet = {
		callback = function(data) ClientBets:ReceiveNewBet(data) end
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
    local gold = floor(money/10000);
    local silver = floor((money - (gold * 10000)) / 100);
    local copper = mod(money, 100);
    if gold > 0 then
        ret = gold .. "g "
    end
    if silver > 0 then
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


