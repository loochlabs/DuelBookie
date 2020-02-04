--ClientBets.lua
--Author: Looch
--Desciption: Client listener for recieving bets from broadcasting Bookies.

local _,addon = ...
local ClientBets = addon:NewModule("ClientBets", "AceEvent-3.0")

ClientBets.activeBookie = nil
ClientBets.activeWager = 0
ClientBets.activeChoice = 0
ClientBets.status = addon.clientStatus.Inactive
ClientBets.bets = {}
ClientBets.tradeOpen = false

function ClientBets:OnEnable()
end

function ClientBets:OnDisable()
end

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
	}
	print("new bet: "..bet.bookie..","..bet.duelers[1]..","..bet.duelers[2]..","..bet.minbet..","..bet.maxbet..","..bet.rake)
	table.insert(self.bets, bet)

	addon:GUIRefresh()
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
	end

	if self.status == addon.clientStatus.Conclusion then
		addon:GUIRefresh_Lobby()
	end
end

function ClientBets:InitiateTrade()
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end

	target = UnitName("target")
	if target ~= self.activeBookie then addon:Debug("Not targeting your active bookie!"); return end

	--wait for money to be traded 
	addon:Debug("Trade opened with your bookie.")
	self.tradeOpen = true
	self.currentMoney = GetMoney()
	self.tradeAmount = 0
end

function ClientBets:SetTradeAmount()	
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end
	if not self.tradeOpen then addon:Debug("Client is not correctly open for trades."); return end

    self.tradeAmount = math.floor(GetPlayerTradeMoney()/10000)
end

function ClientBets:HandleTrade()
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end
	if not self.tradeOpen then addon:Debug("Client is not correctly open for trades."); return end

	addon:Debug("Client sending trade amount: "..addon:FormatMoney(self.tradeAmount*10000))
	msg = { addon.playerName, self.tradeAmount }
	addon:SendCommand("group", "send_client_trade", msg)
end

function ClientBets:FinalizeTrade()
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end
	self.tradeOpen = false
end

function ClientBets:ReceiveOdds(data)
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end

	bookie, pool1, pool2, total = unpack(data)

	if bookie ~= self.activeBookie then return end

	local poolOdds = { tonumber(pool1), tonumber(pool2) }--string.format("%.1f", pool1/lcd)
	local gcd = poolOdds[self.activeChoice]
	local factor = poolOdds[1] * poolOdds[2] / gcd
	self.payout = self.activeWager * (1+factor)

	addon:Debug("potential payout "..self.payout)
	addon:GUIRefresh_ClientWaiting()
end
