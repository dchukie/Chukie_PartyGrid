--[[ Integración opcional con ElvUI: publica las opciones de PartyGrid dentro de
     ElvUI → Unit Frames → Group Units → Party, que es donde el usuario ya está cuando
     configura la grilla a la que este addon se ancla.

     Es estrictamente opcional. El addon sigue siendo standalone: sin ElvUI este archivo
     no hace nada, y las mismas claves se editan desde `/cpg` y desde Opciones → AddOns.
     Las tres ventanas escriben el mismo perfil a través de PG:SetOption, así que no hay
     una copia de la configuración por interfaz. ]]

local ADDON_NAME, ns = ...

if not _G.ElvUI or not _G.LibStub then
  return
end

local EP = _G.LibStub("LibElvUIPlugin-1.0", true)
if not EP then
  return
end

local E = unpack(_G.ElvUI)

local function PG()
  return ns.PartyGrid
end

local function notifyChange()
  local registry = E.Libs and E.Libs.AceConfigRegistry
  if registry then
    pcall(registry.NotifyChange, registry, "ElvUI")
  end
end

local function inCombat()
  return InCombatLockdown and InCombatLockdown() or false
end

--- Los límites viven en PartyGrid.lua: replicarlos acá los dejaría desincronizados en
--- cuanto se toque uno. Los de reserva solo cubren el caso de un orden de carga raro.
local function limit(key, fallbackMin, fallbackMax)
  local limits = (PG() and PG().LIMITS) or {}
  local range = limits[key]
  return (range and range[1]) or fallbackMin, (range and range[2]) or fallbackMax
end

local function rangeValues(key, step, fallbackMin, fallbackMax)
  local min, max = limit(key, fallbackMin, fallbackMax)
  return { min = min, max = max, step = step or 1 }
end

local function spellName(spellId)
  if not spellId then
    return nil
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
    if ok and type(info) == "table" and info.name then
      return info.name
    end
  end
  return tostring(spellId)
end

-- ---------------------------------------------------------------------------
-- Tabla de opciones
-- ---------------------------------------------------------------------------

