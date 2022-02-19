--[[
	Bloody Mask
	Copyright (c) 2013 Resperger Dániel (Resike)
	E-Mail: reske@gmail.com
	All rights reserved.
	The addon can be found at:
	http://www.curse.com/addons/wow/bloody-mask
	http://www.wowinterface.com/downloads/info22354-BloodyMask.html
--]]
local BloodyMask = {}

local pairs, ipairs, next = pairs, ipairs, next
local type, tsort = type, table.sort
local random, rad, sqrt, floor, max = math.random, math.rad, math.sqrt, math.floor, math.max
local CreateFrame, GetTime, GetFramerate = CreateFrame, GetTime, GetFramerate
local UnitGUID = UnitGUID
local UnitIsGhost, UnitIsDeadOrGhost = UnitIsGhost, UnitIsDeadOrGhost
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local PlaySoundFile = PlaySoundFile
local WowBuildInfo = select(4, GetBuildInfo()) or 0
local _

local BloodyMaskVars = {
	EnableAddon = true,
	TextureMaskFrame = {Alpha = 0.75, Strata = "BACKGROUND", Level = 1},
	TextureMask = {BlendMode = "Disable", Strata = "BACKGROUND", Level = 0},
	TextureBloodFrame = {
		Alpha = 1.0,
		Strata = "BACKGROUND",
		Level = 0,
		WidthPercent = 0.70,
		HeightPercent = 0.85,
		WidthPreventPercent = 0.08,
		HeightPreventPercent = 0.08
	},
	TextureBlood = {BlendMode = "Mod", Strata = "BACKGROUND", Level = 0, Type = "Blood"},
	Damage = {MinimalScalingFactor = 1.0, MaximalScalingFactor = 1.35, LowerDamageLimit = 0, UpperDamageLimit = 100000},
	Sound = {Enable = true, Channel = "Master"},
	Health1 = 0.90,
	Health2 = 0.75,
	Health3 = 0.60,
	Health4 = 0.45,
	Health5 = 0.30,
	Health6 = 0.15
}

local PlayerHealthGetObjective
local PlayerHealthState
local BloodyMask_ShowAllTextures
local BloodyMask_HideAllTextures
local BloodyMask_RandomlyHideAllTextures
local SortByOffsetAscending
local SortByOffsetDescending
local BloodyMask_HideAllTexturesFrom
local Position

local EventFrame = CreateFrame("Frame", nil)
EventFrame:RegisterEvent("ADDON_LOADED")

local TextureMaskFrame = CreateFrame("Frame", nil)
TextureMaskFrame:SetAllPoints(UIParent)
TextureMaskFrame:SetAlpha(BloodyMaskVars.TextureMaskFrame.Alpha)
TextureMaskFrame:SetFrameStrata(BloodyMaskVars.TextureMaskFrame.Strata)
TextureMaskFrame:SetFrameLevel(BloodyMaskVars.TextureMaskFrame.Level)

local TextureMask = TextureMaskFrame:CreateTexture(nil, BloodyMaskVars.TextureMask.Strata)
TextureMask:SetAllPoints(TextureMaskFrame)
TextureMask:SetDrawLayer(BloodyMaskVars.TextureMask.Strata, BloodyMaskVars.TextureMask.Level)
TextureMask:SetBlendMode(BloodyMaskVars.TextureMask.BlendMode)

local TextureBloodFrame = CreateFrame("Frame", nil)
TextureBloodFrame:SetAllPoints(UIParent)
TextureBloodFrame:SetAlpha(BloodyMaskVars.TextureBloodFrame.Alpha)
TextureBloodFrame:SetFrameStrata(BloodyMaskVars.TextureBloodFrame.Strata)
TextureBloodFrame:SetFrameLevel(BloodyMaskVars.TextureBloodFrame.Level)

local TextureBlood = {}
local TextureBloodTimers = {}
local TextureBloodAlpha = {}
local TextureBloodFadingIterator = {}

