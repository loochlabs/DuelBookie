--core 

local _,addon = ...
DuelBookie = addon
AceGUI = LibStub("AceGUI-3.0")
ClientBets = addon:GetModule("ClientBets")
addon.ClientBets = ClientBets
BookieBets = addon:GetModule("BookieBets")
addon.BookieBets = BookieBets
addon.isBookie = false

local frame = nil 
local tab = nil
local activeTab = nil
local joinIndex = 0

local highlightTexture = [[Interface\PaperDollInfoFrame\UI-Character-Skills-Bar]]

activeTabGroups = {
	create_lobby = function() return MDB_GetTabLobby() end,
	bookie_create = function() return GetTabBookieCreate() end,
	bookie_status = function() return GetTabBookieStatus() end,
	client_joined = function() return GetTabClientJoined() end,
	client_waiting = function() return GetTabClientWaiting() end,
}

local function ValidBetParams(dueler1, dueler2, minbet, maxbet, rake)
	local validNames = true
	--local validNames = UnitExists(dueler1) and UnitExists(dueler2) and dueler1 ~= dueler2
	return validNames and minbet and maxbet and rake and (tonumber(minbet) < tonumber(maxbet))
end

function SetActiveTab(key)
	addon:Debug("Getting active tab "..key)
	activeTab = activeTabGroups[key]()
end

function MDB_GetTabLobby()
	returnGroup = AceGUI:Create("SimpleGroup")
	returnGroup:SetFullWidth(true)
	returnGroup:SetFullHeight(true)

	body = AceGUI:Create("SimpleGroup")
	body:SetLayout("List")
	body:SetFullWidth(true)
	body:SetFullHeight(true)
	returnGroup:AddChild(body)

	local bookiePanel = AceGUI:Create("SimpleGroup")
	bookiePanel:SetFullWidth(true)
	bookiePanel:SetLayout("Flow")
	body:AddChild(bookiePanel)

	bookieButton = AceGUI:Create("Button")
	bookiePanel:AddChild(bookieButton)
	bookieButton:SetText("Create New Bookie Session")
	bookieButton:SetFullWidth(true)
	bookieButton:SetCallback("OnClick", 
		function() 
			SetActiveTab("bookie_create")
			tab:SelectTab("tab1")
		end )

	horzLine = AceGUI:Create("Heading")
	horzLine:SetRelativeWidth(1)
	body:AddChild(horzLine)

	--scrollable table of available bets
	clientJoinPanel = AceGUI:Create("SimpleGroup")
	clientJoinPanel:SetLayout("Flow")
	clientJoinPanel:SetFullWidth(true)
	body:AddChild(clientJoinPanel)

	local scrollContainer = AceGUI:Create("SimpleGroup")
	scrollContainer:SetFullWidth(true)
	scrollContainer:SetHeight(100)
	scrollContainer:SetLayout("Fill")
	clientJoinPanel:AddChild(scrollContainer)

	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	scrollContainer:AddChild(scroll)

	for idx=1, #ClientBets.availableBets do
		bet = ClientBets.availableBets[idx]

		--DEBUG fill lobby join list
		fillCount = 1
		if addon.debug then fillCount = 20 end

		for i=1, fillCount do 
			addon:Debug("Bet entry: fields:".. bet.bookie)

			entry = AceGUI:Create("SimpleGroup")
			entry:SetFullWidth(true)
			entry:SetLayout("Flow")
			scroll:AddChild(entry)

			namePanel = AceGUI:Create("SimpleGroup")
			namePanel:SetRelativeWidth(0.7)
			namePanel:SetLayout("Flow")
			entry:AddChild(namePanel)

			buttonPanel = AceGUI:Create("SimpleGroup")
			buttonPanel:SetRelativeWidth(0.3)
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
			joinButton:SetDisabled(not bet.open)
			joinButton:SetCallback("OnClick", 
				function() 
					joinIndex = idx
					SetActiveTab("client_joined")
					tab:SelectTab("tab1")
				end) 
			buttonPanel:AddChild(joinButton)
		end
	end

	if #ClientBets.availableBets == 0 then
		noneLabel = AceGUI:Create("Label")
		noneLabel:SetText("Waiting for a bookie...")
		scroll:AddChild(noneLabel)
	end

	return returnGroup
