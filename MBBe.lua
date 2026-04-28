local TARGET_ADDON = "MinimapButtonButton"
local MAIN_BUTTON_NAME = TARGET_ADDON .. "Button"
local LOGO_TEXTURE_PATH = "Interface\\AddOns\\MinimapButtonButton\\Media\\Logo.blp"

local STYLE_SIZE = {
  button = 31,
  ring = 50,
  icon = 18,
}

local ICON_TEX_COORD = {0, 1, 0, 1}
local MASK_TEXTURE_PATH = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local BACKDROP_PARTS = {
  "Center",
  "LeftEdge",
  "RightEdge",
  "TopEdge",
  "BottomEdge",
  "TopLeftCorner",
  "TopRightCorner",
  "BottomLeftCorner",
  "BottomRightCorner",
}

local menuFrame = CreateFrame("Frame", "MBBeContextMenu", UIParent, "UIDropDownMenuTemplate")

local function getDB()
  MBBeDB = MBBeDB or _G.MBBCircleDB or {}

  if MBBeDB.enabled == nil then
    MBBeDB.enabled = true
  end

  return MBBeDB
end

local function findMainButton()
  return _G[MAIN_BUTTON_NAME]
end

local function isTexture(region)
  return region and region.IsObjectType and region:IsObjectType("Texture")
end

local function setRegionState(region, alpha, shown)
  if not isTexture(region) then
    return
  end

  region:SetAlpha(alpha)
  if shown then
    region:Show()
  else
    region:Hide()
  end
end

local function isLogoTexture(region)
  if not isTexture(region) then
    return false
  end

  local texture = region:GetTexture()
  if type(texture) ~= "string" then
    return false
  end

  local normalized = texture:lower():gsub("\\", "/")
  return normalized:find("minimapbuttonbutton/media/logo", 1, true) ~= nil
end

local function saveOriginalVisual(mainButton)
  if mainButton.__mbbCircleOriginal then
    return
  end

  local original = {
    parts = {},
    logos = {},
  }

  if mainButton.GetBackdropColor then
    original.backdropColor = {mainButton:GetBackdropColor()}
  end

  if mainButton.GetBackdropBorderColor then
    original.backdropBorderColor = {mainButton:GetBackdropBorderColor()}
  end

  for _, partName in ipairs(BACKDROP_PARTS) do
    local tex = mainButton[partName]
    if isTexture(tex) then
      original.parts[partName] = {
        alpha = tex:GetAlpha(),
        shown = tex:IsShown(),
      }
    end
  end

  for _, region in ipairs({ mainButton:GetRegions() }) do
    if isLogoTexture(region) then
      original.logos[#original.logos + 1] = {
        region = region,
        alpha = region:GetAlpha(),
        shown = region:IsShown(),
      }
    end
  end

  mainButton.__mbbCircleOriginal = original
end

local function hideOriginalVisual(mainButton)
  saveOriginalVisual(mainButton)

  if mainButton.SetBackdropColor then
    mainButton:SetBackdropColor(0, 0, 0, 0)
  end

  if mainButton.SetBackdropBorderColor then
    mainButton:SetBackdropBorderColor(0, 0, 0, 0)
  end

  for _, partName in ipairs(BACKDROP_PARTS) do
    local tex = mainButton[partName]
    setRegionState(tex, 0, false)
  end

  for _, region in ipairs({ mainButton:GetRegions() }) do
    if isLogoTexture(region) then
      setRegionState(region, 0, false)
    end
  end
end

local function restoreOriginalVisual(mainButton)
  local original = mainButton.__mbbCircleOriginal
  if not original then
    return
  end

  if original.backdropColor and mainButton.SetBackdropColor then
    mainButton:SetBackdropColor(unpack(original.backdropColor))
  end

  if original.backdropBorderColor and mainButton.SetBackdropBorderColor then
    mainButton:SetBackdropBorderColor(unpack(original.backdropBorderColor))
  end

  for partName, state in pairs(original.parts) do
    setRegionState(mainButton[partName], state.alpha or 1, state.shown)
  end

  for _, logoState in ipairs(original.logos) do
    setRegionState(logoState.region, logoState.alpha or 1, logoState.shown)
  end
end

local function addMask(parent, texture)
  if not texture or type(texture.AddMaskTexture) ~= "function" then
    return
  end

  if texture.__mbbCircleMaskApplied then
    return
  end

  local mask = parent:CreateMaskTexture(nil, "ARTWORK")
  mask:SetTexture(MASK_TEXTURE_PATH)
  mask:SetPoint("TOPLEFT", texture, "TOPLEFT")
  mask:SetPoint("BOTTOMRIGHT", texture, "BOTTOMRIGHT")

  texture:AddMaskTexture(mask)
  texture.__mbbCircleMaskApplied = true
  texture.__mbbCircleMask = mask
end

