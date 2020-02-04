--BookieBets.lua
--Author: Looch
--Description: Manager for creating and dispatching bets to listening bet clients. 

local _,addon = ...
local BookieBets = addon:NewModule("BookieBets", "AceEvent-3.0")
local Utils = addon:GetModule("Util")

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
	addon.isBookie = true

	bet = { 
		entrants = {},
		info = {
			duelers = { dueler1, dueler2 },
			minBet = min,
			maxBet = max,
			rake = rake,
			bookie = addon.playerName
		},
		pool = { 0,0 },--self.bookiePool/2, self.bookiePool/2 },
		completed = false,
	}
	self.betData = bet
	self.betStatus = addon.betStatus.Open

	--Send message to listening clients that a new bet is available.
	msg = { addon.playerName, dueler1, dueler2, min, max, rake }
 	addon:SendCommand("group", "new_bet", msg)
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
		--tradeAmount = 0,
	}

	self.betData.entrants[client] = entrantInfo

	msg = { addon.playerName, entrantInfo.status, client, 0 }
	addon:SendCommand("group", "update_client_status", msg)

	addon:GUIRefresh_BookieStatus()
end

function BookieBets:ReceieveClientTrade(data)
	if not addon.isBookie then addon:Debug("You are the client, skipping bookie junk"); return end

	clientName, clientTrade = unpack(data)
	client = self.betData.entrants[clientName]
	client.wager = clientTrade --TODO have to keep track of bookie trading to client. this only goes from client to bookie
	--if tonumber(client.tradeAmount) ~= tonumber(client.wager) then
	--	addon:Debug("Not enough gold received from client! amount:"..tostring(client.tradeAmount)..",wager:"..tostring(client.wager))
	--else
	--addon:Debug("Received correct gold from: "..clientName)
	addon:Debug("Received a trade from our client: "..clientName)

	client.status = addon.clientStatus.WaitingForResults
	self.betData.pool[client.choice] = self.betData.pool[client.choice] + client.wager

	msg = { addon.playerName, client.status, clientName, client.wager }
	addon:SendCommand("group", "update_client_status", msg)

	addon:GUIRefresh_BookieStatus()
	--end
end

--Close the incoming bets. Calculate our final odds and broadcast to clients.
function BookieBets:FinalizeWagers()
	if BookieBets.betData.pool[1] == 0 then
		BookieBets.betData.pool[1] = 1
	end
	if BookieBets.betData.pool[2] == 0 then
		BookieBets.betData.pool[2] = 1
	end

	local pool1 = BookieBets.betData.pool[1] 
	local pool2 = BookieBets.betData.pool[2]
	local totalPool = pool1 + pool2

	msg = { addon.playerName, pool1, pool2, totalPool }
	addon:SendCommand("group", "send_odds", msg)

	self.betStatus = addon.betStatus.BetsClosed
end

function BookieBets:CalculateOdds()
	local totalPool = self.betData.pool[1] + self.betData.pool[2]
	local pool1 = max(self.betData.pool[1],1) 
	local pool2 = max(self.betData.pool[2],1)
	local lcd = min(pool1, pool2)
	return { pool1/lcd, pool2/lcd }
end

--Bookie has selected a winner. 
--@param int choice = { 1, 2 } -> Represents dueler1 or dueler2  
function BookieBets:FinalizeDuelWinner(choice)
	if not addon.isBookie then addon:Debug("You are the client, skipping bookie junk"); return end

	addon:Debug("Winner has been decided: "..self.betData.info.duelers[choice])
	self.betData.completed = true 

	for name, data in pairs(self.betData.entrants) do
		if data.status == addon.clientStatus.WaitingForResults then
			local playerPayout = data.choice == choice
			if playerPayout then
				data.status = addon.clientStatus.WaitingForPayout
			else
				data.status = addon.clientStatus.Conclusion 
			end

			--TODO do a batch message for all entrants?
			msg = { addon.playerName, data.status, name, 0 }
			addon:SendCommand("group", "update_client_status", msg)
		end
	end

	self.betStatus = addon.betStatus.PendingPayout
	addon:GUIRefresh_BookieStatus()
end
