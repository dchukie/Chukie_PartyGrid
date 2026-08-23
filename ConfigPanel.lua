local ADDON_NAME, ns = ...

local category

local function PG()
  return ns.PartyGrid
end

local function db()
  return PG() and PG():DB() or ChukiePartyGridDB
end

local function register(setting, getter)
  if PG() and PG().RegisterSetting then
    PG():RegisterSetting(setting, getter)
  end
  return setting
end

local function addBool(layoutCategory, uniqueId, key, label, tooltip, defaultOn, enabledSetter)
  local function get()
    local value = db()[key]
    if value == nil then
      return defaultOn == true
    end
    return value == true
  end
  local function set(value)
    if PG():SettingsLocked() then
      return
    end
    if enabledSetter then
      PG():SetEnabled(value == true or value == 1)
    else
      PG():SetOption(key, value == true or value == 1, "refresh")
    end
  end
  local setting = Settings.RegisterProxySetting(
    layoutCategory,
    uniqueId,
    Settings.VarType.Boolean,
    label,
    defaultOn and Settings.Default.True or Settings.Default.False,
    get,
    set
  )
  register(setting, get)
  Settings.CreateCheckbox(layoutCategory, setting, tooltip)
end

local function addNumber(layoutCategory, uniqueId, key, label, tooltip, minValue, maxValue, step, defaultValue)
  local function get()
    local value = tonumber(db()[key]) or defaultValue
    return math.max(minValue, math.min(maxValue, value))
  end
  local function set(value)
    if PG():SettingsLocked() then
      return
    end
    PG():SetOption(key, math.floor((tonumber(value) or defaultValue) + 0.5), "layout")
  end
  local setting = Settings.RegisterProxySetting(
    layoutCategory,
    uniqueId,
    Settings.VarType.Number,
    label,
    defaultValue,
    get,
    set
  )
  register(setting, get)
  Settings.CreateSlider(
    layoutCategory,
    setting,
    Settings.CreateSliderOptions(minValue, maxValue, step),
    tooltip
  )
end

local function addList(layoutCategory, uniqueId, key, label, tooltip, values, labels, defaultValue)
  local function data()
    local container = Settings.CreateControlTextContainer()
    for index = 1, #values do
      container:Add(index, labels[values[index]] or values[index])
    end
    return container:GetData()
  end
  local function get()
    local current = db()[key] or defaultValue
    for index = 1, #values do
      if values[index] == current then
        return index
      end
    end
    return 1
  end
  local function set(index)
    if PG():SettingsLocked() then
      return
    end
    PG():SetOption(key, values[tonumber(index) or 1] or defaultValue, "layout")
  end
  local setting = Settings.RegisterProxySetting(
    layoutCategory,
    uniqueId,
    Settings.VarType.Number,
    label,
    1,
    get,
    set
  )
  register(setting, get)
  Settings.CreateDropdown(layoutCategory, setting, data, tooltip)
end

local function addText(layoutCategory, uniqueId, key, label, tooltip, defaultValue)
  local function get()
    return tostring(db()[key] or defaultValue or "")
  end
  local function set(value)
    if PG():SettingsLocked() then
      return
    end
    PG():SetOption(key, tostring(value or ""), "layout")
  end
  local setting = Settings.RegisterProxySetting(
    layoutCategory,
    uniqueId,
    Settings.VarType.String,
    label,
    defaultValue or "",
    get,
    set
  )
  register(setting, get)
  Settings.CreateTextBox(layoutCategory, setting, tooltip)
end

