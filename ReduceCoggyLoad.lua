-- ReduceCoggyLoad.lua
local ADDON_NAME = ...

-- =========================
-- CVars
-- =========================
local CVAR_DAMAGE = "floatingCombatTextCombatDamage"
local CVAR_HEAL   = "floatingCombatTextCombatHealing"

-- SavedVariables 
ReduceCoggyLoadDB = ReduceCoggyLoadDB

local function chat(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff70d6ff[ReduceCoggyLoad]|r " .. tostring(text))
end

-- =====================================
-- Combat Text apply helpers 
-- =====================================
local function applyCombatDamageText(disable)
  C_CVar.SetCVar(CVAR_DAMAGE, disable and "0" or "1")
  ReduceCoggyLoadDB.combatDamageTextDisabled = disable
  chat("Damage floating combat text: " .. (disable and "OFF" or "ON"))
end

local function applyCombatHealingText(disable)
  C_CVar.SetCVar(CVAR_HEAL, disable and "0" or "1")
  ReduceCoggyLoadDB.combatHealingTextDisabled = disable
  chat("Healing floating combat text: " .. (disable and "OFF" or "ON"))
end

-- =====================================
-- Aura visibility helpers
-- =====================================
-- Player auras use the global BuffFrame/DebuffFrame.
-- Target auras live on TargetFrame and are managed by frame pools.

-- Player Buffs/Debuffs
local function enforcePlayerAuraVisibility()
  if ReduceCoggyLoadDB.playerBuffsDisabled and BuffFrame then BuffFrame:Hide() else if BuffFrame then BuffFrame:Show() end end
  if ReduceCoggyLoadDB.playerDebuffsDisabled and DebuffFrame then DebuffFrame:Hide() else if DebuffFrame then DebuffFrame:Show() end end
end

local function setPlayerBuffsDisabled(disable)
  ReduceCoggyLoadDB.playerBuffsDisabled = disable and true or false
  enforcePlayerAuraVisibility()
  chat("Player BUFFS: " .. (disable and "HIDDEN" or "VISIBLE"))
end

local function setPlayerDebuffsDisabled(disable)
  ReduceCoggyLoadDB.playerDebuffsDisabled = disable and true or false
  enforcePlayerAuraVisibility()
  chat("Player DEBUFFS: " .. (disable and "HIDDEN" or "VISIBLE"))
end

-- Target Buffs/Debuffs 
local function hideTargetAuraPool(poolName, self)
  if not (self and self.auraPools) then return end
  local pool = self.auraPools:GetPool(poolName)
  if not pool then return end
  for button in pool:EnumerateActive() do
    button:Hide()
  end
end

local function targetAurasHook(self)
  if ReduceCoggyLoadDB.targetBuffsDisabled then
    hideTargetAuraPool("TargetBuffFrameTemplate", self)
  end
  if ReduceCoggyLoadDB.targetDebuffsDisabled then
    hideTargetAuraPool("TargetDebuffFrameTemplate", self)
  end
end

local function setTargetBuffsDisabled(disable)
  ReduceCoggyLoadDB.targetBuffsDisabled = disable and true or false
  if TargetFrame and TargetFrame.UpdateAuras then TargetFrame:UpdateAuras() end
  chat("Target BUFFS: " .. (disable and "HIDDEN" or "VISIBLE"))
end

local function setTargetDebuffsDisabled(disable)
  ReduceCoggyLoadDB.targetDebuffsDisabled = disable and true or false
  if TargetFrame and TargetFrame.UpdateAuras then TargetFrame:UpdateAuras() end
  chat("Target DEBUFFS: " .. (disable and "HIDDEN" or "VISIBLE"))
end

local playerAuraEnforcer = CreateFrame("Frame")
playerAuraEnforcer:RegisterEvent("PLAYER_ENTERING_WORLD")
playerAuraEnforcer:RegisterEvent("UNIT_AURA")
playerAuraEnforcer:SetScript("OnEvent", function(_, event, unit)
  if event == "UNIT_AURA" and unit ~= "player" then return end
  enforcePlayerAuraVisibility()
end)

-- Hook the target frame’s aura refresh so hide/show sticks
hooksecurefunc(TargetFrame, "UpdateAuras", targetAurasHook) 

-- =====================================
-- Apply everything from DB
-- =====================================
local function applyAllFromDB()
  applyCombatDamageText(ReduceCoggyLoadDB.combatDamageTextDisabled)
  applyCombatHealingText(ReduceCoggyLoadDB.combatHealingTextDisabled)

  setPlayerBuffsDisabled(ReduceCoggyLoadDB.playerBuffsDisabled)
  setPlayerDebuffsDisabled(ReduceCoggyLoadDB.playerDebuffsDisabled)

  setTargetBuffsDisabled(ReduceCoggyLoadDB.targetBuffsDisabled)
  setTargetDebuffsDisabled(ReduceCoggyLoadDB.targetDebuffsDisabled)
end

-- =====================================
-- Seed / migrate settings
-- =====================================
local function migrateAndSeed()
  ReduceCoggyLoadDB = ReduceCoggyLoadDB or {}

  if ReduceCoggyLoadDB.combatDamageTextDisabled  == nil then ReduceCoggyLoadDB.combatDamageTextDisabled  = (GetCVar(CVAR_DAMAGE) == "0") end
  if ReduceCoggyLoadDB.combatHealingTextDisabled == nil then ReduceCoggyLoadDB.combatHealingTextDisabled = (GetCVar(CVAR_HEAL)   == "0") end

  if ReduceCoggyLoadDB.playerBuffsDisabled   == nil then ReduceCoggyLoadDB.playerBuffsDisabled   = false end
  if ReduceCoggyLoadDB.playerDebuffsDisabled == nil then ReduceCoggyLoadDB.playerDebuffsDisabled = false end
  if ReduceCoggyLoadDB.targetBuffsDisabled   == nil then ReduceCoggyLoadDB.targetBuffsDisabled   = false end
  if ReduceCoggyLoadDB.targetDebuffsDisabled == nil then ReduceCoggyLoadDB.targetDebuffsDisabled = false end
end

-- =====================================
-- Options UI (3 sections)
-- =====================================
local damageCB, healingCB
local tDebuffsCB, pDebuffsCB
local tBuffsCB, pBuffsCB

local function addSectionHeader(parent, label, anchor, yOffset)
  local hdr = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  hdr:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset or -16)
  hdr:SetText(label)
  return hdr
