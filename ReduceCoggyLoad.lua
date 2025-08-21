-- ReduceCoggyLoad.lua
local ADDON_NAME = ...

-- CVars we control
local CVAR_DAMAGE = "floatingCombatTextCombatDamage"
local CVAR_HEAL   = "floatingCombatTextCombatHealing"

-- SavedVariables declared in TOC
ReduceCoggyLoadDB = ReduceCoggyLoadDB

local function chat(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff70d6ff[ReduceCoggyLoad]|r " .. tostring(text))
end

-- Apply helpers
local function applyCombatDamageText(disable)
  C_CVar.SetCVar(CVAR_DAMAGE, disable and "0" or "1")
  ReduceCoggyLoadDB.combatDamageTextDisabled = disable
  chat("Damage floating combat text: " .. (disable and "OFF" or "ON"))
end

local function applyHealingDamageText(disable)
  C_CVar.SetCVar(CVAR_HEAL, disable and "0" or "1")
  ReduceCoggyLoadDB.combatHealingTextDisabled = disable
  chat("Healing floating combat text: " .. (disable and "OFF" or "ON"))
end

local function applyAllFromDB()
  applyCombatDamageText(ReduceCoggyLoadDB.combatDamageTextDisabled)
  applyHealingDamageText(ReduceCoggyLoadDB.combatHealingTextDisabled)
end

-- Seed / migrate settings
local function migrateAndSeed()
  ReduceCoggyLoadDB = ReduceCoggyLoadDB or {}

  -- Migrate old single toggle, if present
  if ReduceCoggyLoadDB.disabled ~= nil then
    local both = ReduceCoggyLoadDB.disabled and true or false
    ReduceCoggyLoadDB.combatDamageTextDisabled = (ReduceCoggyLoadDB.combatDamageTextDisabled ~= nil) and ReduceCoggyLoadDB.combatDamageTextDisabled or both
    ReduceCoggyLoadDB.combatHealingTextDisabled = (ReduceCoggyLoadDB.combatHealingTextDisabled ~= nil) and ReduceCoggyLoadDB.combatHealingTextDisabled or both
    ReduceCoggyLoadDB.disabled = nil
  end

  -- If either is unset, infer from current CVars
  if ReduceCoggyLoadDB.combatDamageTextDisabled == nil then
    ReduceCoggyLoadDB.combatDamageTextDisabled = (GetCVar(CVAR_DAMAGE) == "0")
  end
  if ReduceCoggyLoadDB.combatHealingTextDisabled == nil then
    ReduceCoggyLoadDB.combatHealingTextDisabled = (GetCVar(CVAR_HEAL) == "0")
  end
end

-- UI: options panel with two checkboxes
local damageCB, healingCB
local function buildOptionsPanel()
  local panel = CreateFrame("Frame", "ReduceCoggyLoadOptions", UIParent)
  panel.name = "ReduceCoggyLoad"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Reduce Coggy Load")

  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  sub:SetText("Individually disable floating combat text:")

  damageCB = CreateFrame("CheckButton", "ReduceCoggyLoad_DamageCB", panel, "InterfaceOptionsCheckButtonTemplate")
  damageCB:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -12)
  damageCB.Text:SetText("Disable DAMAGE floating combat text")
  damageCB:SetChecked(ReduceCoggyLoadDB.combatDamageTextDisabled)
  damageCB:SetScript("OnClick", function(self) applyCombatDamageText(self:GetChecked()) end)

  healingCB = CreateFrame("CheckButton", "ReduceCoggyLoad_HealingCB", panel, "InterfaceOptionsCheckButtonTemplate")
  healingCB:SetPoint("TOPLEFT", damageCB, "BOTTOMLEFT", 0, -10)
  healingCB.Text:SetText("Disable HEALING floating combat text")
  healingCB:SetChecked(ReduceCoggyLoadDB.combatHealingTextDisabled)
  healingCB:SetScript("OnClick", function(self) applyHealingDamageText(self:GetChecked()) end)

  -- New Settings API (Retail)
  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    category.ID = panel.name
    Settings.RegisterAddOnCategory(category)
  end

  -- Legacy shim (Classic/older)
  if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

-- Slash commands
local function openOptions()
  if Settings and Settings.OpenToCategory then
    Settings.OpenToCategory("ReduceCoggyLoad")
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory("ReduceCoggyLoad")
  end
end

local function parseBoolWord(w)
  if w == "on" then return false end      -- "on" means enabled (not disabled)
  if w == "off" then return true end      -- "off" means disabled
  if w == "toggle" then return "toggle" end
  return nil
end

local function handleSlash(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "" or msg == "status" then
    chat(("Damage: %s, Healing: %s"):format(
      ReduceCoggyLoadDB.combatDamageTextDisabled and "OFF" or "ON",
      ReduceCoggyLoadDB.combatHealingTextDisabled and "OFF" or "ON"))
    chat("Usage: /rcl damage on|off|toggle  |  /rcl healing on|off|toggle  |  /rcl on|off  |  /rcl ui")
    return
  end

  local a, b = msg:match("^(%S+)%s*(%S*)$")
  if a == "ui" then
    openOptions()
    return
  end

  if a == "damage" or a == "healing" then
    local v = parseBoolWord(b)
    if v == nil then
      chat("Use: /rcl " .. a .. " on|off|toggle")
      return
    end
    if v == "toggle" then
      if a == "damage" then
        applyCombatDamageText(not ReduceCoggyLoadDB.combatDamageTextDisabled)
        if damageCB then damageCB:SetChecked(ReduceCoggyLoadDB.combatDamageTextDisabled) end
      else
        applyHealingDamageText(not ReduceCoggyLoadDB.combatHealingTextDisabled)
        if healingCB then healingCB:SetChecked(ReduceCoggyLoadDB.combatHealingTextDisabled) end
      end
    else
      if a == "damage" then
        applyCombatDamageText(v)
        if damageCB then damageCB:SetChecked(v) end
      else
        applyHealingDamageText(v)
        if healingCB then healingCB:SetChecked(v) end
      end
    end
    return
  end

  if a == "on" or a == "off" then
    local disable = (a == "off")
    applyCombatDamageText(disable)
    applyHealingDamageText(disable)
    if damageCB then damageCB:SetChecked(ReduceCoggyLoadDB.combatDamageTextDisabled) end
    if healingCB then healingCB:SetChecked(ReduceCoggyLoadDB.combatHealingTextDisabled) end
    return
  end

  chat("Unknown command. Try /rcl, /rcl ui, /rcl damage on|off|toggle, /rcl healing on|off|toggle, /rcl on|off")
end

-- Events
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    migrateAndSeed()
    buildOptionsPanel()
    -- Slash registration
    SLASH_REDUCECOGGYLOAD1 = "/rcl"
    SlashCmdList.REDUCECOGGYLOAD = handleSlash
  elseif event == "PLAYER_LOGIN" then
    applyAllFromDB()
    -- Sync UI if already built
    if damageCB then damageCB:SetChecked(ReduceCoggyLoadDB.combatDamageTextDisabled) end
    if healingCB then healingCB:SetChecked(ReduceCoggyLoadDB.combatHealingTextDisabled) end
  end
end)
