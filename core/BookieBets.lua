--BookieBets.lua
--Author: Looch
--Description: Manager for creating and dispatching bets to listening bet clients. 

local _,addon = ...
BookieBets = BookieSave.Bookie.BookieBets or addon:NewModule("BookieBets", "AceEvent-3.0")

function BookieBets:Save()
	BookieSave.Bookie.isBookie = addon.isBookie
	BookieSave.Bookie.BookieBets.bet = self.bet
end

function BookieBets:UpdateClients()
	if not addon.isBookie then return end
	
	for client,_ in pairs(self.bet.entrants) do
		self:UpdateClient(client)
	end
end

function BookieBets:UpdateClient(client)
	local bet = self.bet

	msg = { addon.playerName, client, bet }
	addon:SendCommand("update_client_status", msg)

	self:Save()
end

--Set parameters for a new bet. Establish this player is a the BOOKIE,
--Message all other clients of new bet.
--@param wager parameters
function BookieBets:CreateBet(dueler1, dueler2, min, max, rake)
	addon:Debug("Creating bet")
	addon.isBookie = true

	self.bet = { 
		entrants = {},
		duelers = { dueler1, dueler2 },
		minBet = min,
		maxBet = max,
		rake = rake,
		bookie = addon.playerName,
		pool = { 0,0 },
		status = addon.betStatus.Open,
	}

	--Send message to listening clients that a new bet is available.
	msg = {}
 	addon:SendCommand("new_bet", msg)

 	self:Save()
end

function BookieBets:SendAvailableBet(data) 
	if not addon.isBookie then return end
	if not self.bet or self.bet.status ~= addon.betStatus.Open then return end

	client = unpack(data)
	addon:Debug("refresh request from.. "..client)

	dueler1, dueler2 = unpack(self.bet.duelers)
 	msg = { addon.playerName, client, dueler1, dueler2}
 	addon:SendCommand("send_available_bet", msg)
end

function BookieBets:SendActiveBet(data)
	if not addon.isBookie then return end

	client = unpack(data)
	self:UpdateClient(client)
end

function BookieBets:ReceiveClientJoin(data)
	if not addon.isBookie then return end

	bookie, client = unpack(data)

	if bookie ~= addon.playerName then return end
	if not self.bet then addon:Debug("Error! bookie was not initialized correctly."); return end
	
	entrant = {
		status = addon.clientStatus.WaitingForWager,
		payout = "TBD",
		payoutReceived = 0,
	}

	self.bet.entrants[client] = entrant
	self:UpdateClient(client)

	addon:GUIRefresh_BookieStatus()
end

function BookieBets:ReceiveClientQuit(data)
	if not addon.isBookie then return end

	bookie, client = unpack(data)

	if bookie ~= addon.playerName then return end
	if not self.bet then addon:Debug("Error! bookie was not initialized correctly."); return end
	
	self.bet.entrants[client] = nil
	self:UpdateClient(client)

	addon:GUIRefresh_BookieStatus()
end

--Wager data received on bookie from client.
--@param string client = client player name
--@param int wager = ammount wagered by player, to be traded to the bookie
--@param int choice = { 1, 2 } -> Represents dueler1 or dueler2  
function BookieBets:ReceiveChoice(data)
	if not addon.isBookie then return end

	bookie, client, choice = unpack(data)
	addon:Debug("Received choice from " .. client..","..choice)

	if bookie ~= addon.playerName then addon:Debug("Bookie: Receieved wager but not the client's bookie."); return end
	if not self.bet then addon:Debug("Error! bookie was not initialized correctly."); return end
	if not self.bet.entrants[client] then addon:Debug("Error! Client does not exist as entrant."); return end

	entrant = self.bet.entrants[client]
	entrant.wager = 0
	entrant.status = addon.clientStatus.WaitingForTrade
	entrant.choice = choice

	self:UpdateClient(client)

	addon:GUIRefresh_BookieStatus()