end

local function GetRake(text)
	rake = string.gsub(text, "%%", "")
	rake = tonumber(rake)/100
	return rake
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
	dueler2Editbox:DisableButton(true)
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

	rakeOptions = {
		rake0 = "0%",
		rake5 = "5%",
		rake10 = "10%",
		rake20 = "25%",
	}

	rakeOptionOrder = { "rake0", "rake5", "rake10", "rake20" }
	rake = GetRake(rakeOptions.rake0)

	rakeDropdown = AceGUI:Create("Dropdown")
	rakeDropdown:SetLabel("Percentage of gold taken from prize pool:")
	rakeDropdown:SetFullWidth(true)
	rakeDropdown:SetList(rakeOptions, rakeOptionOrder)
	rakeDropdown:SetValue("rake0")
	rakeDropdown:SetCallback("OnValueChanged", 
		function(widget, event, key) 
			rake = GetRake(rakeOptions[key])
			createBetStartButton:SetDisabled(not ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
		end)
	rakeContainer:AddChild(rakeDropdown)

	horzLine = AceGUI:Create("Heading")
	body:AddChild(horzLine)
	horzLine:SetRelativeWidth(1)

	footer = AceGUI:Create("SimpleGroup")
	footer:SetFullWidth(true)
	footer:SetLayout("Flow")
	body:AddChild(footer)

	createBetStartButton = AceGUI:Create("Button")
	footer:AddChild(createBetStartButton)
	createBetStartButton:SetText("Start")
	createBetStartButton:SetRelativeWidth(0.7)
	createBetStartButton:SetDisabled(not ValidBetParams(dueler1Name, dueler2Name, minbet, maxbet, rake))
	createBetStartButton:SetCallback("OnClick", 
		function() 
			BookieBets:CreateBet(dueler1Name, dueler2Name, minbet, maxbet, rake) 
			SetActiveTab("bookie_status")
			tab:SelectTab("tab1")
		end )

	cancelBetButton = AceGUI:Create("Button")
	footer:AddChild(cancelBetButton)
	cancelBetButton:SetText("Cancel")
	cancelBetButton:SetRelativeWidth(0.3)
	cancelBetButton:SetCallback("OnClick", 
		function() 
			SetActiveTab("create_lobby")
			tab:SelectTab("tab1")
		end )

	return returnGroup
end

function GetControlButtons(status)
	addon:Debug("Get control buttons: "..status)
	controlBetsPanel = AceGUI:Create("SimpleGroup")
	controlBetsPanel:SetLayout("Flow")

	if status == addon.betStatus.Open then
		addon:Debug("Get control buttons: "..status)
		closeBetsButton = AceGUI:Create("Button")
		controlBetsPanel:AddChild(closeBetsButton)
		closeBetsButton:SetFullWidth(true)
		closeBetsButton:SetDisabled(BookieBets:GetEntrantsCount() == 0)
		closeBetsButton:SetText("Close Bets")
		closeBetsButton:SetCallback("OnClick", 
			function() 
				BookieBets:FinalizeWagers() 
			end)

	elseif status == addon.betStatus.BetsClosed then
		local finalLabel = AceGUI:Create("Label")
		finalLabel:SetText("Choose Winner:")
		controlBetsPanel:AddChild(finalLabel)
		finalLabel:SetFullWidth(true)

		dueler1Button = AceGUI:Create("Button")
		dueler1Button:SetText(BookieBets.betData.info.duelers[1])
		dueler1Button:SetRelativeWidth(0.5)
		dueler1Button:SetCallback("OnClick", function() BookieBets:FinalizeDuelWinner(1) end)
		controlBetsPanel:AddChild(dueler1Button)
		
		dueler2Button = AceGUI:Create("Button")
		dueler2Button:SetRelativeWidth(0.5)
		dueler2Button:SetText(BookieBets.betData.info.duelers[2])
		dueler2Button:SetCallback("OnClick", function() BookieBets:FinalizeDuelWinner(2) end)
		controlBetsPanel:AddChild(dueler2Button)

	elseif status == addon.betStatus.Complete or status == addon.betStatus.PendingPayout then
		returnButton = AceGUI:Create("Button")
		controlBetsPanel:AddChild(returnButton)
		returnButton:SetFullWidth(true)
		returnButton:SetText("Return to Lobby")
		returnButton:SetCallback("OnClick", function() BookieBets:EndCurrentBet() end )

		--check if all entrants are paid
		entrantsPaid = BookieBets:AllEntrantsPaid()
		returnButton:SetDisabled(not entrantsPaid)
	end

	
	return controlBetsPanel
end

function GetTabBookieStatus()
	returnGroup = AceGUI:Create("SimpleGroup")
	local body = AceGUI:Create("SimpleGroup")
	body:SetFullWidth(true)
	body:SetFullHeight(true)
	body:SetLayout("List")
	returnGroup:AddChild(body)

	headerPanel = AceGUI:Create("SimpleGroup")
	headerPanel:SetLayout("Flow")
	headerPanel:SetFullWidth(true)
	body:AddChild(headerPanel)

	headerPanelLeft = AceGUI:Create("SimpleGroup")
	headerPanel:AddChild(headerPanelLeft)
	headerPanelLeft:SetRelativeWidth(0.5)

	duelerLabel = AceGUI:Create("Label")
	duelerLabel:SetFullWidth(true)
	headerPanelLeft:AddChild(duelerLabel)
	--TODO we have the same data in BookieBets and ClientBets here...
	duelerLabel:SetText(BookieBets.betData.info.duelers[1].." VS "..BookieBets.betData.info.duelers[2])
	
	totalPoolLabel = AceGUI:Create("Label")
	totalPoolLabel:SetText("PRIZE POOL: "..
		addon:FormatMoney((BookieBets.betData.pool[1]+BookieBets.betData.pool[2])*(1-BookieBets.betData.info.rake)))
	totalPoolLabel:SetFullWidth(true)
	headerPanelLeft:AddChild(totalPoolLabel)

	odds = BookieBets:CalculateOdds()
	oddsLabel = AceGUI:Create("Label")
	headerPanelLeft:AddChild(oddsLabel)
	oddsLabel:SetText("ODDS | " .. odds[1]..":"..odds[2])--..ceil(odds[1]/1000)/10 ..":"..ceil(odds[2]/1000)/10)
	
	headerPanelRight = AceGUI:Create("SimpleGroup")
	headerPanel:AddChild(headerPanelRight)
	headerPanelRight:SetRelativeWidth(0.5)

	cancelButton = AceGUI:Create("Button")
	headerPanelRight:AddChild(cancelButton)
	cancelButton:SetFullWidth(true)
	cancelButton:SetText("Cancel Bet")
	cancelButton:SetCallback("OnClick", function() 
		BookieBets:CancelBet() 
	end)


	horzline3 = AceGUI:Create("Heading")
	horzline3:SetRelativeWidth(1)
	body:AddChild(horzline3)

	bottomPanel = AceGUI:Create("SimpleGroup")
	body:AddChild(bottomPanel)
	bottomPanel:SetFullWidth(true)
	bottomPanel:SetLayout("Flow")

	leftLabel = AceGUI:Create("Label")
	bottomPanel:AddChild(leftLabel)
	leftLabel:SetText("ENTRANTS")
	leftLabel:SetFullWidth(true)

	horzlineLeft = AceGUI:Create("Heading")
	horzlineLeft:SetRelativeWidth(1)
	bottomPanel:AddChild(horzlineLeft)

	--scrollable table of current entrants
	local scrollContainer = AceGUI:Create("SimpleGroup")
	scrollContainer:SetLayout("Fill")
	scrollContainer:SetFullWidth(true)
	scrollContainer:SetHeight(100)
	bottomPanel:AddChild(scrollContainer)
	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	scrollContainer:AddChild(scroll)

	--List entrants who have submitted 
	for name, data in pairs(BookieBets.betData.entrants) do
		fillCount = 1
		if addon.debug then fillCount = 20 end

		for i=1, fillCount do
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
			entryWager:SetRelativeWidth(0.2)
			entry:AddChild(entryWager)

			statusText = addon:FormatMoney(data.wager)
			if data.status == addon.clientStatus.ConclusionPaid then
				statusText = addon:FormatMoney(data.payoutReceived)
			elseif data.status > addon.clientStatus.WaitingForResults then
				statusText = addon:FormatMoney(data.payout - data.payoutReceived)
			end
			entryWager:SetText(statusText)
		end
	end

	horzSpacer = AceGUI:Create("Heading")
	horzSpacer:SetRelativeWidth(1)
	body:AddChild(horzSpacer)

	controlPanel = AceGUI:Create("SimpleGroup")
	body:AddChild(controlPanel)
	controlPanel:SetFullWidth(true)
	controlPanel:SetLayout("Flow")

	controlButtons = GetControlButtons(BookieBets.betStatus)
	controlPanel:AddChild(controlButtons)

	return returnGroup
