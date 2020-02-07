--BookieBets.lua
--Author: Looch
--Description: Manager for creating and dispatching bets to listening bet clients. 

local _,addon = ...
local BookieBets = addon:NewModule("BookieBets", "AceEvent-3.0")
local Utils = addon:GetModule("Util")

addon.BookieBets = BookieBets
BookieBets.betStatus = addon.betStatus.Complete
BookieBets.betData = nil
BookieBets.bookiePool = 2 --2g put up for default pool

function BookieBets:OnEnable()
	addon:Debug("BookieBets active")
end

--Set parameters for a new bet. Establish this player is a the BOOKIE,
--Message all other clients of new bet.
--@param wager parameters
function BookieBets:CreateBet(dueler1, dueler2, min, max, rake)
	addon:Debug("Creating bet")
	addon.isBookie = true

	bet = { 
		entrants = {},
		info = {
			duelers = { dueler1, dueler2 },
			minBet = min,
			maxBet = max,
			rake = rake,
			bookie = addon.playerName,
			open = true,
		},
		pool = { 0,0 },--self.bookiePool/2, self.bookiePool/2 },
	}
	self.betData = bet
	self.betStatus = addon.betStatus.Open

	--Send message to listening clients that a new bet is available.
	msg = { addon.playerName, dueler1, dueler2, min, max, rake }
 	addon:SendCommand("group", "new_bet", msg)
end

function BookieBets:SendAvailableBet(data) 
	if not addon.isBookie then addon:Debug("You are the client, skipping bookie junk"); return end
	if not self.betData or self.betStatus == addon.betStatus.Complete then return end

	clientName = unpack(data)
	addon:Debug("refresh request from.. "..clientName)

	--duelers, minbet, maxbet, rake, bookie = unpack(self.betData.info)
	dueler1, dueler2 = unpack(self.betData.info.duelers)
	minbet = self.betData.info.minBet
	maxbet = self.betData.info.maxBet
	rake = self.betData.info.rake
	bookie = self.betData.info.bookie
	open = self.betData.info.open

	msg = { addon.playerName, dueler1, dueler2, minbet, maxbet, rake, open, clientName }
 	addon:SendCommand("group", "refresh_bets", msg)
end

--Wager data received on bookie from client.
--@param string client = client player name
--@param int wager = ammount wagered by player, to be traded to the bookie
--@param int choice = { 1, 2 } -> Represents dueler1 or dueler2  
function BookieBets:ReceiveWager(data)
	if not addon.isBookie then addon:Debug("You are the client, skipping bookie junk"); return end

	client, choice = unpack(data)
	addon:Debug("Received wager from " .. client..","..choice)

	if not self.betData then addon:Debug("Error! bookie was not initialized correctly."); return end

	entrantInfo = {
		wager = 0,
		status = addon.clientStatus.WaitingForTrade,
		choice = choice,
		payout = 0,
		payoutReceived = 0,
	}

	self.betData.entrants[client] = entrantInfo

	msg = { addon.playerName, entrantInfo.status, client, 0 }
	addon:SendCommand("group", "update_client_status", msg)

	addon:GUIRefresh_BookieStatus()
end

function BookieBets:ReceieveClientTrade(data)
	if not addon.isBookie then addon:Debug("You are the client, skipping bookie junk"); return end
	if not addon.betStatus.Open then addon:Debug("Bookie is not open for bet trades"); return end

	clientName, clientTrade = unpack(data)
	client = self.betData.entrants[clientName]

	addon:Debug("Received a trade from our client: "..clientName)

	client.wager = clientTrade 
	client.status = addon.clientStatus.WaitingForResults
	self.betData.pool[client.choice] = self.betData.pool[client.choice] + client.wager

	msg = { addon.playerName, client.status, clientName, client.wager }
	addon:SendCommand("group", "update_client_status", msg)

	addon:GUIRefresh_BookieStatus()
end

function BookieBets:InitiateTrade()
	if not addon.isBookie then addon:Debug("You are the client, skipping bookie junk"); return end

	target = UnitName("target")
	if not self.betData.entrants[target] then addon:Debug("Not targeting one of your clients!"); return end
	if self.betData.entrants[target].status ~= addon.clientStatus.WaitingForPayout then addon:Debug("TRADE: Client status incorrect!"); return end

	--wait for money to be traded 
	addon:Debug("Trade opened with your client.")
	self.tradeOpen = true
	self.tradeAmount = 0
	self.tradeTarget = target