local MaximumSplatters = 20
local TextureTypes = 5
local FadeOutSequences = 17
local BaseWidth = 280
local BaseHeight = 280
local BaseUpTime = 12
local FadingTime = 0.4
local LastTextureShown = 0

local AddonPath = "Interface\\AddOns\\BloodyMask\\"

local PlayerHealthObjectives = {Percent = nil}

function PlayerHealthGetObjective(healthPercent)
	if healthPercent then
		return "Percent"
	else
		return false
	end
end

function PlayerHealthState(healthPercent)
	if healthPercent >= BloodyMaskVars.Health1 then
		return 1
	elseif healthPercent < BloodyMaskVars.Health1 and healthPercent > BloodyMaskVars.Health2 then
		return 2
	elseif healthPercent < BloodyMaskVars.Health2 and healthPercent > BloodyMaskVars.Health3 then
		return 3
	elseif healthPercent < BloodyMaskVars.Health3 and healthPercent > BloodyMaskVars.Health4 then
		return 4
	elseif healthPercent < BloodyMaskVars.Health4 and healthPercent > BloodyMaskVars.Health5 then
		return 5
	elseif healthPercent < BloodyMaskVars.Health5 and healthPercent > BloodyMaskVars.Health6 then
		return 6
	elseif healthPercent < BloodyMaskVars.Health6 and UnitIsDeadOrGhost("player") ~= 1 then
		return 7
	else
		return 10
	end
end

function BloodyMask:OnLoad()
	PlayerHealthObjectives.Percent = UnitHealth("player") / UnitHealthMax("player")
	BloodyMask:RegisterEvents()
	BloodyMask:CreateTextures()
	TextureBloodFrame:SetScript("OnUpdate", BloodyMask.TexturesOnUpdate)
	EventFrame:UnregisterEvent("ADDON_LOADED")
end