end

--TODO validate sumbission fields
function GetTabClientJoined()
	addon:Debug("Create clientjoined tab")
	returnGroup = AceGUI:Create("SimpleGroup")

	local bet = ClientBets.availableBets[joinIndex]

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
	dueler1Button:SetHighlight(highlightTexture)
	duelerPanel:AddChild(dueler1Button)
	local dueler2Button = AceGUI:Create("InteractiveLabel")
	dueler2Button:SetText(bet.duelers[2])
	dueler2Button:SetRelativeWidth(0.5)
	dueler2Button:SetHighlight(highlightTexture)
	duelerPanel:AddChild(dueler2Button)

	horzline = AceGUI:Create("Heading")
	horzline:SetRelativeWidth(1)
	body:AddChild(horzline)

	buttonPanel = AceGUI:Create("SimpleGroup")
	body:AddChild(buttonPanel)
	buttonPanel:SetFullWidth(true)
	buttonPanel:SetLayout("Flow")

	local selectedDueler = nil
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

	bet = ClientBets.availableBets[joinIndex]

	--dueler1, dueler2, wager
	duelerLabel = AceGUI:Create("Label")
	duelerLabel:SetText(bet.duelers[1] .. " VS " ..bet.duelers[2])
	betContainer:AddChild(duelerLabel)

	choiceLabel = AceGUI:Create("Label")
	choiceLabel:SetText("CHOICE: "..bet.duelers[ClientBets.activeChoice])
	betContainer:AddChild(choiceLabel)

	--bookie
	bookieLabel = AceGUI:Create("Label")
	bookieLabel:SetText("BOOKIE: "..ClientBets.activeBookie)
	betContainer:AddChild(bookieLabel)

	wagerText = "TBD" 
	if ClientBets.activeWager > 0 then 
		wagerText = addon:FormatMoney(ClientBets.activeWager) 
	end

	wagerLabel = AceGUI:Create("Label")
	wagerLabel:SetText("WAGER: "..wagerText)
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
	statusLabel:SetFullWidth(true)

	if ClientBets.status == addon.clientStatus.WaitingForTrade then
		statusLabel:SetText("STATUS: Pay your Bookie")
	elseif ClientBets.status == addon.clientStatus.WaitingForResults then
		statusLabel:SetText("STATUS: Waiting for duel results...")
	elseif ClientBets.status == addon.clientStatus.WaitingForPayout then
		statusLabel:SetText("STATUS: WINNER! Waiting for Bookie Payouts")
	elseif ClientBets.status == addon.clientStatus.ConclusionLost then
		statusLabel:SetText("STATUS: LOSER. Return to Lobby")	
	elseif ClientBets.status == addon.clientStatus.ConclusionPaid then
		statusLabel:SetText("STATUS: Paid")
	end

	payoutLabel = AceGUI:Create("Label")
	statusContainer:AddChild(payoutLabel)

	payoutText = "TBD"
	if ClientBets.payout then 
		payoutText = addon:FormatMoney(ClientBets.payout) 
	end
	payoutLabel:SetText("PAYOUT: "..payoutText)

	horzLine2 = AceGUI:Create("Heading")
	horzLine2:SetRelativeWidth(1)
	body:AddChild(horzLine2)

	footer = AceGUI:Create("SimpleGroup")
	footer:SetLayout("Flow")
	footer:SetFullWidth(true)
	body:AddChild(footer)

	closeBetButton = AceGUI:Create("Button")
	closeBetButton:SetText("Return to Lobby")
	footer:AddChild(closeBetButton)
	closeBetButton:SetFullWidth(true)
	closeBetButton:SetDisabled(ClientBets.status ~= addon.clientStatus.ConclusionPaid and ClientBets.status ~= addon.clientStatus.ConclusionLost)
	closeBetButton:SetCallback("OnClick", 
		function() 
			ClientBets:CleanupCurrentBet()
			addon:GUIRefresh_Lobby()
		end)

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
	bookieButton:SetHeight(40)
	bookieButton:SetCallback("OnClick", 
		function() 
			SetActiveTab("bookie_create")
			tab:SelectTab("tab1")
		end )

	clientHeaderLabel = AceGUI:Create("Heading")
	clientHeaderLabel:SetRelativeWidth(1)
	body:AddChild(clientHeaderLabel)

	--scrollable table of available bets
	clientJoinPanel = AceGUI:Create("SimpleGroup")
	clientJoinPanel:SetLayout("Flow")
	clientJoinPanel:SetFullWidth(true)
	body:AddChild(clientJoinPanel)

	local scrollContainer = AceGUI:Create("SimpleGroup")
	scrollContainer:SetFullWidth(true)
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
				tab:SelectTab("tab1")
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
		DrawActiveTabGroup(container)
	end