--- ACH se resuelve recién acá, no al cargar el archivo: si por orden de carga todavía no
--- estuviera publicado, abortar arriba dejaría al plugin sin opciones para siempre.
local function buildOptions(ACH)
  --- Clave del control = clave del perfil, que es lo que espera este get/set heredado.
  local function get(info)
    return PG():DB()[info[#info]]
  end
  local function setLayout(info, value)
    PG():SetOption(info[#info], value, "layout")
    notifyChange()
  end
  local function setRefresh(info, value)
    PG():SetOption(info[#info], value, "refresh")
    notifyChange()
  end

  local root = ACH:Group("|cff9482c9Chukie PartyGrid|r", nil, 100, nil, get, setLayout)

  root.args.description = ACH:Description(
    "Grilla de celdas clickeables al lado de los marcos de party. Cada columna lleva una habilidad"
      .. " y cada celda la lanza sobre el jugador de su fila.\n\nTambién se configura con |cffffffff/cpg|r.",
    1
  )

  root.args.enabled = ACH:Toggle(
    "Activar grilla",
    "Muestra la grilla clickeable. En combate el cambio se rechaza y no se guarda.",
    2,
    nil,
    nil,
    nil,
    function()
      return PG():DB().enabled == true
    end,
    function(_, value)
      PG():SetEnabled(value)
      notifyChange()
    end
  )

  root.args.openWindow = ACH:Execute("Abrir ventana /cpg", "Abre la ventana propia, con arrastrar y soltar de hechizos.", 3, function()
    PG():ShowConfig()
  end)

  root.args.anchorElv = ACH:Execute(
    "Anclar a los marcos de ElvUI",
    "Fija el modo de anclaje en «ElvUI Party» para que la grilla siga a ElvUF_Party.",
    4,
    function()
      PG():SetOption("hostFrameMode", "elvui", "layout")
      notifyChange()
    end
  )

  root.args.diagnostics = ACH:Execute("Diagnóstico", "Imprime en el chat el estado del frame, el anclaje y los ciclos.", 5, function()
    PG():PrintDiagnostics()
  end)

  root.args.combatWarning = ACH:Description(
    "|cffffcc66En combate toda la configuración se rechaza|r: no se guarda ni se aplaza, y los controles vuelven al valor real al salir.",
    6,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    function()
      return not inCombat()
    end
  )

  -- Aspecto -----------------------------------------------------------------

  local look = ACH:Group("Aspecto", nil, 10, nil, get, setLayout)
  look.inline = true
  root.args.look = look

  --- Con una sola columna no hay nada que separar ni hacia dónde crecer: dejar los
  --- controles activos hace pensar que el ajuste no funciona.
  local function singleColumn()
    return PG():Columns() <= 1
  end

  look.args.size = ACH:Range("Tamaño de celda", "Lado de cada celda, en píxeles.", 1, rangeValues("size", 1, 16, 100))
  look.args.spacing = ACH:Range("Separación de jugadores", "Espacio entre las filas.", 2, rangeValues("spacing", 1, 0, 20))
  look.args.columns = ACH:Range(
    "Columnas por jugador",
    "Celdas en fila por cada jugador, una habilidad distinta en cada una. Con 1 no hay columnas que acomodar.",
    3,
    rangeValues("columns", 1, 1, 8)
  )
  look.args.columnSpacing = ACH:Range(
    "Separación de columnas",
    "Espacio entre las habilidades de una fila.",
    4,
    rangeValues("columnSpacing", 1, 0, 20),
    nil,
    nil,
    nil,
    singleColumn
  )
  look.args.alphaPercent = ACH:Range("Opacidad", "Opacidad del conjunto.", 5, rangeValues("alphaPercent", 5, 10, 100))

  look.args.growth = ACH:Select(
    "Crecimiento de columnas",
    "Hacia dónde se agregan la 2ª, 3ª… habilidad de cada jugador. No mueve la grilla: para eso está «Lado», en Anclaje.",
    6,
    PG().GROWTH_LABELS,
    nil,
    nil,
    nil,
    nil,
    singleColumn
  )
  look.args.orientation = ACH:Select(
    "Orientación de jugadores",
    "Se usa cuando el frame elegido no expone filas por unidad.",
    7,
    PG().ORIENTATION_LABELS
  )

  look.args.includePlayer = ACH:Toggle("Incluir al jugador", "Agrega tu propia fila además de party1..4.", 8, nil, nil, nil, get, setRefresh)
  look.args.showHealth = ACH:Toggle("Barra de vida", "Dibuja la vida detrás del icono.", 9, nil, nil, nil, get, setRefresh)
  look.args.showRole = ACH:Toggle("Icono de rol", "Tanque, sanador o daño en la primera celda de cada fila.", 10, nil, nil, nil, get, setRefresh)
  look.args.useMasque = ACH:Toggle(
    "Usar Masque",
    "Registra las celdas en el grupo «Chukie PartyGrid → PartyGrid».",
    11,
    nil,
    nil,
    nil,
    get,
    setRefresh
  )

  -- Anclaje -----------------------------------------------------------------

  local anchor = ACH:Group("Anclaje", nil, 20, nil, get, setLayout)
  anchor.inline = true
  root.args.anchor = anchor

  local function detached()
    return PG():DB().attachToBlizzard == false
  end

  anchor.args.attachToBlizzard = ACH:Toggle(
    "Pegada a un frame",
    "Sin esto la grilla queda en posición libre y se mueve arrastrándola desde /cpg.",
    1
  )

  anchor.args.hostFrameMode = ACH:Select(
    "Frame objetivo",
    "Automático prioriza ElvUI. Los modos explícitos esperan ese frame sin caer en otro.",
    2,
    PG().HOST_FRAME_LABELS,
    nil,
    nil,
    nil,
    nil,
    detached
  )

  anchor.args.hostFrameCustom = ACH:Input(
    "Nombre global personalizado",
    "Por ejemplo ElvUF_Party. Sólo se usa con «Nombre global personalizado».",
    3,
    nil,
    nil,
    nil,
    nil,
    function()
      return detached() or PG():HostFrameMode() ~= "custom"
    end
  )

  anchor.args.perUnitAnchor = ACH:Toggle(
    "Anclar a cada jugador",
    "Cada grupo de celdas se pega al marco de su propio jugador. Es lo que querés con la grilla de party"
      .. " en horizontal y las celdas arriba o abajo. Sin esto, la grilla se ancla como un bloque único al"
      .. " conjunto de marcos.",
    4,
    nil,
    nil,
    nil,
    nil,
    nil,
    detached
  )

  anchor.args.status = ACH:Description(function()
    local resolved = PG():BlizzardContainer()
    if resolved then
      local name = (resolved.GetName and resolved:GetName()) or "sin nombre"
      return "|cff66ff66Resuelto:|r " .. name .. " · visible=" .. tostring(resolved:IsVisible())
    end
    if detached() then
      return "Modo libre: posición propia respecto a UIParent."
    end
    return "|cffff6666Esperando frame:|r todavía no existe o no está visible."
  end, 5)

  anchor.args.side = ACH:Select(
    "Lado",
    "De qué lado se colocan las celdas. Con «Anclar a cada jugador» es respecto al marco de cada uno;"
      .. " sin eso, respecto al conjunto. Esto es lo que las manda arriba, abajo o a un costado.",
    6,
    PG().SIDE_LABELS,
    nil,
    nil,
    nil,
    nil,
    detached
  )
  anchor.args.gap = ACH:Range("Distancia al frame", nil, 7, rangeValues("gap", 2, -60, 300), nil, nil, nil, detached)
  anchor.args.offsetX = ACH:Range("Ajuste X", nil, 8, rangeValues("offset", 2, -400, 400))
  anchor.args.offsetY = ACH:Range("Ajuste Y", nil, 9, rangeValues("offset", 2, -400, 400))
  anchor.args.showSolo = ACH:Toggle("Mostrar en solitario", "Sólo tiene efecto en modo libre.", 10, nil, nil, nil, nil, nil, function()
    return not detached()
  end)

  -- Habilidades por columna -------------------------------------------------

  local spells = ACH:Group("Habilidades por columna", nil, 30)
  root.args.spells = spells

  spells.args.description = ACH:Description(
    "Escribí el nombre exacto o el ID del hechizo; vacío limpia la columna. También podés arrastrar"
      .. " un hechizo del libro sobre una celda.\n\nUna columna en |cffffffffCiclo|r publica una acción"
      .. " |cffffffff/click ch-cl-Hechizo|r que lanza sobre el siguiente jugador incluido. Fuera de combate,"
      .. " el clic derecho sobre una celda incluye o excluye a ese jugador.",
    1
  )

  local minColumn, maxColumn = limit("columns", 1, 8)
  for column = minColumn, maxColumn do
    local index = column

    local entry = ACH:Group(function()
      local name = spellName(PG():ColumnSpell(index))
      local title = "Columna " .. index .. ": " .. (name or "|cff909090vacía|r")
      return PG():IsCycleColumn(index) and (title .. " |cff8ad4ff(ciclo)|r") or title
    end, nil, index + 1)
    entry.inline = true
    spells.args["column" .. index] = entry

    entry.args.spell = ACH:Input(
      "Hechizo",
      "Nombre exacto o ID. Vacío limpia la columna.",
      1,
      nil,
      nil,
      function()
        return spellName(PG():ColumnSpell(index)) or ""
      end,
      function(_, value)
        PG():SetColumnSpellInput(index, value)
        notifyChange()
      end
    )

    entry.args.cycle = ACH:Toggle(
      "Usar como ciclo",
      "Publica una acción /click que recorre los jugadores incluidos.",
      2,
      nil,
      nil,
      nil,
      function()
        return PG():IsCycleColumn(index)
      end,
      function(_, value)
        PG():SetColumnCycle(index, value)
        notifyChange()
      end
    )

    entry.args.clear = ACH:Execute("Limpiar", "Borra la habilidad de esta columna.", 3, function()
      PG():SetColumnSpell(index, nil)
      notifyChange()
    end)

    --- Caja de solo lectura: existe para copiar la línea a una macro. La lista de
    --- unidades no se edita acá, se arma con clic derecho sobre la propia grilla.
    entry.args.macro = ACH:Input(
      "Macro del ciclo",
      "Copiá esta línea a una macro.",
      4,
      nil,
      "full",
      function()
        local action = PG():CycleActionName(index)
        if not action then
          return ""
        end
        return "/click " .. action
      end,
      function()
        print("|cffff9900Chukie PartyGrid|r: copiá esa línea a una macro; la lista se edita con clic derecho en la grilla.")
        notifyChange()
      end,
      function()
        return PG():CycleActionName(index) == nil
      end
    )
  end

  return root
end

-- ---------------------------------------------------------------------------
-- Registro
-- ---------------------------------------------------------------------------

local function insertOptions()
  local ACH = E.Libs and E.Libs.ACH
  if not PG() or not ACH then
    return
  end
  local options = E.Options and E.Options.args
  if not options then
    return
  end
  local built = buildOptions(ACH)
  --- Destino preferido: dentro de la sección Party de Unit Frames, que es el contexto en
  --- el que se usa la grilla. Si ElvUI reacomoda su árbol, cae en la raíz antes que
  --- desaparecer sin dejar rastro.
  local unitframe = options.unitframe and options.unitframe.args
  local groupUnits = unitframe and unitframe.groupUnits and unitframe.groupUnits.args
  local party = groupUnits and groupUnits.party and groupUnits.party.args
  if party then
    party.chukiePartyGrid = built
  else
    options.chukiePartyGrid = built
  end
end

--- NewModule aborta si el nombre ya está tomado, y llevarse puesto el arranque de ElvUI
--- por una integración opcional sería un mal negocio.
local module = E:GetModule(ADDON_NAME, true) or E:NewModule(ADDON_NAME)
if not module then
  return
end

function module:Initialize()
  EP:RegisterPlugin(ADDON_NAME, insertOptions)
end

--- Registra el módulo aunque ElvUI ya haya inicializado: en ese caso lo llama en el acto.
E:RegisterModule(module:GetName())