function BloodyMask:RegisterEvents()
	EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	EventFrame:RegisterEvent("UNIT_HEALTH")
	EventFrame:RegisterEvent("UNIT_MAXHEALTH")
	EventFrame:RegisterEvent("PLAYER_DEAD")
	EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function BloodyMask:OnEvent(event, ...)
	if event == "ADDON_LOADED" then
		local Addon = ...
		if Addon == "BloodyMask" then
			if BloodyMaskVars.EnableAddon == true then
				BloodyMask:OnLoad()
			end
		end
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local eventType, srcGUID, dstGUID, swingDamage, spellDamage, swingCrit, spellCrit
		if WowBuildInfo >= 40200 then
			_, eventType, _, srcGUID, _, _, _, dstGUID, _, _, _, swingDamage, _, _, spellDamage, _, _, swingCrit, _, _, spellCrit = ...
		elseif WowBuildInfo >= 40100 then
			_, eventType, _, srcGUID, _, _, dstGUID, _, _, _, swingDamage, _, _, spellDamage, _, _, swingCrit, _, _, spellCrit = ...
		else
			_, eventType, srcGUID, _, _, dstGUID, _, _, swingDamage, _, _, spellDamage, _, _, swingCrit, _, _, spellCrit = ...
		end
		if (srcGUID == UnitGUID("player")) and (dstGUID == UnitGUID("target")) then
			local Damage
			local CritMatchesConfig = false
			if eventType == "SWING_DAMAGE" and swingCrit then
				Damage = swingDamage
				CritMatchesConfig = true
			elseif eventType == "RANGE_DAMAGE" and spellCrit then
				Damage = spellDamage
				CritMatchesConfig = true
			elseif eventType == "SPELL_DAMAGE" and spellCrit then
				Damage = spellDamage
				CritMatchesConfig = true
			elseif eventType == "SPELL_PERIODIC_DAMAGE" and spellCrit then
				Damage = spellDamage
				CritMatchesConfig = true
			end
			if (CritMatchesConfig) then
				local Scale
				if Damage < BloodyMaskVars.Damage.LowerDamageLimit then
					Scale = BloodyMaskVars.Damage.MinimalScalingFactor
				elseif Damage > BloodyMaskVars.Damage.UpperDamageLimit then
					Scale = BloodyMaskVars.Damage.MaximalScalingFactor
				else
					Scale = BloodyMaskVars.Damage.MinimalScalingFactor + (BloodyMaskVars.Damage.MaximalScalingFactor - BloodyMaskVars.Damage.MinimalScalingFactor) * (Damage / BloodyMaskVars.Damage.UpperDamageLimit)
				end
				LastTextureShown = ((LastTextureShown + MaximumSplatters) % MaximumSplatters) + 1
				BloodyMask:TextureOnShow(LastTextureShown, Scale)
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		if ... and ... ~= "player" then return end
		local PlayerHealthPercent = UnitHealth("player") / UnitHealthMax("player")
		-- Textures
		if PlayerHealthPercent >= BloodyMaskVars.Health1 then
			if TextureMask:GetTexture() ~= AddonPath .. "Textures\\Mask\\Mask1" then
				TextureMask:SetTexture(AddonPath .. "Textures\\Mask\\Mask1")
			end
		elseif PlayerHealthPercent < BloodyMaskVars.Health1 and PlayerHealthPercent >= BloodyMaskVars.Health2 then
			if TextureMask:GetTexture() ~= AddonPath .. "Textures\\Mask\\Mask2" then
				TextureMask:SetTexture(AddonPath .. "Textures\\Mask\\Mask2")
			end
		elseif PlayerHealthPercent < BloodyMaskVars.Health2 and PlayerHealthPercent >= BloodyMaskVars.Health3 then
			if TextureMask:GetTexture() ~= AddonPath .. "Textures\\Mask\\Mask3" then
				TextureMask:SetTexture(AddonPath .. "Textures\\Mask\\Mask3")
			end
		elseif PlayerHealthPercent < BloodyMaskVars.Health3 and PlayerHealthPercent >= BloodyMaskVars.Health4 then
			if TextureMask:GetTexture() ~= AddonPath .. "Textures\\Mask\\Mask4" then
				TextureMask:SetTexture(AddonPath .. "Textures\\Mask\\Mask4")
			end
		elseif PlayerHealthPercent < BloodyMaskVars.Health4 and PlayerHealthPercent >= BloodyMaskVars.Health5 then
			if TextureMask:GetTexture() ~= AddonPath .. "Textures\\Mask\\Mask5" then
				TextureMask:SetTexture(AddonPath .. "Textures\\Mask\\Mask5")
			end
		elseif PlayerHealthPercent < BloodyMaskVars.Health5 and PlayerHealthPercent >= BloodyMaskVars.Health6 then
			if TextureMask:GetTexture() ~= AddonPath .. "Textures\\Mask\\Mask6" then
				TextureMask:SetTexture(AddonPath .. "Textures\\Mask\\Mask6")
			end
		elseif PlayerHealthPercent < BloodyMaskVars.Health6 then
			if UnitIsDeadOrGhost("player") ~= 1 then
				if TextureMask:GetTexture() ~= AddonPath .. "Textures\\Mask\\Mask7" then
					TextureMask:SetTexture(AddonPath .. "Textures\\Mask\\Mask7")
				end
			else
				if UnitIsGhost("player") ~= 1 then
					if TextureMask:GetTexture() ~= AddonPath .. "Textures\\Mask\\Mask8" then
						TextureMask:SetTexture(AddonPath .. "Textures\\Mask\\Mask8")
					end
				else
					if TextureMask:GetTexture() ~= AddonPath .. "Textures\\Mask\\Dirt" then
						TextureMask:SetTexture(AddonPath .. "Textures\\Mask\\Dirt")
					end
				end
			end
		end
		-- Sounds
		if BloodyMaskVars.Sound.Enable == true then
			local type = PlayerHealthGetObjective(PlayerHealthPercent)
			if type then
				if PlayerHealthState(PlayerHealthObjectives[type]) < PlayerHealthState(PlayerHealthPercent) and PlayerHealthState(PlayerHealthPercent) == 2 then
					PlaySoundFile(AddonPath .. "Sounds\\MaskCrack1.mp3", BloodyMaskVars.Sound.Channel)
				elseif PlayerHealthState(PlayerHealthObjectives[type]) < PlayerHealthState(PlayerHealthPercent) and PlayerHealthState(PlayerHealthPercent) == 3 then
					PlaySoundFile(AddonPath .. "Sounds\\MaskCrack1.mp3", BloodyMaskVars.Sound.Channel)
				elseif PlayerHealthState(PlayerHealthObjectives[type]) < PlayerHealthState(PlayerHealthPercent) and PlayerHealthState(PlayerHealthPercent) == 4 then
					PlaySoundFile(AddonPath .. "Sounds\\MaskCrack2.mp3", BloodyMaskVars.Sound.Channel)
				elseif PlayerHealthState(PlayerHealthObjectives[type]) < PlayerHealthState(PlayerHealthPercent) and PlayerHealthState(PlayerHealthPercent) == 5 then
					PlaySoundFile(AddonPath .. "Sounds\\MaskCrack2.mp3", BloodyMaskVars.Sound.Channel)
				elseif PlayerHealthState(PlayerHealthObjectives[type]) < PlayerHealthState(PlayerHealthPercent) and PlayerHealthState(PlayerHealthPercent) == 6 then
					PlaySoundFile(AddonPath .. "Sounds\\MaskCrack3.mp3", BloodyMaskVars.Sound.Channel)
				elseif PlayerHealthState(PlayerHealthObjectives[type]) < PlayerHealthState(PlayerHealthPercent) and PlayerHealthState(PlayerHealthPercent) == 7 then
					PlaySoundFile(AddonPath .. "Sounds\\MaskCrack3.mp3", BloodyMaskVars.Sound.Channel)
				end
				PlayerHealthObjectives[type] = PlayerHealthPercent
			end
		end
	elseif event == "PLAYER_DEAD" then
		PlaySoundFile(AddonPath .. "Sounds\\MaskCrack4.mp3", BloodyMaskVars.Sound.Channel)
	end