end

local function buildOptionsPanel()
  local panel = CreateFrame("Frame", "ReduceCoggyLoadOptions", UIParent)
  panel.name = "ReduceCoggyLoad"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Reduce Coggy Load")

  -- === Combat Text section ===
  local combatHdr = addSectionHeader(panel, "Combat Text", title, -8)

  damageCB = CreateFrame("CheckButton", "ReduceCoggyLoad_DamageCB", panel, "InterfaceOptionsCheckButtonTemplate")
  damageCB:SetPoint("TOPLEFT", combatHdr, "BOTTOMLEFT", 0, -10)
  damageCB.Text:SetText("Disable DAMAGE floating combat text")
  damageCB:SetChecked(ReduceCoggyLoadDB.combatDamageTextDisabled)
  damageCB:SetScript("OnClick", function(self) applyCombatDamageText(self:GetChecked()) end)

  healingCB = CreateFrame("CheckButton", "ReduceCoggyLoad_HealingCB", panel, "InterfaceOptionsCheckButtonTemplate")
  healingCB:SetPoint("TOPLEFT", damageCB, "BOTTOMLEFT", 0, -8)
  healingCB.Text:SetText("Disable HEALING floating combat text")
  healingCB:SetChecked(ReduceCoggyLoadDB.combatHealingTextDisabled)
  healingCB:SetScript("OnClick", function(self) applyCombatHealingText(self:GetChecked()) end)

  -- === Debuffs section ===
  local debuffHdr = addSectionHeader(panel, "Debuffs", healingCB, -14)

  tDebuffsCB = CreateFrame("CheckButton", "ReduceCoggyLoad_TargetDebuffsCB", panel, "InterfaceOptionsCheckButtonTemplate")
  tDebuffsCB:SetPoint("TOPLEFT", debuffHdr, "BOTTOMLEFT", 0, -10)
  tDebuffsCB.Text:SetText("Hide TARGET Debuffs")
  tDebuffsCB:SetChecked(ReduceCoggyLoadDB.targetDebuffsDisabled)
  tDebuffsCB:SetScript("OnClick", function(self) setTargetDebuffsDisabled(self:GetChecked()) end)

  pDebuffsCB = CreateFrame("CheckButton", "ReduceCoggyLoad_PlayerDebuffsCB", panel, "InterfaceOptionsCheckButtonTemplate")
  pDebuffsCB:SetPoint("TOPLEFT", tDebuffsCB, "BOTTOMLEFT", 0, -8)
  pDebuffsCB.Text:SetText("Hide PLAYER Debuffs")
  pDebuffsCB:SetChecked(ReduceCoggyLoadDB.playerDebuffsDisabled)
  pDebuffsCB:SetScript("OnClick", function(self) setPlayerDebuffsDisabled(self:GetChecked()) end)

  -- === Buffs section ===
  local buffHdr = addSectionHeader(panel, "Buffs", pDebuffsCB, -14)

  tBuffsCB = CreateFrame("CheckButton", "ReduceCoggyLoad_TargetBuffsCB", panel, "InterfaceOptionsCheckButtonTemplate")
  tBuffsCB:SetPoint("TOPLEFT", buffHdr, "BOTTOMLEFT", 0, -10)
  tBuffsCB.Text:SetText("Hide TARGET Buffs")
  tBuffsCB:SetChecked(ReduceCoggyLoadDB.targetBuffsDisabled)
  tBuffsCB:SetScript("OnClick", function(self) setTargetBuffsDisabled(self:GetChecked()) end)

  pBuffsCB = CreateFrame("CheckButton", "ReduceCoggyLoad_PlayerBuffsCB", panel, "InterfaceOptionsCheckButtonTemplate")
  pBuffsCB:SetPoint("TOPLEFT", tBuffsCB, "BOTTOMLEFT", 0, -8)
  pBuffsCB.Text:SetText("Hide PLAYER Buffs")
  pBuffsCB:SetChecked(ReduceCoggyLoadDB.playerBuffsDisabled)
  pBuffsCB:SetScript("OnClick", function(self) setPlayerBuffsDisabled(self:GetChecked()) end)

  -- New Settings API (Retail)
  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    category.ID = panel.name
    Settings.RegisterAddOnCategory(category)
  end
  -- Legacy shim
  if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

