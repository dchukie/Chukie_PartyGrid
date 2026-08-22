local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME

local defaults = {
  enabled = false,
  unlocked = false,
  size = 34,
  spacing = 2,
  columns = 1,
  columnSpells = {},
  columnCycles = {},
  columnCycleUnits = {},
  columnSpacing = 2,
  growth = "RIGHT",
  gap = 8,
  offsetX = 0,
  offsetY = 0,
  orientation = "vertical",
  side = "RIGHT",
  attachToBlizzard = true,
  perUnitAnchor = true,
  hostFrameMode = "auto",
  hostFrameCustom = "",
  includePlayer = true,
  showHealth = true,
  showRole = true,
  useMasque = true,
  alphaPercent = 100,
  showSolo = false,
  point = { "CENTER", -320, 0 },
}

local function copyDefaults(dest, src)
  for key, value in pairs(src) do
    if type(value) == "table" then
      if type(dest[key]) ~= "table" then
        dest[key] = {}
      end
      copyDefaults(dest[key], value)
    elseif dest[key] == nil then
      dest[key] = value
    end
  end
end

local function initDB()
  ChukiePartyGridDB = type(ChukiePartyGridDB) == "table" and ChukiePartyGridDB or {}
  copyDefaults(ChukiePartyGridDB, defaults)
end

--[[ Dos pasadas a propósito. Al ejecutarse este archivo las SavedVariables todavía no
     están cargadas, así que el perfil que se completa acá es descartable: el juego
     reemplaza el global cuando lee el archivo guardado. La segunda pasada, en
     ADDON_LOADED, es la que de verdad completa un perfil viejo con las claves nuevas.
     La primera igual hace falta por si algo consulta el perfil antes de ese evento. ]]
initDB()

do
  local loader = CreateFrame("Frame")
  loader:RegisterEvent("ADDON_LOADED")
  loader:SetScript("OnEvent", function(self, _, addon)
    if addon ~= ADDON_NAME then
      return
    end
    initDB()
    self:UnregisterEvent("ADDON_LOADED")
  end)
end

ns.Profile = {}

function ns.Profile:GetActive()
  return {
    enabled = true,
    partyGrid = ChukiePartyGridDB,
  }
end

--- PartyGrid prohíbe incluso reparaciones de esquema durante combate: un perfil antiguo
--- se completa al cargar o en PLAYER_REGEN_ENABLED, nunca al consultarlo en pelea.
function ns.Profile:GetPartyGridModel()
  if InCombatLockdown() then
    return ChukiePartyGridDB
  end
  if type(ChukiePartyGridDB.columnSpells) ~= "table" then
    ChukiePartyGridDB.columnSpells = {}
  end
  if type(ChukiePartyGridDB.columnCycles) ~= "table" then
    ChukiePartyGridDB.columnCycles = {}
  end
  if type(ChukiePartyGridDB.columnCycleUnits) ~= "table" then
    ChukiePartyGridDB.columnCycleUnits = {}
  end
  if type(ChukiePartyGridDB.point) ~= "table" then
    ChukiePartyGridDB.point = { "CENTER", -320, 0 }
  end
  return ChukiePartyGridDB
end

do
  local CdInfo = {}
  ns.CdInfo = CdInfo

  local function isSecret(value)
    return issecretvalue and issecretvalue(value) or false
  end

  local function readBool(value)
    if value == nil or isSecret(value) then
      return nil
    end
    return value == true
  end

  function CdInfo.Derive(cdInfo, chargeInfo)
    local state = {
      cdActive = false,
      onGcd = false,
      hasCharges = false,
      maxCharges = nil,
      chargeActive = false,
      empty = false,
      count = nil,
    }
    if type(cdInfo) == "table" then
      state.onGcd = readBool(cdInfo.isOnGCD) == true
      local active = readBool(cdInfo.isActive)
      state.cdActive = active == true and readBool(cdInfo.isEnabled) ~= false and not state.onGcd
    end
    if type(chargeInfo) == "table" and not isSecret(chargeInfo.maxCharges) then
      local maxCharges = tonumber(chargeInfo.maxCharges)
      if maxCharges and maxCharges > 1 then
        state.hasCharges = true
        state.maxCharges = math.floor(maxCharges)
        local current
        if not isSecret(chargeInfo.currentCharges) then
          current = tonumber(chargeInfo.currentCharges)
        end
        local active = readBool(chargeInfo.isActive)
        if active == nil and current then
          active = current < state.maxCharges
        end
        state.chargeActive = active == true
        state.empty = state.chargeActive and state.cdActive
        if current then
          state.count = math.floor(current)
          state.empty = state.count <= 0
        elseif not state.chargeActive then
          state.count = state.maxCharges
        elseif state.empty then
          state.count = 0
        elseif state.maxCharges == 2 then
          state.count = 1
        end
      end
    end
    if not state.hasCharges then
      state.empty = state.cdActive
    end
    return state
  end
