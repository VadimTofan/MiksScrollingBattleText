local module = {}
MSBTOptions.ProfileTransfer = module

local Controls = MSBTOptions.Controls
local L = MikSBT.translations.PROFILE_TRANSFER
local popup

local function ClosePopup(frame)
	local hideHandler = frame.hideHandler
	frame.dataEditbox:ClearFocus()
	frame.nameEditbox.editboxFrame:ClearFocus()
	frame.exportText = nil
	frame.importHandler = nil
	frame.successHandler = nil
	frame.hideHandler = nil
	frame.dataEditbox:SetText("")
	frame.nameEditbox:SetText("")
	if hideHandler then hideHandler() end
end

local function Submit(frame)
	if frame.exportText then
		frame.dataEditbox:SetFocus()
		frame.dataEditbox:HighlightText()
		return
	end
	local name, details = frame.importHandler(
		frame.dataEditbox:GetText(), frame.nameEditbox:GetText())
	if not name then
		frame.statusText:SetText(L.errors[details] or L.errors.INVALID_DATA)
		return
	end
	local successHandler = frame.successHandler
	frame:Hide()
	successHandler(name, details)
end

local function CreatePopup()
	local frame = CreateFrame("Frame", nil, UIParent,
		BackdropTemplateMixin and "BackdropTemplate")
	frame:Hide()
	frame:SetSize(500, 400)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetBackdrop({
		bgFile = "Interface\\Addons\\MikScrollingBattleText\\" ..
			"MSBTOptions\\Artwork\\PlainBackdrop",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	})
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	frame:SetScript("OnHide", ClosePopup)
	MSBTOptions.Main.RegisterPopupFrame(frame)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 20, -20)
	frame.titleText = title
	local instructions = frame:CreateFontString(nil, "OVERLAY",
		"GameFontHighlightSmall")
	instructions:SetPoint("TOPLEFT", 20, -45)
	instructions:SetWidth(450)
	instructions:SetJustifyH("LEFT")
	frame.instructionsText = instructions

	local name = Controls.CreateEditbox(frame)
	name:SetPoint("TOPLEFT", 20, -72)
	name:SetPoint("TOPRIGHT", -20, -72)
	name:SetLabel(L.name)
	name.editboxFrame:SetMaxLetters(64)
	name:SetEscapeHandler(function() frame:Hide() end)
	frame.nameEditbox = name

	local scroll = CreateFrame("ScrollFrame", nil, frame,
		"UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 24, -128)
	scroll:SetPoint("BOTTOMRIGHT", -44, 112)
	frame.scrollFrame = scroll
	local background = scroll:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
	background:SetVertexColor(0, 0, 0, 0.6)

	local data = CreateFrame("EditBox", nil, scroll)
	data:SetMultiLine(true)
	data:SetAutoFocus(false)
	data:SetFontObject(ChatFontNormal)
	data:SetWidth(420)
	data:SetHeight(160)
	data:SetMaxLetters(131072)
	data:SetScript("OnEscapePressed", function() frame:Hide() end)
	data:SetScript("OnTextChanged", function(self)
		frame.statusText:SetText("")
		if frame.exportText and self:GetText() ~= frame.exportText then
			self:SetText(frame.exportText)
			self:HighlightText()
		end
		scroll:UpdateScrollChildRect()
	end)
	data:SetScript("OnCursorChanged", function(_, _, y, _, height)
		local cursor = -y
		local offset = scroll:GetVerticalScroll()
		if cursor < offset then
			scroll:SetVerticalScroll(cursor)
		elseif cursor + height > offset + scroll:GetHeight() then
			scroll:SetVerticalScroll(cursor + height - scroll:GetHeight())
		end
	end)
	scroll:SetScrollChild(data)
	frame.dataEditbox = data

	local note = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	note:SetPoint("BOTTOMLEFT", 20, 70)
	note:SetWidth(450)
	note:SetJustifyH("LEFT")
	note:SetText(L.mediaNote)
	local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	status:SetPoint("BOTTOMLEFT", 20, 45)
	status:SetWidth(450)
	status:SetJustifyH("LEFT")
	status:SetTextColor(1, 0.3, 0.3)
	frame.statusText = status

	local action = Controls.CreateOptionButton(frame)
	action:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -10, 15)
	action:SetClickHandler(function() Submit(frame) end)
	frame.actionButton = action
	local close = Controls.CreateOptionButton(frame)
	close:Configure(20, L.close)
	close:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 10, 15)
	close:SetClickHandler(function() frame:Hide() end)
	return frame
end

local function Show(config, exportText)
	if not popup then popup = CreatePopup() end
	local frame = popup
	frame.hideHandler = nil
	frame:SetParent(config.parentFrame)
	frame:SetFrameStrata("DIALOG")
	frame.exportText = exportText
	frame.importHandler = config.importHandler
	frame.successHandler = config.successHandler
	frame.hideHandler = config.hideHandler
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", config.parentFrame, "CENTER")
	frame.titleText:SetText(exportText and L.exportTitle or L.importTitle)
	frame.instructionsText:SetText(exportText and L.exportHelp or L.importHelp)
	frame.actionButton:Configure(20, exportText and L.selectAll or L.import)
	if exportText then
		frame.nameEditbox:Hide()
		frame.scrollFrame:ClearAllPoints()
		frame.scrollFrame:SetPoint("TOPLEFT", 24, -78)
	else
		frame.nameEditbox:Show()
		frame.nameEditbox:SetText("")
		frame.scrollFrame:ClearAllPoints()
		frame.scrollFrame:SetPoint("TOPLEFT", 24, -128)
	end
	frame.scrollFrame:SetPoint("BOTTOMRIGHT", -44, 112)
	frame.dataEditbox:SetText(exportText or "")
	frame.scrollFrame:SetVerticalScroll(0)
	frame.statusText:SetText("")
	frame:Show()
	frame:Raise()
	frame.dataEditbox:SetFocus()
	if exportText then frame.dataEditbox:HighlightText() end
end

function module.ShowExport(config, text)
	Show(config, text)
end

function module.ShowImport(config)
	Show(config)
end
