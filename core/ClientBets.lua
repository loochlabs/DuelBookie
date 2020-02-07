--ClientBets.lua
--Author: Looch
--Desciption: Client listener for recieving bets from broadcasting Bookies.

local _,addon = ...
local ClientBets = addon:NewModule("ClientBets", "AceEvent-3.0")

addon.ClientBets = ClientBets
ClientBets.activeBookie = nil
ClientBets.activeWager = 0
ClientBets.activeChoice = 0
ClientBets.status = addon.clientStatus.Inactive
ClientBets.availableBets = {}
ClientBets.tradeOpen = false

function ClientBets:ReceiveNewBet(data)
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end

	--Store new bet in db, refresh MyBets tab with new bet
	addon:Debug("Client received new bet: ")
	bet = {
		bookie = data[1],
		duelers = { data[2], data[3] },
		minbet = data[4],
		maxbet = data[5],
		rake = data[6],
		open = data[7],
	}
	
	table.insert(self.availableBets, bet)

	--Only refresh if we are in the lobby
	if ClientBets.status == addon.clientStatus.Inactive then
		addon:GUIRefresh_Lobby()
	end
end

function ClientBets:RefreshBets(data)
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end

	bookie, dueler1, dueler2, minbet, maxbet, rake, open, clientName = unpack(data)

	if clientName ~= addon.playerName then return end

	self:ReceiveNewBet({bookie, dueler1, dueler2, minbet, maxbet, rake, open})
end

function ClientBets:RefreshAvailableBets()
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end

	--Clear our current available bets, get a fresh update from all possible bookies
	self.availableBets = {}

	msg = { addon.playerName }
	addon:SendCommand("group", "get_available_bets", msg)
end

--@param wager = gold amount
--@param int choice = { 1, 2 } -> Represents dueler1 or dueler2 
function ClientBets:SendWager(choice)
	addon:Debug("Client sending wager submission")

	self.activeChoice = choice

	msg = { addon.playerName, choice }
	addon:SendCommand("group", "send_wager", msg)
end

function ClientBets:UpdateStatus(data)
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end

	addon:Debug("Client received new status: " .. data[2].. " from Bookie: "..data[1])
	self.activeBookie, self.status, sender, self.activeWager = unpack(data)

	if sender ~= addon.playerName then return end

	if self.status == addon.clientStatus.WaitingForTrade then
		addon:Debug("Bookie received your wager, waiting for your trade.")
		addon:GUIRefresh_ClientWaiting()
	elseif self.status == addon.clientStatus.WaitingForResults then
		addon:Debug("Bookie received your bet, waiting for results.")
		addon:GUIRefresh_ClientWaiting()
	elseif self.status == addon.clientStatus.WaitingForPayout then
		addon:Debug("Bookie decided winer, waiting for payouts.")
		addon:GUIRefresh_ClientWaiting()
	elseif self.status == addon.clientStatus.ConclusionPaid then
		addon:Debug("Received payouts.")
		addon:GUIRefresh_ClientWaiting()
	elseif self.status == addon.clientStatus.ConclusionLost then
		addon:Debug("Client LOST this bet.")
		addon:GUIRefresh_ClientWaiting()
	end
end

function ClientBets:InitiateTrade()
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end

	target = UnitName("target")
	if target ~= self.activeBookie then addon:Debug("Not targeting your active bookie!"); return end

	--wait for money to be traded 
	addon:Debug("Trade opened with your bookie.")
	self.tradeOpen = true
	self.tradeAmount = 0
end

function ClientBets:SetTradeAmount()	
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end
	if not self.tradeOpen then addon:Debug("Client is not correctly open for trades."); return end

    self.tradeAmount = GetPlayerTradeMoney()
end

function ClientBets:HandleTrade()
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end
	if not self.tradeOpen then addon:Debug("Client is not correctly open for trades."); return end
	if self.tradeAmount == 0 then addon:Debug("Client is not correctly open for trades."); return end

	addon:Debug("Client sending trade amount: "..addon:FormatMoney(self.tradeAmount))
	msg = { addon.playerName, self.tradeAmount }
	addon:SendCommand("group", "send_client_trade", msg)
end

function ClientBets:FinalizeTrade()
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end
	self.tradeOpen = false
end

function ClientBets:ReceiveOdds(data)
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end

	bookie, odds1, odds2, rake = unpack(data)

	if bookie ~= self.activeBookie then return end

	local odds = { tonumber(odds1), tonumber(odds2) }--string.format("%.1f", pool1/lcd)
	if self.activeChoice == 1 then
		num = odds[2]
		denom = odds[1]
	else
		num = odds[1]
		denom = odds[2]
	end
	--local factor = poolOdds[1] * poolOdds[2] / gcd
	self.activeWager = self.activeWager * (1-rake)
	self.payout = self.activeWager * (1 + (num/denom))

	addon:Debug("potential payout "..self.payout.." oods:"..num..","..denom)
	addon:GUIRefresh_ClientWaiting()
end

function ClientBets:CleanupCurrentBet()
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end

	ClientBets.status = addon.clientStatus.Inactive
	ClientBets:RefreshAvailableBets()
end

function ClientBets:ReceiveCancelledBet(data)
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end

	bookie = unpack(data)

	if bookie ~= self.activeBookie then return end

	addon:Debug("Bookie cancelled our bet. Returning to lobby.")
	self:CleanupCurrentBet()
	addon:GUIRefresh_Lobby()
end