end

if BloodyMaskVars.EnableAddon == true then
	EventFrame:SetScript("OnEvent", BloodyMask.OnEvent)
end

function BloodyMask:CreateTextures()
	for i = 1, MaximumSplatters do
		if (TextureBlood[i] == nil) then
			TextureBlood[i] = TextureBloodFrame:CreateTexture(nil, "Background")
			TextureBlood[i]:SetTexture(AddonPath .. "Textures\\" .. BloodyMaskVars.TextureBlood.Type .. "\\Blood" .. (((i - 1) % TextureTypes) + 1) .. "_1")
			TextureMask:SetDrawLayer(BloodyMaskVars.TextureBlood.Strata, BloodyMaskVars.TextureBlood.Level)
			TextureBlood[i]:SetWidth(BaseWidth)
			TextureBlood[i]:SetHeight(BaseHeight)
			TextureBlood[i]:SetBlendMode(BloodyMaskVars.TextureBlood.BlendMode)
			TextureBlood[i]:Hide()
		end
		if (TextureBloodTimers[i] == nil) then
			TextureBloodTimers[i] = 0
		end
		if (TextureBloodAlpha[i] == nil) then
			TextureBloodAlpha[i] = 1
		end
		if (TextureBloodFadingIterator[i] == nil) then
			TextureBloodFadingIterator[i] = 0
		end
	end
end