end

function DuelBookie:GUIInit()
	frame = AceGUI:Create("Frame")
	frame:SetTitle("Duel Bookie")
	frame:SetStatusText("v0.1")
	frame:SetLayout("Fill")
	frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
	frame:SetWidth(300)
	frame:SetHeight(360)--320)

	tab = AceGUI:Create("TabGroup")
	frame:AddChild(tab)
	tab:SetLayout("Flow")
	tab:SetTabs({
		{text="Lobby", value="tab1"},
	})
	tab:SetCallback("OnGroupSelected", SelectGroup)
	
	if addon.BookieBets and addon.isBookie then
		self:GUIRefresh_BookieStatus()
	elseif addon.ClientBets and not addon.isBookie and addon.ClientBets.status ~= addon.clientStatus.Inactive then
		self:GUIRefresh_ClientWaiting()
	else
		ClientBets:RefreshAvailableBets()
		self:GUIRefresh_Lobby()
	end
end

function DuelBookie:GUIRefresh_Active()
	tab:SelectTab("tab1")
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
	SetActiveTab("create_lobby")
	tab:SelectTab("tab1") 
end

function DuelBookie:GUI_ShowRootFrame()
	if not frame:IsVisible() then
		self:GUIInit()
		frame:Show()
	end
end

function DuelBookie:GUI_HideRootFrame()
	frame:Hide()
end