end

function BookieBets:ReceieveClientTrade(data)
	if not addon.isBookie then return end
	if self.bet.status ~= addon.betStatus.Open then addon:Debug("Bookie is not open for bet trades"); return end

	clientName, clientTrade = unpack(data)
	addon:Debug("Received a trade from our client: "..clientName)

	entrant = self.bet.entrants[clientName]
	if entrant.status ~= addon.clientStatus.WaitingForTrade then addon:Debug("Client already paid: "..clientName); return end 

	entrant.wager = clientTrade 
	entrant.status = addon.clientStatus.WaitingForResults
	self.bet.pool[entrant.choice] = self.bet.pool[entrant.choice] + entrant.wager

	self:UpdateClient(clientName)
	addon:GUIRefresh_BookieStatus()
end

function BookieBets:ReceieveClientPayoutConfirm(data)
	if not addon.isBookie then return end
	if self.bet.status ~= addon.betStatus.PendingPayout then addon:Debug("Bookie is not ready for payouts"); return end

	local clientName, payout = unpack(data)
	local client = self.bet.entrants[clientName]

	if client.status ~= addon.clientStatus.WaitingForPayout then addon:Debug("Client already paid: "..clientName); return end 

	client.payoutReceived = payout + client.payoutReceived
	if client.payoutReceived >= client.payout then
		addon:Debug("Traded the correct payout to the client: "..clientName)
		client.status = addon.clientStatus.ConclusionPaid
	end

	self:UpdateClient(clientName)
	addon:GUIRefresh_BookieStatus()
end

function BookieBets:InitiateTrade()
	if not addon.isBookie then return end
	if not self.bet then return end

	target = UnitName("target")
	if not self.bet.entrants[target] then addon:Debug("Not targeting one of your clients!"); return end

	addon:Debug("Trade opened with your client.")
	self.tradeOpen = true
	self.tradeAmount = 0
	self.tradeTarget = target
end

function BookieBets:SetTradeAmount()	
	if not addon.isBookie then return end
	if not self.tradeOpen then addon:Debug("Bookie is not correctly open for trades."); return end

	local status = self.bet.entrants[self.tradeTarget].status
	if status == addon.clientStatus.WaitingForTrade then
    	self.tradeAmount = GetTargetTradeMoney()
    elseif status == addon.clientStatus.WaitingForPayout then
    	self.tradeAmount = GetPlayerTradeMoney()
    else
    	addon:Debug("Bookie is not correctly open for trades.");
    	self.tradeOpen = false
    	self.tradeTarget = nil
    end
end

function BookieBets:HandleTrade()
	if not addon.isBookie then return end
	if not self.tradeOpen then addon:Debug("Bookie is not correctly open for trades."); return end
	if not self.tradeAmount or self.tradeAmount == 0 then return end

	addon:Debug("Bookie trade amount: "..addon:FormatMoney(self.tradeAmount))

	local client = self.bet.entrants[self.tradeTarget]
	if not client then addon:Debug("Client not found for this bookie!"); return end

	local status = client.status
	if status == addon.clientStatus.WaitingForTrade then
		self:ReceieveClientTrade( {self.tradeTarget, self.tradeAmount} )

    elseif status == addon.clientStatus.WaitingForPayout then
    	self:ReceieveClientPayoutConfirm( {self.tradeTarget, self.tradeAmount} )
    else
    	addon:Debug("Bookie is not correctly open for trades.");
    	self.tradeOpen = false
    end

	addon:GUIRefresh_BookieStatus()
end

function BookieBets:FinalizeTrade()
	if not addon.isBookie then return end
	self.tradeOpen = false
end

function BookieBets:RemoveEntrants(status)
	local found = false
	local entrants = self.bet.entrants
	for name,info in pairs(entrants) do
		if status == info.status then
			addon:Debug("Bookie purging "..name)
			info.status = addon.clientStatus.Inactive
			self:UpdateClient(name)
			entrants[name] = nil
		end
	end
