--ClientBets.lua
--Author: Looch
--Desciption: Client listener for recieving bets from broadcasting Bookies.

local _,addon = ...
local ClientBets = addon:NewModule("ClientBets", "AceEvent-3.0")

ClientBets.availableBets = {}
ClientBets.activeBet = nil
ClientBets.tradeOpen = false

function ClientBets:ReceiveUpdate(data)
	if addon.isBookie then return end

	bookie, client, bet = unpack(data)

	if client ~= addon.playerName then return end
	if not bet.entrants[client] then addon:Debug("Error! Client does not exist in bookie's active bet"); return end

	self.activeBet = bet

	if bet.entrants[client].status == addon.clientStatus.WaitingForWager then
		addon:Debug("Successfully joined bookie session.")
		addon:GUIRefresh_ClientJoined()
	elseif bet.entrants[client].status == addon.clientStatus.WaitingForTrade then
		addon:Debug("Bookie received your wager, waiting for your trade.")
		addon:GUIRefresh_ClientWaiting()
	elseif bet.entrants[client].status == addon.clientStatus.WaitingForResults then
		addon:Debug("Bookie received your bet, waiting for results.")
		addon:GUIRefresh_ClientWaiting()
	elseif bet.entrants[client].status == addon.clientStatus.WaitingForPayout then
		addon:Debug("Bookie decided winer, waiting for payouts.")
		addon:GUIRefresh_ClientWaiting()
	elseif bet.entrants[client].status == addon.clientStatus.ConclusionPaid then
		addon:Debug("Received payouts.")
		addon:GUIRefresh_ClientWaiting()
	elseif bet.entrants[client].status == addon.clientStatus.ConclusionLost then
		addon:Debug("Client LOST this bet.")
		addon:GUIRefresh_ClientWaiting()
	elseif bet.entrants[client].status == addon.clientStatus.Inactive then
		addon:Debug("Client purged. Returning to Lobby")
		addon:GUIRefresh_Lobby()
	end

end

function ClientBets:ReceiveAvailableBet(data)
	if addon.isBookie then return end

	bookie, clientName, dueler1, dueler2= unpack(data)

	if clientName ~= addon.playerName then return end
	addon:Debug("Received available bet from: "..bookie)

	bet = {
		bookie = bookie,
		duelers = { dueler1, dueler2 },
	}

	table.insert(self.availableBets, bet)

	if not self.activeBet then
		addon:GUIRefresh_Lobby()
	end
end

function ClientBets:GetActiveBet()
	if addon.isBookie then return end

	msg = { addon.playerName }
	addon:SendCommand("get_active_bet", msg)
end

function ClientBets:GetAvailableBets()
	if addon.isBookie then return end

	--Clear our current available bets, get a fresh update from all possible bookies
	self.availableBets = {}

	addon:Debug("player name "..addon.playerName)

	msg = { addon.playerName }
	addon:SendCommand("get_available_bets", msg)
end


function ClientBets:ReceiveBetClosed(data)
	if addon.isBookie then return end
	if self.activeBet then addon:Debug("Client bet is active, skipping purge"); return end

	self:GetAvailableBets()
	addon:GUIRefresh_Lobby()
end

function ClientBets:JoinBet(index)
	if addon.isBookie then return end

	bet = self.availableBets[index]
	if not bet then return end

	msg = { bet.bookie, addon.playerName }
	addon:SendCommand("join_bet", msg)
	addon:GUIRefresh_Lobby()
end

function ClientBets:QuitBet()
	if addon.isBookie then return end

	msg = { bet.bookie, addon.playerName }
	addon:SendCommand("quit_bet", msg)
	addon:GUIRefresh_Lobby()
end

--@param wager = gold amount
--@param int choice = { 1, 2 } -> Represents dueler1 or dueler2 
function ClientBets:SubmitWager(choice)
	if addon.isBookie then return end
	if not self.activeBet then addon:Debug("ERROR! Client does not have an active bet"); return end

	addon:Debug("Client sending wager submission")

	msg = { self.activeBet.bookie, addon.playerName, choice }
	addon:SendCommand("send_choice", msg)
end

function ClientBets:InitiateTrade()
	if addon.isBookie then return end

	target = UnitName("target")
	if target ~= self.activeBet.bookie then addon:Debug("Not targeting your active bookie!"); return end

	--wait for money to be traded 
	addon:Debug("Trade opened with your bookie.")
	self.tradeOpen = true
	self.tradeAmount = 0
end

function ClientBets:SetTradeAmount()	
	if addon.isBookie then return end
	if not self.tradeOpen then addon:Debug("Client is not correctly open for trades."); return end

    self.tradeAmount = GetPlayerTradeMoney()
end

function ClientBets:HandleTrade()
	if addon.isBookie then return end
	if not self.tradeOpen then addon:Debug("Client is not correctly open for trades."); return end
	if self.tradeAmount == 0 then addon:Debug("Client traded 0g."); return end

	addon:Debug("Client sending trade amount: "..addon:FormatMoney(self.tradeAmount))
	msg = { addon.playerName, self.tradeAmount }
	addon:SendCommand("send_client_trade", msg)
end

function ClientBets:FinalizeTrade()
	if addon.isBookie then return end
	self.tradeOpen = false
end

function ClientBets:ReceiveCancelledBet(data)
	if addon.isBookie then return end
	if not self.activeBet then return end

	bookie = unpack(data)

	if bookie ~= self.activeBet.bookie then return end

	addon:Debug("Bookie cancelled our bet. Returning to lobby.")
	self:GetAvailableBets()
	addon:GUIRefresh_Lobby()
end

function ClientBets:GetBookie()
	if not self.activeBet.bookie then return "TBD" end
	return self.activeBet.bookie
end

function ClientBets:GetActiveWager()
	if not self.activeBet.entrants[addon.playerName].wager then return "TBD" end
	return self.activeBet.entrants[addon.playerName].wager
end

function ClientBets:GetChoiceText()
	if not self.activeBet.entrants[addon.playerName].choice then return "TBD" end
	local choice = self.activeBet.entrants[addon.playerName].choice
	return self.activeBet.duelers[choice]
end

function ClientBets:GetPayout()
	if not self.activeBet.entrants[addon.playerName].payout then return "TBD" end
	return self.activeBet.entrants[addon.playerName].payout
end