local function ensureCircleVisual(mainButton)
  local visual = mainButton.__mbbCircleVisual
  if not visual then
    visual = CreateFrame("Frame", nil, mainButton)
    mainButton.__mbbCircleVisual = visual

    local ring = visual:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(136430) -- Interface\\Minimap\\MiniMap-TrackingBorder
    visual.ring = ring

    local icon = visual:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(LOGO_TEXTURE_PATH)
    icon:SetTexCoord(unpack(ICON_TEX_COORD))
    icon:SetVertexColor(1, 1, 1, 1)
    visual.icon = icon
  end

  visual:ClearAllPoints()
  visual:SetSize(STYLE_SIZE.button, STYLE_SIZE.button)
  visual:SetPoint("CENTER", mainButton, "CENTER", 0, 0)
  visual:SetFrameLevel(mainButton:GetFrameLevel() + 1)

  visual.ring:ClearAllPoints()
  visual.ring:SetPoint("TOPLEFT", visual, "TOPLEFT")
  visual.ring:SetSize(STYLE_SIZE.ring, STYLE_SIZE.ring)

  visual.icon:ClearAllPoints()
  visual.icon:SetPoint("CENTER", visual, "CENTER", 0, 0)
  visual.icon:SetSize(STYLE_SIZE.icon, STYLE_SIZE.icon)
  visual.icon:SetTexture(LOGO_TEXTURE_PATH)
  visual.icon:SetTexCoord(unpack(ICON_TEX_COORD))

  addMask(visual, visual.icon)
end

local function applyCurrentMode(mainButton)
  local db = getDB()

  if db.enabled then
    hideOriginalVisual(mainButton)
    ensureCircleVisual(mainButton)
    mainButton.__mbbCircleVisual:Show()
  else
    restoreOriginalVisual(mainButton)
    if mainButton.__mbbCircleVisual then
      mainButton.__mbbCircleVisual:Hide()
    end
  end
end

local function openTargetSettings()
  local function openAddOnsTab()
    if SettingsPanel and type(SettingsPanel.Open) == "function" then
      pcall(SettingsPanel.Open, SettingsPanel)
    end

    if SettingsPanel and SettingsPanel.AddOnsTab and type(SettingsPanel.AddOnsTab.Click) == "function" then
      pcall(SettingsPanel.AddOnsTab.Click, SettingsPanel.AddOnsTab)
    end
  end

  local settingsApi = Settings
  local candidates = { TARGET_ADDON, "mbb", "Minimap Button Button" }
  local canOpenCategory = settingsApi and type(settingsApi.OpenToCategory) == "function"

  local function openToCandidates()
    if not canOpenCategory then
      return
    end
    for _, candidate in ipairs(candidates) do
      pcall(settingsApi.OpenToCategory, candidate)
    end
  end

  if settingsApi and type(settingsApi.GetCategory) == "function" then
    local category = settingsApi.GetCategory(TARGET_ADDON)
    if category then
      if type(category.GetID) == "function" then
        table.insert(candidates, 1, category:GetID())
      elseif category.ID ~= nil then
        table.insert(candidates, 1, category.ID)
      end
      table.insert(candidates, 1, category)
    end
  end

  openAddOnsTab()

  if canOpenCategory then
    openToCandidates()
  elseif type(InterfaceOptionsFrame_OpenToCategory) == "function" then
    pcall(InterfaceOptionsFrame_OpenToCategory, TARGET_ADDON)
    pcall(InterfaceOptionsFrame_OpenToCategory, TARGET_ADDON)
  end

  C_Timer.After(0, function()
    openAddOnsTab()

    openToCandidates()

    if SettingsPanel and SettingsPanel.SearchBox and SettingsPanel.SearchBox.SetText then
      SettingsPanel.SearchBox:SetText(TARGET_ADDON)
    end
  end)
end

local function showContextMenu(mainButton)
  local db = getDB()

  local menu = {
    { text = "MBB Enhancements", isTitle = true, notCheckable = true },
    {
      text = "Use Circle Icon",
      checked = db.enabled,
      keepShownOnClick = true,
      func = function()
        db.enabled = not db.enabled
        applyCurrentMode(mainButton)
      end,
    },
    { text = "Open MinimapButtonButton Settings", notCheckable = true, func = openTargetSettings },
    { text = "Close", notCheckable = true, func = function() if CloseDropDownMenus then CloseDropDownMenus() end end },
  }

  if type(EasyMenu) == "function" then
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU", 2)
    return
  end

  if type(UIDropDownMenu_Initialize) == "function" and type(ToggleDropDownMenu) == "function" then
    UIDropDownMenu_Initialize(menuFrame, function(_, level)
      if level ~= 1 then
        return
      end

      for _, item in ipairs(menu) do
        UIDropDownMenu_AddButton(item, level)
      end
    end, "MENU")

    ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
    return
  end

  -- Last-resort fallback: right-click still toggles mode if menu APIs are unavailable.
  db.enabled = not db.enabled
  applyCurrentMode(mainButton)
end

local function installHooks(mainButton)
  if mainButton.__mbbCircleHooksApplied then
    return
  end

  mainButton.__mbbCircleHooksApplied = true

  hooksecurefunc(mainButton, "SetSize", function()
    applyCurrentMode(mainButton)
  end)

  mainButton:HookScript("OnMouseDown", function(self, button)
    if button == "RightButton" then
      showContextMenu(self)
    end
  end)
end

local function tryApply()
  local mainButton = findMainButton()
  if not mainButton then
    return false
  end

  installHooks(mainButton)
  applyCurrentMode(mainButton)
  return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event, addonName)
  if event == "ADDON_LOADED" and addonName ~= TARGET_ADDON and addonName ~= "MBBe" then
    return
  end

  getDB()

  if tryApply() then
    return
  end

  C_Timer.After(0, tryApply)
  C_Timer.After(0.2, tryApply)
  C_Timer.After(1, tryApply)
end)