end

--Close the incoming bets. Calculate our final odds and broadcast to clients.
function BookieBets:CloseBets()
	if not addon.isBookie then return end

	--purge clients who have not paid
	self:RemoveEntrants(addon.clientStatus.WaitingForWager)
	self:RemoveEntrants(addon.clientStatus.WaitingForTrade)

	odds = self:CalculateOdds()

	--add 1g if a prize pool is empty
	self.bet.pool[1] = max(10000, self.bet.pool[1])
	self.bet.pool[2] = max(10000, self.bet.pool[2])
	self.bet.status = addon.betStatus.BetsClosed
	
	--update entrants' payouts
	for name, info in pairs(self.bet.entrants) do
		if info.choice == 1 then
			num = odds[2]
			denom = odds[1]
		else
			num = odds[1]
			denom = odds[2]
		end

		local scaledWager = info.wager * (1-self.bet.rake)
		info.payout = scaledWager* (1 + (num/denom))

		self:UpdateClient(name)
	end

	--broadcast bet close to ALL lobbied players
	msg = { addon.playerName }
	addon:SendCommand("broadcast_bet_close", msg)

	addon:GUIRefresh_BookieStatus()
end

function BookieBets:CalculateOdds()
	local rake = 1 - self.bet.rake
	local pool1 = self.bet.pool[1] * rake
	local pool2 = self.bet.pool[2] * rake
	local totalPool = pool1 + pool2
	local bookiePool = floor(10000 * rake)
	pool1 = max(pool1,bookiePool) 
	pool2 = max(pool2,bookiePool)
	local lcd = min(pool1, pool2)
	return { pool1/lcd, pool2/lcd }
end

--Bookie has selected a winner. 
--@param int choice = { 1, 2 } -> Represents dueler1 or dueler2  
function BookieBets:FinalizeDuelWinner(choice)
	if not addon.isBookie then return end

	addon:Debug("Winner has been decided: "..self.bet.duelers[choice])

	for name, info in pairs(self.bet.entrants) do
		if info.status == addon.clientStatus.WaitingForResults then
			local playerPayout = info.choice == choice
			if playerPayout then
				info.status = addon.clientStatus.WaitingForPayout
			else
				info.status = addon.clientStatus.ConclusionLost 
			end
			self:UpdateClient(name)

		elseif info.status == addon.clientStatus.ConclusionLost then
			self:RemoveEntrants(addon.clientStatus.ConclusionLost)
		end
	end

	self.bet.status = addon.betStatus.PendingPayout
	self:Save()
	addon:GUIRefresh_BookieStatus()
end

function BookieBets:AllEntrantsPaid()
	allpaid = true

	for name, info in pairs(self.bet.entrants) do
		allpaid = info.status ~= addon.clientStatus.WaitingForPayout
		if not allpaid then break end
	end

	return allpaid
end

function BookieBets:EndCurrentBet()
	self.bet = nil
	addon.isBookie = false
	self:Save()
	addon:GUIRefresh_Lobby()
end

function BookieBets:CancelBet()
	--alert client
	msg = { addon.playerName }
	addon:SendCommand("cancel_bet", msg)
	addon:SendCommand("broadcast_bet_close", msg)

	self:EndCurrentBet()
end

function BookieBets:GetEntrantsCount()
	local count = 0
	for _ in pairs(self.bet.entrants) do count = count + 1 end
	return count
end

function BookieBets:GetPrizePoolRaw()
	return (self.bet.pool[1] + self.bet.pool[2]) 
end

function BookieBets:GetPrizePoolRaked()
	return self:GetPrizePoolRaw() * (1-self.bet.rake)
end

function BookieBets:GetRakeTotal()
	return self:GetPrizePoolRaw() * self.bet.rake
end