function BloodyMask:TextureOnShow(i, scale)
	TextureBloodTimers[i] = GetTime() + (i / MaximumSplatters) + random(4)
	TextureBloodAlpha[i] = 1
	TextureBlood[i]:SetRotation(rad(random(360)))
	TextureBlood[i]:ClearAllPoints()
	TextureBlood[i]:SetWidth(BaseWidth * scale)
	TextureBlood[i]:SetHeight(BaseHeight * scale)
	local Width = max(1, (UIParent:GetWidth() * BloodyMaskVars.TextureBloodFrame.WidthPercent) - (BaseWidth * sqrt(2)))
	local Height = max(1, (UIParent:GetHeight() * BloodyMaskVars.TextureBloodFrame.HeightPercent) - (BaseHeight * sqrt(2)))
	local x = random(Width) - (Width / 2)
	local y = random(Height) - (Height / 2)
	local PreventWidth = UIParent:GetWidth() * BloodyMaskVars.TextureBloodFrame.WidthPreventPercent
	local PreventHeight = UIParent:GetHeight() * (UIParent:GetWidth() / UIParent:GetHeight()) * BloodyMaskVars.TextureBloodFrame.HeightPreventPercent
	if x > -PreventWidth and x <= 0 and y > -PreventHeight and y <= 0 then
		x = (PreventWidth + random(25)) * -1
		y = (PreventHeight + random(25)) * -1
	elseif x > -PreventWidth and x <= 0 and y < PreventHeight and y > 0 then
		x = (PreventWidth + random(25)) * -1
		y = PreventHeight + random(25)
	elseif x < PreventWidth and x > 0 and y > -PreventHeight and y <= 0 then
		x = PreventWidth + random(25)
		y = (PreventHeight + random(25)) * -1
	elseif x < PreventWidth and x > 0 and y < PreventHeight and y > 0 then
		x = PreventWidth + random(25)
		y = PreventHeight + random(25)
	end
	TextureBlood[i]:SetPoint("CENTER", TextureBloodFrame, "CENTER", x, y)
	TextureBlood[i]:Show()
end

function BloodyMask_ShowAllTextures()
	for i = 1, MaximumSplatters do
		if (not TextureBlood[i]:IsVisible()) then
			local scale = BloodyMaskVars.Damage.MinimalScalingFactor + ((BloodyMaskVars.Damage.MaximalScalingFactor - BloodyMaskVars.Damage.MinimalScalingFactor) / i)
			TextureBloodTimers[i] = GetTime() + random(8)
			TextureBlood[i]:Show()
			BloodyMask:TextureOnShow(i, scale)
		end
	end
end

function BloodyMask_HideAllTextures()
	for i = 1, MaximumSplatters do
		if TextureBlood[i]:IsVisible() then
			TextureBloodFadingIterator[i] = 1
			TextureBloodTimers[i] = 0
		end
	end
end

function BloodyMask_RandomlyHideAllTextures(timeLenght)
	for i = 1, MaximumSplatters do
		if TextureBlood[i]:IsVisible() then
			TextureBloodFadingIterator[i] = 0
			TextureBloodTimers[i] = GetTime() - BaseUpTime + ((i * timeLenght) / MaximumSplatters)
		end
	end
end

function SortByOffsetAscending(a, b)
	if a.Offset ~= nil and b.Offset ~= nil then
		return a.Offset < b.Offset
	end
end

function SortByOffsetDescending(a, b)
	if a.Offset ~= nil and b.Offset ~= nil then
		return a.Offset > b.Offset
	end
end