end

function BookieBets:SetTradeAmount()	
	if not addon.isBookie then addon:Debug("You are the client, skipping bookie junk"); return end
	if not self.tradeOpen then addon:Debug("Bookie is not correctly open for trades."); return end

    self.tradeAmount = GetPlayerTradeMoney()
end

function BookieBets:HandleTrade()
	if not addon.isBookie then addon:Debug("You are the client, skipping bookie junk"); return end
	if not self.tradeOpen then addon:Debug("Client is not correctly open for trades."); return end

	addon:Debug("Bookie sending trade amount: "..addon:FormatMoney(self.tradeAmount))

	client = self.betData.entrants[self.tradeTarget]

	if not client then addon:Debug("Client not found for this bookie!"); return end

	client.payoutReceived = self.tradeAmount + client.payoutReceived
	if client.payoutReceived >=client.payout then
		addon:Debug("Traded the correct payout to the client")
		client.status = addon.clientStatus.ConclusionPaid
	end

	msg = { addon.playerName, client.status, target, 0 }
	addon:SendCommand("group", "update_client_status", msg)

	addon:GUIRefresh_BookieStatus()
end

function BookieBets:FinalizeTrade()
	if addon.isBookie then addon:Debug("You are the bookie, skipping client junk"); return end
	self.tradeOpen = false
end


--Close the incoming bets. Calculate our final odds and broadcast to clients.
function BookieBets:FinalizeWagers()
	odds = self:CalculateOdds()

	msg = { addon.playerName, odds[1], odds[2], self.betData.info.rake }
	addon:SendCommand("group", "send_odds", msg)

	--add 1g if a prize pool is empty
	self.betData.pool[1] = max(10000, self.betData.pool[1])
	self.betData.pool[2] = max(10000, self.betData.pool[2])
	
	self.betStatus = addon.betStatus.BetsClosed
	self.betData.info.open = false 
	
	--update entrants' payouts
	for name, info in pairs(self.betData.entrants) do
		if info.choice == 1 then
			num = odds[2]
			denom = odds[1]
		else
			num = odds[1]
			denom = odds[2]
		end

		local scaledWager = info.wager * (1-self.betData.info.rake)
		info.payout = scaledWager* (1 + (num/denom))
	end

	addon:GUIRefresh_BookieStatus()
end

function BookieBets:CalculateOdds()
	local rake = 1 - self.betData.info.rake
	local pool1 = self.betData.pool[1] * rake
	local pool2 = self.betData.pool[2] * rake
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
	if not addon.isBookie then addon:Debug("You are the client, skipping bookie junk"); return end

	addon:Debug("Winner has been decided: "..self.betData.info.duelers[choice])

	for name, data in pairs(self.betData.entrants) do
		if data.status == addon.clientStatus.WaitingForResults then
			local playerPayout = data.choice == choice
			if playerPayout then
				data.status = addon.clientStatus.WaitingForPayout
			else
				data.status = addon.clientStatus.ConclusionLost 
			end

			--TODO do a batch message for all entrants?
			msg = { addon.playerName, data.status, name, 0 }
			addon:SendCommand("group", "update_client_status", msg)
		end
	end

	self.betStatus = addon.betStatus.PendingPayout
	addon:GUIRefresh_BookieStatus()
end

function BookieBets:AllEntrantsPaid()
	allpaid = true

	for name, info in pairs(self.betData.entrants) do
		allpaid = info.status == addon.clientStatus.ConclusionPaid or info.status == addon.clientStatus.ConclusionLost 

		if not allpaid then break end
	end

	return allpaid
end

function BookieBets:EndCurrentBet()
	self.betData = nil
	self.betStatus = addon.betStatus.Complete
	addon.isBookie = false
	addon:GUIRefresh_Lobby()
end

function BookieBets:CancelBet()
	self:EndCurrentBet()

	--alert client
	msg = { addon.playerName }
	addon:SendCommand("group", "cancel_bet", msg)
end

function BookieBets:GetEntrantsCount()
	local count = 0
	for _ in pairs(self.betData.entrants) do count = count + 1 end
	return count
end