--core 

local _,addon = ...
DuelBookie = addon
AceGUI = LibStub("AceGUI-3.0")
ClientBets = addon:GetModule("ClientBets")
addon.ClientBets = ClientBets
BookieBets = addon:GetModule("BookieBets")
addon.BookieBets = BookieBets
addon.isBookie = false

local frame = AceGUI:Create("Frame")
local tab = AceGUI:Create("TabGroup")
local activeTab = nil
local joinIndex = 0

activeTabGroups = {
	bookie_create = function() return GetTabBookieCreate() end,
	bookie_status = function() return GetTabBookieStatus() end,
	client_joined = function() return GetTabClientJoined() end,
	client_waiting = function() return GetTabClientWaiting() end,
}

local function ValidBetParams(dueler1, dueler2, minbet, maxbet, rake)
	validNames = UnitIsPlayer(dueler1) and UnitIsPlayer(dueler2) and dueler1 ~= dueler2
	return validNames and minbet and maxbet and rake and (tonumber(minbet) < tonumber(maxbet))
end

function SetActiveTab(key)
	addon:Debug("Getting active tab "..key)
	activeTab = activeTabGroups[key]()
end

function GetTabBookieCreate()
	returnGroup = AceGUI:Create("SimpleGroup")
	returnGroup:SetFullWidth(true)
	returnGroup:SetFullHeight(true)

	local header = AceGUI:Create("SimpleGroup")
	header:SetFullWidth(true)
	header:SetLayout("Flow")
	returnGroup:AddChild(header)
	local body = AceGUI:Create("SimpleGroup")
	body:SetFullWidth(true)
	body:SetLayout("List")
	returnGroup:AddChild(body)

	local headerLabel = AceGUI:Create("Label")
	headerLabel:SetText("Creating a New Bookie Session")
	header:AddChild(headerLabel)

	local dueler1Name, dueler2Name, rake
	local minbet = 1
	local maxbet = 1000
	local startButton

	if addon.debug then dueler1Name, dueler2Name = "Lootch", "Deulbookie" end

	rakeOptions = {
		rake0 = 0,
		rake5 = 0.05,
		rake10 = 0.1,
		rake20 = 0.25
	}
	rake = rakeOptions.rake0

	duelerContainer = AceGUI:Create("SimpleGroup")
	duelerContainer:SetFullWidth(true)
	duelerContainer:SetLayout("Flow")
	body:AddChild(duelerContainer)

	dueler1Editbox = AceGUI:Create("EditBox")
	dueler1Editbox:SetLabel("Dueler #1")
	dueler1Editbox:SetText(dueler1Name)
	dueler1Editbox:SetRelativeWidth(0.5)
	dueler1Editbox:SetMaxLetters(12)
	dueler1Editbox:DisableButton(true)
	dueler1Editbox:SetCallback("OnTextChanged", 
		function(widget, event, text) 
			dueler1Name = text 
			createBetStartButton:SetDisabled(not ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
		end)
	duelerContainer:AddChild(dueler1Editbox)

	dueler2Editbox = AceGUI:Create("EditBox")
	dueler2Editbox:SetLabel("Dueler #2")
	dueler2Editbox:SetText(dueler2Name)
	dueler2Editbox:SetRelativeWidth(0.5)
	dueler2Editbox:SetMaxLetters(12)
	dueler1Editbox:DisableButton(true)
	dueler2Editbox:SetCallback("OnTextChanged", 
		function(widget, event, text) 
			dueler2Name = text 
			createBetStartButton:SetDisabled(not ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
		end)
	duelerContainer:AddChild(dueler2Editbox)

	--TODO callback to verify user name is a real player, when value changed

	betsContainer = AceGUI:Create("SimpleGroup")
	betsContainer:SetFullWidth(true)
	betsContainer:SetLayout("Flow")
	body:AddChild(betsContainer)

	minbetEditbox = AceGUI:Create("EditBox")
	minbetEditbox:SetLabel("Minimum Bet (gold)")
	minbetEditbox:SetText(minbet)
	minbetEditbox:SetRelativeWidth(0.5)
	minbetEditbox:SetMaxLetters(4)
	minbetEditbox:DisableButton(true)
	minbetEditbox:SetCallback("OnTextChanged", 
		function(widget, event, text) 
			minbet = text 
			createBetStartButton:SetDisabled(not ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
		end)
	betsContainer:AddChild(minbetEditbox)

	maxbetEditbox = AceGUI:Create("EditBox")
	maxbetEditbox:SetLabel("Maximum Bet (gold)")
	maxbetEditbox:SetText(maxbet)
	maxbetEditbox:SetRelativeWidth(0.5)
	maxbetEditbox:SetMaxLetters(4)
	maxbetEditbox:DisableButton(true)
	maxbetEditbox:SetCallback("OnTextChanged", 
		function(widget, event, text) 
			maxbet = text 
			createBetStartButton:SetDisabled(not ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
		end)
	betsContainer:AddChild(maxbetEditbox)

	rakeContainer = AceGUI:Create("SimpleGroup")
	rakeContainer:SetFullWidth(true)
	rakeContainer:SetLayout("Flow")
	body:AddChild(rakeContainer)

	rakeDropdown = AceGUI:Create("Dropdown")
	rakeDropdown:SetLabel("Percentage of gold taken from prize pool:")
	rakeDropdown:SetFullWidth(true)
	rakeDropdown:SetList(rakeOptions)
	rakeDropdown:SetValue("rake0")
	rakeDropdown:SetCallback("OnValueChanged", 
		function(widget, event, key) 
			rake = rakeOptions[key] 
			createBetStartButton:SetDisabled(not ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
		end)
	rakeContainer:AddChild(rakeDropdown)

	footer = AceGUI:Create("SimpleGroup")
	footer:SetFullWidth(true)
	footer:SetLayout("Flow")
	body:AddChild(footer)

	createBetStartButton = AceGUI:Create("Button")
	createBetStartButton:SetText("Start")
	createBetStartButton:SetFullWidth(true)
	createBetStartButton:SetDisabled(not ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
	createBetStartButton:SetCallback("OnClick", 
		function() 
			BookieBets:CreateBet(dueler1Name, dueler2Name, minbet, maxbet, rake) 
			SetActiveTab("bookie_status")
			tab:SelectTab("tab2")
		end )
	footer:AddChild(createBetStartButton)

	return returnGroup
end

function GetTabBookieStatus()
	returnGroup = AceGUI:Create("SimpleGroup")
	local body = AceGUI:Create("SimpleGroup")
	body:SetFullWidth(true)
	body:SetFullHeight(true)
	body:SetLayout("List")
	returnGroup:AddChild(body)

	headerPanel = AceGUI:Create("SimpleGroup")
	headerPanel:SetLayout("List")
	headerPanel:SetFullWidth(true)
	body:AddChild(headerPanel)

	--headerLabel = AceGUI:Create("Label")
	--headerLabel:SetText("Active Bet Status")
	--header:AddChild(headerLabel)
	duelerLabel = AceGUI:Create("Label")
	duelerLabel:SetFullWidth(true)
	headerPanel:AddChild(duelerLabel)
	--TODO we have the same data in BookieBets and ClientBets here...
	duelerLabel:SetText(BookieBets.betData.info.duelers[1].." VS "..BookieBets.betData.info.duelers[2])
	

	--local pool1 = BookieBets.betData.pool[1] 
	--local pool2 = BookieBets.betData.pool[2]
	--local totalPool = pool1 + pool2
	--local lcd = min(pool1, pool2)
	--local pool1Odd = pool1/lcd
	--local pool2Odd = pool2/lcd
	totalPoolLabel = AceGUI:Create("Label")
	totalPoolLabel:SetText("Prize Pool: "..addon:FormatMoney((BookieBets.betData.pool[1]+BookieBets.betData.pool[2]) *10000))
	totalPoolLabel:SetFullWidth(true)
	headerPanel:AddChild(totalPoolLabel)

	odds = BookieBets:CalculateOdds()
	oddsLabel = AceGUI:Create("Label")
	headerPanel:AddChild(oddsLabel)
	oddsLabel:SetText("ODDS | "..odds[1]..":"..odds[2])
	
	--dueler1PoolLabel = AceGUI:Create("Label")
	--dueler1PoolLabel:SetText("Pool for "..BookieBets.betData.info.duelers[1]..": "..addon:FormatMoney(pool1*10000))
	--header:AddChild(dueler1PoolLabel)
	--dueler2PoolLabel = AceGUI:Create("Label")
	--dueler2PoolLabel:SetText("Pool for "..BookieBets.betData.info.duelers[2]..": "..addon:FormatMoney(pool2*10000))
	--header:AddChild(dueler2PoolLabel)

	--if BookieBets.betStatus >= addon.betStatus.BetsClosed then
	--	oddsLabel = AceGUI:Create("Label")
	--	oddsLabel:SetText("Odds ["..BookieBets.betData.info.duelers[1]..":"..BookieBets.betData.info.duelers[2]..
	--		"] - ["..pool1Odd..":"..pool2Odd.."]")
	--	header:AddChild(oddsLabel)
	--end

	horzSpacer = AceGUI:Create("Heading")
	horzSpacer:SetRelativeWidth(1)
	body:AddChild(horzSpacer)

	controlPanel = AceGUI:Create("SimpleGroup")
	body:AddChild(controlPanel)
	controlPanel:SetFullWidth(true)
	controlPanel:SetLayout("Flow")

	--local controlsLabel = AceGUI:Create("Label")
	--controlsLabel:SetText("Controls")
	--bottomButtonPanel:AddChild(controlsLabel)
	--controlsLabel:SetFullWidth(true)

	controlBetsPanel = AceGUI:Create("SimpleGroup")
	controlPanel:AddChild(controlBetsPanel)
	controlBetsPanel:SetLayout("List")
	controlBetsPanel:SetRelativeWidth(0.5)

	closeBetsButton = AceGUI:Create("Button")
	controlBetsPanel:AddChild(closeBetsButton)
	closeBetsButton:SetFullWidth(true)
	closeBetsButton:SetText("Close Bets")
	closeBetsButton:SetCallback("OnClick", 
		function() 
			closeBetsButton:SetDisabled(true)
			BookieBets:FinalizeWagers() 
		end)
	
	--horzline = AceGUI:Create("Heading")
	--horzline:SetRelativeWidth(1)
	--bottomButtonPanel:AddChild(horzline)

	controlDuelerPanel = AceGUI:Create("SimpleGroup")
	controlPanel:AddChild(controlDuelerPanel)
	controlDuelerPanel:SetLayout("List")
	controlDuelerPanel:SetRelativeWidth(0.5)

	local finalLabel = AceGUI:Create("Label")
	finalLabel:SetText("Choose Winner:")
	controlDuelerPanel:AddChild(finalLabel)
	finalLabel:SetFullWidth(true)
	finalizeDueler1Button = AceGUI:Create("Button")
	finalizeDueler1Button:SetText(BookieBets.betData.info.duelers[1])
	finalizeDueler1Button:SetFullWidth(true)
	finalizeDueler1Button:SetCallback("OnClick", function() BookieBets:FinalizeDuelWinner(1) end)
	controlDuelerPanel:AddChild(finalizeDueler1Button)
	finalizeDueler2Button = AceGUI:Create("Button")
	finalizeDueler2Button:SetFullWidth(true)
	finalizeDueler2Button:SetText(BookieBets.betData.info.duelers[2])
	finalizeDueler2Button:SetCallback("OnClick", function() BookieBets:FinalizeDuelWinner(2) end)
	controlDuelerPanel:AddChild(finalizeDueler2Button)


	bottomPanel = AceGUI:Create("SimpleGroup")
	body:AddChild(bottomPanel)
	bottomPanel:SetFullWidth(true)
	bottomPanel:SetLayout("Flow")

	leftContainer = AceGUI:Create("SimpleGroup")
	bottomPanel:AddChild(leftContainer)
	leftContainer:SetLayout("List")
	--leftContainer:SetRelativeWidth(0.6)

	leftLabel = AceGUI:Create("Label")
	leftContainer:AddChild(leftLabel)
	leftLabel:SetText("Entrants")
	leftLabel:SetFullWidth(true)

	horzlineLeft = AceGUI:Create("Heading")
	horzlineLeft:SetRelativeWidth(1)
	leftContainer:AddChild(horzlineLeft)



	--scrollable table of current entrants
	local scrollContainer = AceGUI:Create("SimpleGroup")
	scrollContainer:SetLayout("Fill")
	scrollContainer:SetFullWidth(true)
	--scrollContainer:SetRelativeWidth(0.6)
	--bottomPanel:AddChild(scrollContainer)
	leftContainer:AddChild(scrollContainer)
	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	scrollContainer:AddChild(scroll)

	--List entrants who have submitted 
	for name, data in pairs(BookieBets.betData.entrants) do
		--testing
		for i=1, 20 do
			local entry = AceGUI:Create("SimpleGroup")
			entry:SetFullWidth(true)
			entry:SetLayout("Flow")
			scroll:AddChild(entry)
			local entryName = AceGUI:Create("Label")
			entryName:SetText(name)
			entryName:SetRelativeWidth(0.5)
			entry:AddChild(entryName)

			local entryStatus = AceGUI:Create("Label")
			entryStatus:SetText(addon:GetClientStatusTextShort(data.status))
			entryStatus:SetRelativeWidth(0.3)
			entry:AddChild(entryStatus)

			local entryWager = AceGUI:Create("Label")
			entryWager:SetText(addon:FormatMoney(data.wager*10000))
			entryWager:SetRelativeWidth(0.2)
			entry:AddChild(entryWager)
		end
	end

	return returnGroup
end

--TODO validate sumbission fields
function GetTabClientJoined()
	addon:Debug("Create clientjoined tab")
	returnGroup = AceGUI:Create("SimpleGroup")

	local bet = ClientBets.bets[joinIndex]
	local selectedDueler = 1 --TODO dont have a default, submit disabled until client makes choice

	--populate tab with bet data
	local body = AceGUI:Create("SimpleGroup")
	body:SetLayout("List")
	body:SetFullWidth(true)
	body:SetFullHeight(true)
	returnGroup:AddChild(body)

	local duelerChoiceLabel = AceGUI:Create("Label")
	duelerChoiceLabel:SetText("Choose your dueler:")
	body:AddChild(duelerChoiceLabel)

	local duelerPanel = AceGUI:Create("SimpleGroup")
	duelerPanel:SetLayout("Flow")
	duelerPanel:SetFullWidth(true)
	body:AddChild(duelerPanel)
	
	local dueler1Button = AceGUI:Create("InteractiveLabel")
	dueler1Button:SetText(bet.duelers[1])
	dueler1Button:SetRelativeWidth(0.5)
	dueler1Button:SetHighlight(1,1,1,0.3)
	--dueler1Button:SetCallback("OnEnter", function() dueler1Button:SetHighlight(choiceHighlight) end)
	--dueler1Button:SetCallback("OnLeave", function() dueler1Button:SetHighlight(defaultHighlight) end)
	duelerPanel:AddChild(dueler1Button)
	local dueler2Button = AceGUI:Create("InteractiveLabel")
	dueler2Button:SetText(bet.duelers[2])
	dueler2Button:SetRelativeWidth(0.5)
	dueler2Button:SetHighlight(1,1,1,0.3)
	duelerPanel:AddChild(dueler2Button)

	
	--dueler2Button:SetCallback("OnEnter", function() dueler2Button:SetHighlight(choiceHighlight) end)
	--dueler2Button:SetCallback("OnLeave", function() dueler2Button:SetHighlight(defaultHighlight) end)
	

	--[[
	local wager = bet.minbet
	wagerEditbox = AceGUI:Create("EditBox")
	wagerEditbox:SetLabel("Wager")
	wagerEditbox:DisableButton(true)
	wagerEditbox:SetText(tostring(wager))
	wagerEditbox:SetCallback("OnTextChanged", function(widget, event, text) wager = text; end)
	body:AddChild(wagerEditbox)
	--]]

	horzline = AceGUI:Create("Heading")
	horzline:SetRelativeWidth(1)
	body:AddChild(horzline)

	buttonPanel = AceGUI:Create("SimpleGroup")
	body:AddChild(buttonPanel)
	buttonPanel:SetFullWidth(true)
	buttonPanel:SetLayout("Flow")

	local submitButton = AceGUI:Create("Button")
	submitButton:SetText("Submit")
	submitButton:SetRelativeWidth(1)
	submitButton:SetDisabled(true)
	submitButton:SetCallback("OnClick", function() ClientBets:SendWager(selectedDueler) end) 
	buttonPanel:AddChild(submitButton)

	dueler1Button:SetCallback("OnClick", 
		function(button) 
			selectedDueler = 1 
			button:SetColor(0,1,0,1)
			dueler2Button:SetColor(0.7,0.7,0.7,1)
			submitButton:SetDisabled(false)
		end)

	dueler2Button:SetCallback("OnClick", 
		function(button) 
			selectedDueler = 2 
			button:SetColor(0,1,0,1)
			dueler1Button:SetColor(0.7,0.7,0.7,1)
			submitButton:SetDisabled(false)
		end)

	return returnGroup
end

function GetTabClientWaiting()
	returnGroup = AceGUI:Create("SimpleGroup")

	body = AceGUI:Create("SimpleGroup")
	body:SetLayout("List")
	body:SetFullWidth(true)
	body:SetFullHeight(true)
	returnGroup:AddChild(body)

	--Bet info
	betContainer = AceGUI:Create("SimpleGroup")
	betContainer:SetLayout("List")
	betContainer:SetFullWidth(true)
	body:AddChild(betContainer)

	bet = ClientBets.bets[joinIndex]

	--dueler1, dueler2, wager
	duelerLabel = AceGUI:Create("Label")
	duelerLabel:SetText(bet.duelers[1] .. " VS " ..bet.duelers[2])
	betContainer:AddChild(duelerLabel)

	choiceLabel = AceGUI:Create("Label")
	choiceLabel:SetText("Choice: "..bet.duelers[ClientBets.activeChoice])
	betContainer:AddChild(choiceLabel)

	--bookie
	bookieLabel = AceGUI:Create("Label")
	bookieLabel:SetText("Bookie: "..ClientBets.activeBookie)
	betContainer:AddChild(bookieLabel)

	wagerText = "TBD" 
	if ClientBets.activeWager > 0 then 
		wagerText = addon:FormatMoney(ClientBets.activeWager*10000) 
	end

	wagerLabel = AceGUI:Create("Label")
	wagerLabel:SetText("Wager: "..wagerText)
	betContainer:AddChild(wagerLabel)

	horzLine1 = AceGUI:Create("Heading")
	horzLine1:SetRelativeWidth(1)
	body:AddChild(horzLine1)

	statusContainer = AceGUI:Create("SimpleGroup")
	statusContainer:SetLayout("List")
	statusContainer:SetFullWidth(true)
	body:AddChild(statusContainer)

	statusLabel = AceGUI:Create("Label")
	statusContainer:AddChild(statusLabel)

	if ClientBets.status == addon.clientStatus.WaitingForTrade then
		statusLabel:SetText("Status: Pay your Bookie")
	elseif ClientBets.status == addon.clientStatus.WaitingForResults then
		statusLabel:SetText("Status: Waiting for duel results...")
	elseif ClientBets.status == addon.clientStatus.WaitingForPayout then
		statusLabel:SetText("Status: Bookie Payouts")
	end

	payoutLabel = AceGUI:Create("Label")
	statusContainer:AddChild(payoutLabel)

	payoutText = "TBD"
	if ClientBets.payout then 
		payoutText = addon:FormatMoney(ClientBets.payout*10000) 
	end
	payoutLabel:SetText("Payout: "..payoutText)

	return returnGroup
end

local function DrawLobbyTabGroup(container)
	container:ReleaseChildren()

	body = AceGUI:Create("SimpleGroup")
	body:SetLayout("List")
	body:SetFullWidth(true)
	body:SetFullHeight(true)
	container:AddChild(body)

	bookieHeaderLabel = AceGUI:Create("Label")
	bookieHeaderLabel:SetText("Bookie")
	body:AddChild(bookieHeaderLabel)

	local bookiePanel = AceGUI:Create("SimpleGroup")
	bookiePanel:SetFullWidth(true)
	bookiePanel:SetLayout("Flow")
	body:AddChild(bookiePanel)

	bookieButton = AceGUI:Create("Button")
	bookiePanel:AddChild(bookieButton)
	bookieButton:SetText("Create New Bookie Session")
	bookieButton:SetFullWidth(true)
	bookieButton:SetHeight(54)
	bookieButton:SetCallback("OnClick", 
		function() 
			SetActiveTab("bookie_create")
			tab:SelectTab("tab2")
		end )

	clientHeaderLabel = AceGUI:Create("Heading")
	clientHeaderLabel:SetRelativeWidth(1)
	--clientHeaderLabel:SetText("Available Bets")
	body:AddChild(clientHeaderLabel)

	--scrollable table of available bets
	clientJoinPanel = AceGUI:Create("SimpleGroup")
	clientJoinPanel:SetLayout("Flow")
	clientJoinPanel:SetFullWidth(true)
	body:AddChild(clientJoinPanel)

	local scrollContainer = AceGUI:Create("SimpleGroup")
	scrollContainer:SetFullWidth(true)
	scrollContainer:SetFullHeight(true)
	scrollContainer:SetLayout("Fill")
	clientJoinPanel:AddChild(scrollContainer)

	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	scrollContainer:AddChild(scroll)

	for idx=1, #ClientBets.bets do
		bet = ClientBets.bets[idx]
		addon:Debug("Bet entry: fields:".. bet.bookie)

		local entry = AceGUI:Create("SimpleGroup")
		entry:SetFullWidth(true)
		entry:SetLayout("Flow")
		scroll:AddChild(entry)

		namePanel = AceGUI:Create("SimpleGroup")
		namePanel:SetRelativeWidth(0.5)
		namePanel:SetLayout("Flow")
		entry:AddChild(namePanel)

		buttonPanel = AceGUI:Create("SimpleGroup")
		buttonPanel:SetRelativeWidth(0.5)
		buttonPanel:SetLayout("Flow")
		entry:AddChild(buttonPanel)

		local entryLabel = AceGUI:Create("Label")
		entryLabel:SetText(bet.duelers[1].." VS ".. bet.duelers[2])
		namePanel:AddChild(entryLabel)
		local bookieLabel = AceGUI:Create("Label")
		bookieLabel:SetText("Bookie: "..bet.bookie)
		namePanel:AddChild(bookieLabel)

		local joinButton = AceGUI:Create("Button")
		joinButton:SetText("Join")
		joinButton:SetFullWidth(true)
		joinButton:SetFullHeight(true)
		joinButton:SetCallback("OnClick", 
			function() 
				joinIndex = idx
				SetActiveTab("client_joined")
				tab:SelectTab("tab2")
			end) 
		buttonPanel:AddChild(joinButton)
	end

	if #ClientBets.bets == 0 then
		noneLabel = AceGUI:Create("Label")
		noneLabel:SetText("Waiting for a bookie...")
		scroll:AddChild(noneLabel)
	end
end

function DrawActiveTabGroup(container)
	container:ReleaseChildren()
	container:AddChild(activeTab)
end

local function SelectGroup(container, event, group)
	container:ReleaseChildren()
	if group == "tab1" then
		DrawLobbyTabGroup(container)
	elseif group == "tab2" then
		DrawActiveTabGroup(container)
	end
end

function DuelBookie:GUIInit()
	frame:SetTitle("Duel Bookie")
	frame:SetStatusText("v0.1")
	frame:SetLayout("Fill")
	frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
	frame:SetWidth(300)
	frame:SetHeight(320)

	tab:SetLayout("Flow")
	tab:SetTabs({
		{text="Lobby", value="tab1"},
		{text="Active", value="tab2",},
	})

	tab:SetCallback("OnGroupSelected", SelectGroup)
	tab:SelectTab("tab1")

	frame:AddChild(tab)
end

function DuelBookie:GUIRefresh_Active()
	tab:SelectTab("tab2")
end

function DuelBookie:GUIRefresh_ClientWaiting()
	SetActiveTab("client_waiting")
	self:GUIRefresh_Active()
end

function DuelBookie:GUIRefresh_BookieStatus()
	SetActiveTab("bookie_status")
	self:GUIRefresh_Active()
end

function DuelBookie:GUIRefresh_Lobby()
	addon:Debug("GUI refreshing lobby")
	tab:SelectTab("tab1") --TODO need a refresh button instead of this forced tab open
end

function DuelBookie:GUIRefresh()
	--TODO check on the state of where the client/bookie are.
	--	We dont want to force open the lobby if someone is in an active bet.
	self:GUIRefresh_Lobby()
	--self:GUIRefresh_Active()
end