function BloodyMask_HideAllTexturesFrom(timeLenght, direction, compare, start, step)
	Position = wipe(Position or {})
	local x = 1
	if timeLenght == nil then
		timeLenght = 1
	end
	if direction == nil then
		direction = "top"
	end
	if compare == nil then
		compare = "ascending"
	end
	if start == nil then
		start = 1
	end
	if step == nil then
		step = 1
	end
	direction = string.lower(direction)
	compare = string.lower(compare)
	for i = start, MaximumSplatters, step do
		Position[x] = {TextureNumber = nil, Offset = nil}
		if TextureBlood[i]:IsVisible() then
			Position[x].TextureNumber = i
			if direction == "top" then
				Position[x].Offset = TextureBlood[i]:GetTop()
			elseif direction == "bottom" then
				Position[x].Offset = TextureBlood[i]:GetBottom()
			elseif direction == "left" then
				Position[x].Offset = TextureBlood[i]:GetLeft()
			elseif direction == "right" then
				Position[x].Offset = TextureBlood[i]:GetRight()
			end
		end
		x = x + 1
	end
	if compare == "ascending" then
		tsort(Position, SortByOffsetAscending)
	elseif compare == "descending" then
		tsort(Position, SortByOffsetDescending)
	end
	for k, v in ipairs(Position) do
		if v.TextureNumber ~= nil then
			TextureBloodFadingIterator[v.TextureNumber] = 0
			TextureBloodTimers[v.TextureNumber] = GetTime() - BaseUpTime + ((k * timeLenght) / MaximumSplatters)
		end
	end
end

local TimeSinceLastUpdate = 0
function BloodyMask:TexturesOnUpdate(elapsed)
	-- https://wowwiki-archive.fandom.com/wiki/Using_OnUpdate_correctly
	TimeSinceLastUpdate = TimeSinceLastUpdate + elapsed
	if TimeSinceLastUpdate <= 0.1 then return end
	TimeSinceLastUpdate = 0

	for i = 1, MaximumSplatters do
		if ((TextureBloodTimers[i] > 0) or (TextureBlood[i]:IsVisible())) then
			if ((TextureBloodTimers[i] < GetTime() - BaseUpTime) and (TextureBloodFadingIterator[i] <= 0)) then
				TextureBloodTimers[i] = 0
				TextureBloodFadingIterator[i] = 1
			end
		end
	end
	BloodyMask:TexturesHide()
end

function BloodyMask:TexturesHide()
	for i = 1, MaximumSplatters do
		if ((TextureBloodFadingIterator[i] > 0) and (TextureBlood[i]:IsVisible())) then
			TextureBloodFadingIterator[i] = TextureBloodFadingIterator[i] + 1
			local MinIteratorValue = (FadingTime * GetFramerate()) / FadeOutSequences
			if (TextureBloodFadingIterator[i] > MinIteratorValue) then
				TextureBloodFadingIterator[i] = TextureBloodFadingIterator[i] - floor(MinIteratorValue)
				BloodyMask:TextureChangeAlpha(i)
			end
		end
	end
end

function BloodyMask:TextureChangeAlpha(i)
	if (TextureBloodAlpha[i] > FadeOutSequences) then
		TextureBloodTimers[i] = 0
		TextureBloodFadingIterator[i] = 0
		TextureBlood[i]:Hide()
		TextureBlood[i]:SetTexture(AddonPath .. "Textures\\" .. BloodyMaskVars.TextureBlood.Type .. "\\Blood" .. (((i - 1) % TextureTypes) + 1) .. "_1")
		TextureBlood[i]:SetWidth(BaseWidth)
		TextureBlood[i]:SetHeight(BaseHeight)
	else
		TextureBloodAlpha[i] = TextureBloodAlpha[i] + 1
		if TextureBloodAlpha[i] == 2 then
			TextureBlood[i]:SetTexture(AddonPath .. "Textures\\" .. BloodyMaskVars.TextureBlood.Type .. "\\Blood" .. (((i - 1) % TextureTypes) + 1) .. "_" .. TextureBloodAlpha[i])
		end
		TextureBlood[i]:SetWidth(TextureBlood[i]:GetWidth() * 1.02)
		TextureBlood[i]:SetHeight(TextureBlood[i]:GetHeight() * 1.02)
	end
end