local function addColumnSpell(layoutCategory, column)
  local function get()
    local spellId = PG():ColumnSpell(column)
    if not spellId then
      return ""
    end
    local info
    if C_Spell and C_Spell.GetSpellInfo then
      local ok, value = pcall(C_Spell.GetSpellInfo, spellId)
      info = ok and value or nil
    end
    return (type(info) == "table" and info.name) or tostring(spellId)
  end
  local function set(value)
    if PG():SettingsLocked() or value == get() then
      return
    end
    PG():SetColumnSpellInput(column, value)
  end
  local setting = Settings.RegisterProxySetting(
    layoutCategory,
    "ChukiePartyGrid_ColumnSpell" .. column,
    Settings.VarType.String,
    "Columna " .. column .. ": hechizo",
    "",
    get,
    set
  )
  register(setting, get)
  Settings.CreateTextBox(
    layoutCategory,
    setting,
    "Nombre exacto o ID del hechizo; vacío limpia la columna. También podés arrastrarlo desde el libro a una celda."
  )
end

local function addColumnCycle(layoutCategory, column)
  local function get()
    return PG():IsCycleColumn(column) == true
  end
  local function set(value)
    if PG():SettingsLocked() then
      return
    end
    PG():SetColumnCycle(column, value == true or value == 1)
  end
  local setting = Settings.RegisterProxySetting(
    layoutCategory,
    "ChukiePartyGrid_ColumnCycle" .. column,
    Settings.VarType.Boolean,
    "Columna " .. column .. ": usar como ciclo",
    Settings.Default.False,
    get,
    set
  )
  register(setting, get)
  Settings.CreateCheckbox(
    layoutCategory,
    setting,
    "Publica una acción /click que recorre los jugadores incluidos. Fuera de combate, clic derecho sobre una celda incluye o excluye a ese jugador."
  )
end

--- Solo lectura: la línea existe para copiarla a una macro. La lista de unidades no se
--- edita acá porque se arma con clic derecho sobre la propia grilla.
local function addColumnCycleAction(layoutCategory, column)
  local function get()
    local action = PG():CycleActionName(column)
    if not action then
      return "(activá ciclo y asigná un hechizo)"
    end
    return "/click " .. action
  end
  local function set(value)
    if PG():SettingsLocked() or value == get() then
      return
    end
    print("|cffff9900Chukie PartyGrid|r: copiá esa línea a una macro; la lista se edita con clic derecho en la grilla.")
    PG():RefreshSettings()
  end
  local setting = Settings.RegisterProxySetting(
    layoutCategory,
    "ChukiePartyGrid_ColumnCycleAction" .. column,
    Settings.VarType.String,
    "Columna " .. column .. ": macro del ciclo",
    "",
    get,
    set
  )
  register(setting, get)
  Settings.CreateTextBox(
    layoutCategory,
    setting,
    "Copiá esta línea completa a una macro. Las celdas prendidas muestran las unidades incluidas."
  )
end