-- =====================================
-- Slash commands
-- =====================================
local function openOptions()
  if Settings and Settings.OpenToCategory then
    Settings.OpenToCategory("ReduceCoggyLoad")
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory("ReduceCoggyLoad")
  end
end

local function parseBoolWord(w)
  if w == "on" then return false end      -- "on" => visible/enabled (not disabled)
  if w == "off" then return true end      -- "off" => disabled/hidden
  if w == "toggle" then return "toggle" end
  return nil
end

local function handleSlash(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "" or msg == "status" then
    chat(("CombatText (Dmg/Heal): %s / %s  |  Target (Debuff/Buff): %s / %s  |  Player (Debuff/Buff): %s / %s"):format(
      ReduceCoggyLoadDB.combatDamageTextDisabled  and "OFF" or "ON",
      ReduceCoggyLoadDB.combatHealingTextDisabled and "OFF" or "ON",
      ReduceCoggyLoadDB.targetDebuffsDisabled     and "HID" or "VIS",
      ReduceCoggyLoadDB.targetBuffsDisabled       and "HID" or "VIS",
      ReduceCoggyLoadDB.playerDebuffsDisabled     and "HID" or "VIS",
      ReduceCoggyLoadDB.playerBuffsDisabled       and "HID" or "VIS"
    ))
    chat("Usage:")
    chat("  /rcl damage on|off|toggle   /rcl healing on|off|toggle")
    chat("  /rcl tdebuffs on|off|toggle /rcl tbuffs on|off|toggle")
    chat("  /rcl pdebuffs on|off|toggle /rcl pbuffs on|off|toggle")
    chat("  /rcl on|off (affects both combat text toggles)   /rcl ui")
    return
  end

  local a, b = msg:match("^(%S+)%s*(%S*)$")
  if a == "ui" then openOptions(); return end

  local function applyToggle(which, val)
    if val == "toggle" then
      if which == "damage"   then applyCombatDamageText(not ReduceCoggyLoadDB.combatDamageTextDisabled)
      elseif which == "healing"  then applyCombatHealingText(not ReduceCoggyLoadDB.combatHealingTextDisabled)
      elseif which == "tdebuffs" then setTargetDebuffsDisabled(not ReduceCoggyLoadDB.targetDebuffsDisabled)
      elseif which == "tbuffs"   then setTargetBuffsDisabled(not ReduceCoggyLoadDB.targetBuffsDisabled)
      elseif which == "pdebuffs" then setPlayerDebuffsDisabled(not ReduceCoggyLoadDB.playerDebuffsDisabled)
      elseif which == "pbuffs"   then setPlayerBuffsDisabled(not ReduceCoggyLoadDB.playerBuffsDisabled)
      end
    else
      if which == "damage"   then applyCombatDamageText(val)
      elseif which == "healing"  then applyCombatHealingText(val)
      elseif which == "tdebuffs" then setTargetDebuffsDisabled(val)
      elseif which == "tbuffs"   then setTargetBuffsDisabled(val)
      elseif which == "pdebuffs" then setPlayerDebuffsDisabled(val)
      elseif which == "pbuffs"   then setPlayerBuffsDisabled(val)
      end
    end
  end

  local v = parseBoolWord(b)

  if a == "damage" or a == "healing" or a == "tdebuffs" or a == "tbuffs" or a == "pdebuffs" or a == "pbuffs" then
    if v == nil then chat("Use: /rcl "..a.." on|off|toggle"); return end
    applyToggle(a, v)
    -- keep UI checkboxes in sync if panel is open
    if damageCB  and a == "damage"   then damageCB:SetChecked(ReduceCoggyLoadDB.combatDamageTextDisabled) end
    if healingCB and a == "healing"  then healingCB:SetChecked(ReduceCoggyLoadDB.combatHealingTextDisabled) end
    if tDebuffsCB and a == "tdebuffs" then tDebuffsCB:SetChecked(ReduceCoggyLoadDB.targetDebuffsDisabled) end
    if tBuffsCB   and a == "tbuffs"   then tBuffsCB:SetChecked(ReduceCoggyLoadDB.targetBuffsDisabled)   end
    if pDebuffsCB and a == "pdebuffs" then pDebuffsCB:SetChecked(ReduceCoggyLoadDB.playerDebuffsDisabled) end
    if pBuffsCB   and a == "pbuffs"   then pBuffsCB:SetChecked(ReduceCoggyLoadDB.playerBuffsDisabled)   end
    return
  end

  if a == "on" or a == "off" then
    local disable = (a == "off")
    applyCombatDamageText(disable)
    applyCombatHealingText(disable)
    if damageCB then damageCB:SetChecked(ReduceCoggyLoadDB.combatDamageTextDisabled) end
    if healingCB then healingCB:SetChecked(ReduceCoggyLoadDB.combatHealingTextDisabled) end
    return
  end

  chat("Unknown command. Try /rcl, /rcl ui, /rcl damage|healing|tdebuffs|tbuffs|pdebuffs|pbuffs on|off|toggle")
end

-- =====================================
-- Events
-- =====================================
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    migrateAndSeed()
    buildOptionsPanel()
    SLASH_REDUCECOGGYLOAD1 = "/rcl"
    SlashCmdList.REDUCECOGGYLOAD = handleSlash
  elseif event == "PLAYER_LOGIN" then
    applyAllFromDB()
  end
end)
