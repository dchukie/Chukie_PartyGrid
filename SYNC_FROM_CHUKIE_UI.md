# Sincronización con Chukie UI

La versión integrada de referencia vive en `Chukie_Ui/PartyGrid.lua`. Este repo conserva
el mismo núcleo operativo, pero no es una copia literal.

## Debe permanecer igual

- Modelo de columnas, hechizos y ciclos
- Seguridad en combate y atributos de `SecureActionButton`
- Acción `/click ch-cl-<Hechizo>` y lista `cycleUnitN`
- Icono, cooldown, cargas, rango, vida, rol y Masque
- Escaneo profundo por `unit` y `perUnitAnchor` en los cuatro lados
- Guardas de valores secretos 12.x, tanto en hechizos como en geometría de marcos ajenos
  (`frameNumber`, `frameFlag`, `sameUnit`): sin ellas ElvUI rompe el recorrido del árbol
- Tolerancia a objetos prohibidos en ese recorrido (`frameChildren` + un `pcall` por hijo):
  con ElvUI hay ramas reservadas al cliente y tocarlas aborta la ejecución. El árbol se
  recorre rama por rama, descartando la ilegible en vez de perder el mapa entero
- Toda API opcional del panel de Settings va detrás de un `if`. `Settings.CreateTextBox` no
  existe: llamarla aborta el registro y el addon se queda sin panel de opciones
- Ventana desplazable con edición, macro copiable y estado del ciclo
- Drag & drop, diagnósticos y aislamiento de errores

## Exclusivo de este standalone

- `Core.lua`, SavedVariables `ChukiePartyGridDB`, comandos `/cpg` y compartimento
- Prefijos `ChukiePartyGrid_*`
- `hostFrameMode`, `hostFrameCustom` y `ResolveHostFrame`
- Candidatos `ElvUF_*`, watchdog del header y `ElvUIPlugin.lua`
- Panel Settings propio y grupo Masque `Chukie PartyGrid → PartyGrid`

## Regla de actualización

No reemplazar `PartyGrid.lua` completo. Portar el cambio por función o bloque y conservar
la capa de host. Si se agrega una opción general, reflejarla en:

1. `Core.lua` (default/esquema)
2. `ConfigPanel.lua`
3. `ElvUIPlugin.lua`
4. Ventana `/cpg` dentro de `PartyGrid.lua`, si corresponde

Validar siempre los dos escenarios: sin ElvUI y con el modo explícito `elvui`.