local function registerPanel()
  if category or not Settings or not Settings.RegisterVerticalLayoutCategory then
    return
  end
  category = Settings.RegisterVerticalLayoutCategory("Chukie PartyGrid")
  category.ID = "ChukiePartyGrid_Settings"
  local layout = SettingsPanel:GetLayout(category)

  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General"))
  addBool(category, "ChukiePartyGrid_Enabled", "enabled", "Activar grilla", "Muestra la grilla clickeable.", false, true)
  addNumber(category, "ChukiePartyGrid_Size", "size", "Tamaño de celda", "Lado de cada celda.", 16, 100, 1, 34)
  addNumber(category, "ChukiePartyGrid_Spacing", "spacing", "Separación de jugadores", "Espacio entre filas.", 0, 20, 1, 2)
  addNumber(category, "ChukiePartyGrid_Columns", "columns", "Columnas por jugador", "Una habilidad distinta por columna.", 1, 8, 1, 1)
  addNumber(category, "ChukiePartyGrid_ColumnSpacing", "columnSpacing", "Separación de columnas", "Espacio entre habilidades.", 0, 20, 1, 2)
  addNumber(category, "ChukiePartyGrid_Alpha", "alphaPercent", "Opacidad", "Opacidad del conjunto.", 10, 100, 5, 100)

  addList(category, "ChukiePartyGrid_Growth", "growth", "Crecimiento de columnas", "Dirección de las habilidades.", PG().GROWTHS, PG().GROWTH_LABELS, "RIGHT")
  addList(category, "ChukiePartyGrid_Orientation", "orientation", "Orientación de jugadores", "Se usa cuando no hay filas detectables.", PG().ORIENTATIONS, PG().ORIENTATION_LABELS, "vertical")

  addBool(category, "ChukiePartyGrid_Player", "includePlayer", "Incluir jugador", "Incluye player además de party1..4.", true)
  addBool(category, "ChukiePartyGrid_Health", "showHealth", "Barra de vida", "Muestra vida bajo el icono.", true)
  addBool(category, "ChukiePartyGrid_Role", "showRole", "Icono de rol", "Muestra tank/healer/dps.", true)
  addBool(category, "ChukiePartyGrid_Masque", "useMasque", "Usar Masque", "Grupo Chukie PartyGrid → PartyGrid.", true)

  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Frame de anclaje"))
  addBool(
    category,
    "ChukiePartyGrid_Attach",
    "attachToBlizzard",
    "Pegada a un frame",
    "Desmarcado: posición libre y arrastrable desde /cpg.",
    true
  )
  addList(
    category,
    "ChukiePartyGrid_HostMode",
    "hostFrameMode",
    "Frame objetivo",
    "Automático prioriza ElvUI. Los modos explícitos esperan ese frame sin caer en otro.",
    PG().HOST_FRAME_MODES,
    PG().HOST_FRAME_LABELS,
    "auto"
  )
  addText(
    category,
    "ChukiePartyGrid_HostCustom",
    "hostFrameCustom",
    "Nombre global personalizado",
    "Ejemplo: ElvUF_Party. Sólo se usa con «Nombre global personalizado».",
    ""
  )
  addBool(
    category,
    "ChukiePartyGrid_PerUnitAnchor",
    "perUnitAnchor",
    "Anclar a cada jugador",
    "Cada grupo de celdas se pega al marco de su propio jugador. Sin esto, la grilla se ancla como un bloque único al conjunto.",
    true
  )
  addList(category, "ChukiePartyGrid_Side", "side", "Lado", "Lado del marco de cada jugador donde se colocan las celdas.", PG().SIDES, PG().SIDE_LABELS, "RIGHT")
  addNumber(category, "ChukiePartyGrid_Gap", "gap", "Distancia al frame", "Separación respecto al frame.", -60, 300, 2, 8)
  addNumber(category, "ChukiePartyGrid_OffsetX", "offsetX", "Offset X", "Ajuste horizontal.", -400, 400, 2, 0)
  addNumber(category, "ChukiePartyGrid_OffsetY", "offsetY", "Offset Y", "Ajuste vertical.", -400, 400, 2, 0)
  addBool(category, "ChukiePartyGrid_ShowSolo", "showSolo", "Mostrar en solitario", "Sólo tiene efecto en modo libre.", false)

  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Habilidades por columna"))
  for column = 1, 8 do
    addColumnSpell(category, column)
    addColumnCycle(category, column)
    addColumnCycleAction(category, column)
    if CreateSettingsButtonInitializer then
      local columnIndex = column
      layout:AddInitializer(
        CreateSettingsButtonInitializer(
          "Columna " .. columnIndex,
          "Limpiar",
          function()
            PG():SetColumnSpell(columnIndex, nil)
          end,
          "Borra el hechizo de esta columna fuera de combate.",
          true,
          nil,
          nil
        )
      )
    end
  end

  if CreateSettingsButtonInitializer then
    layout:AddInitializer(
      CreateSettingsButtonInitializer("", "Abrir ventana /cpg", function()
        PG():ShowConfig()
      end, "Abre la ventana propia con drag & drop y diagnóstico del frame.")
    )
  end

  Settings.RegisterAddOnCategory(category)
end

function ns.OpenSettings()
  if category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(category.ID)
  elseif PG() then
    PG():ShowConfig()
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, addon)
  if addon == ADDON_NAME then
    registerPanel()
  end
end)
