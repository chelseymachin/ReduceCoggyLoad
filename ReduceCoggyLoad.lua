-- ReduceCoggyLoad.lua
local ADDON_NAME = ...

-- CVars we toggle (same as your /console commands)
local CVAR_DAMAGE = "floatingCombatTextCombatDamage"
local CVAR_HEAL   = "floatingCombatTextCombatHealing"

-- SavedVariables (declared in TOC)
ReduceCoggyLoadDB = ReduceCoggyLoadDB

local function chat(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff70d6ff[ReduceCoggyLoad]|r " .. tostring(text))
end

local function applyCombatText(disable)
  local v = disable and "0" or "1"
  C_CVar.SetCVar(CVAR_DAMAGE, v)
  C_CVar.SetCVar(CVAR_HEAL,   v)
  ReduceCoggyLoadDB.disabled = disable
  chat("Floating combat text: " .. (disable and "OFF" or "ON"))
end

local function seedFromCurrentCVarsIfUnset()
  if ReduceCoggyLoadDB.disabled ~= nil then return end
  local dmg  = GetCVar(CVAR_DAMAGE)
  local heal = GetCVar(CVAR_HEAL)
  ReduceCoggyLoadDB.disabled = (dmg == "0" and heal == "0")
end

local function buildOptionsPanel()
  local panel = CreateFrame("Frame", "ReduceCoggyLoadOptions", UIParent)
  panel.name = "ReduceCoggyLoad"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("ReduceCoggyLoad")

  local cb = CreateFrame("CheckButton", "ReduceCoggyLoad_Checkbox", panel, "InterfaceOptionsCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  cb.Text:SetText("Disable floating combat text (damage + healing)")
  cb:SetChecked(ReduceCoggyLoadDB.disabled)

  cb:SetScript("OnClick", function(self)
    applyCombatText(self:GetChecked())
  end)

  -- New Settings API (Retail)
  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    category.ID = panel.name
    Settings.RegisterAddOnCategory(category)
  end

  -- Legacy options (Classic / older)
  if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

-- Event bootstrap: init on ADDON_LOADED, apply on PLAYER_LOGIN
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    ReduceCoggyLoadDB = ReduceCoggyLoadDB or { disabled = false }
    seedFromCurrentCVarsIfUnset()
    buildOptionsPanel()

    -- /rcl on | /rcl off | /rcl ui
    SLASH_REDUCECOGGYLOAD1 = "/rcl"
    SlashCmdList.REDUCECOGGYLOAD = function(msg)
      msg = (msg or ""):lower():match("^%s*(.-)%s*$")
      if msg == "on" then
        applyCombatText(false)
      elseif msg == "off" then
        applyCombatText(true)
      elseif msg == "ui" then
        if Settings and Settings.OpenToCategory then
          Settings.OpenToCategory("ReduceCoggyLoad")
        elseif InterfaceOptionsFrame_OpenToCategory then
          InterfaceOptionsFrame_OpenToCategory("ReduceCoggyLoad")
        end
      else
        local state = ReduceCoggyLoadDB.disabled and "OFF" or "ON"
        chat("Floating combat text is " .. state .. ". Use /rcl on | /rcl off | /rcl ui")
      end
    end
  elseif event == "PLAYER_LOGIN" then
    applyCombatText(ReduceCoggyLoadDB.disabled)
  end
end)