end

local function printHelp()
  print("|cff00ff00Chukie PartyGrid|r — comandos:")
  print("  |cffffffff/cpg|r  abre o cierra la ventana de configuración.")
  print("  |cffffffff/cpg settings|r  abre Opciones → AddOns → Chukie PartyGrid.")
  print("  |cffffffff/cpg on|r · |cffffffff/cpg off|r  activa o desactiva la grilla.")
  print("  |cffffffff/cpg diag|r  diagnóstico de frame, anclaje, ciclos y errores.")
  print("  Alias: |cffffffff/partygrid|r, |cffffffff/chukie-partygrid|r.")
end

ns.PrintHelp = printHelp

local function openConfig()
  local PG = ns.PartyGrid
  if PG then
    PG:ShowConfig()
  end
end

ns.OpenConfig = openConfig

local function command(text)
  local PG = ns.PartyGrid
  if not PG then
    print("|cffff9900Chukie PartyGrid|r: módulo no disponible.")
    return
  end
  local cmd = tostring(text or ""):match("^%s*(.-)%s*$"):lower()
  if cmd == "" then
    PG:ToggleConfig()
  elseif cmd == "on" then
    PG:SetEnabled(true)
  elseif cmd == "off" then
    PG:SetEnabled(false)
  elseif cmd == "diag" then
    PG:PrintDiagnostics()
  elseif cmd == "settings" or cmd == "opciones" then
    if ns.OpenSettings then
      ns.OpenSettings()
    else
      PG:ShowConfig()
    end
  elseif cmd == "config" or cmd == "ui" then
    PG:ShowConfig()
  elseif cmd == "help" or cmd == "ayuda" or cmd == "?" then
    printHelp()
  else
    --- Un argumento desconocido no abre nada: escribir mal el subcomando y ver la
    --- ventana igual hace pensar que se ejecutó lo que se pidió.
    print("|cffff9900Chukie PartyGrid|r: no conozco «" .. cmd .. "».")
    printHelp()
  end
end

SLASH_CHUKIEPARTYGRID1 = "/cpg"
SLASH_CHUKIEPARTYGRID2 = "/chukie-partygrid"
SLASH_CHUKIEPARTYGRID3 = "/partygrid"
SlashCmdList.CHUKIEPARTYGRID = command

--[[ Entrada en el compartimento de addons (el icono al lado del minimapa). PartyGrid es
     standalone: no aparece en la configuración de ElvUI ni de ningún otro addon, así que
     conviene que haya un acceso visible y no solo un slash que hay que recordar. ]]
function ChukiePartyGrid_OnAddonCompartmentClick(_, button)
  if button == "RightButton" then
    if ns.OpenSettings then
      ns.OpenSettings()
    else
      openConfig()
    end
    return
  end
  local PG = ns.PartyGrid
  if PG then
    PG:ToggleConfig()
  end
end

function ChukiePartyGrid_OnAddonCompartmentEnter(_, menuButton)
  GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
  GameTooltip:AddLine("Chukie PartyGrid")
  GameTooltip:AddLine("Clic izquierdo: ventana de configuración.", 1, 1, 1)
  GameTooltip:AddLine("Clic derecho: Opciones → AddOns.", 1, 1, 1)
  GameTooltip:AddLine("También: /cpg", 0.7, 0.7, 0.75)
  GameTooltip:Show()
end

function ChukiePartyGrid_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end
