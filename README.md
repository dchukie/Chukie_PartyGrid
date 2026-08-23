# Chukie PartyGrid

Addon standalone para World of Warcraft Retail 12.1. Cada columna guarda un hechizo y
cada celda lo lanza sobre `player` / `party1..4` con un botón seguro.

## Instalación

Copiar la carpeta completa `Chukie_PartyGrid` a:

`World of Warcraft\_retail_\Interface\AddOns\Chukie_PartyGrid`

La carpeta tiene que llamarse exactamente igual que el `.toc` que hay dentro. Al bajar el ZIP
de GitHub queda `Chukie_PartyGrid-main`, y con ese nombre el cliente ni siquiera lista el
addon: hay que renombrarla a `Chukie_PartyGrid`. Con `git clone` el nombre ya sale correcto.

Activar **Chukie PartyGrid** en el selector de addons y usar:

- `/cpg` (alias `/partygrid`, `/chukie-partygrid`): abre/cierra la ventana propia.
- `/cpg settings`: abre Opciones → AddOns → Chukie PartyGrid.
- `/cpg on`, `/cpg off`: activa/desactiva.
- `/cpg diag`: diagnóstico de frame, anclaje, ciclos, clicks, Masque y errores.
- `/cpg help`: lista los comandos.

También aparece en el **compartimento de addons** (el icono al lado del minimapa): clic
izquierdo abre la ventana, clic derecho abre Opciones.

## Integración con ElvUI

Si ElvUI está instalado, el addon se registra como plugin (`LibElvUIPlugin-1.0`) y publica
sus opciones en:

    ElvUI → Unit Frames → Group Units → Party → Chukie PartyGrid

Es opcional y no cambia nada: sin ElvUI el addon funciona igual, y las tres interfaces
(`/cpg`, Opciones → AddOns y ElvUI) escriben el mismo perfil a través de la misma ruta, así
que no hay copias separadas de la configuración.

El grupo incluye un botón **«Anclar a los marcos de ElvUI»** que fija el modo de anclaje en
`ElvUI Party` sin tener que buscarlo en la lista.

## Anclaje (Blizzard, ElvUI y custom)

En la ventana `/cpg` y en Opciones se puede elegir:

- **Automático (ElvUI primero)**: usa un party header visible de ElvUI; si no existe,
  detecta la grilla activa de Blizzard.
- **ElvUI Party**: espera `ElvUF_Party` (y variantes conocidas) sin cambiar a Blizzard.
- **Blizzard automático**: elige el contenedor Blizzard activo.
- **Presets Blizzard**: `CompactPartyFrame`, `CompactRaidFrameContainer` o `PartyFrame`.
- **Nombre global personalizado**: escribe un global como `ElvUF_Party`.
- **Modo libre**: desmarca «Pegada a un frame» y usa «Mover».

Los modos explícitos no caen silenciosamente en otro frame. Si el objetivo no existe
todavía, la grilla queda oculta y el estado indica «Esperando frame». El watchdog vuelve
a resolverlo cuando el addon/frame aparece.

El motor recorre los hijos del frame elegido y lee su campo o atributo seguro `unit`.
Esto mantiene el mismo orden visual en Blizzard y en los headers oUF de ElvUI. En un
frame custom sin hijos con `unit`, el conjunto se pega al frame pero usa el orden propio
`player, party1..4`.

### Anclar a cada jugador

Con **«Anclar a cada jugador»** (activado por defecto) el grupo de celdas de cada unidad se
pega al marco de *ese* jugador, del lado que indique **«Lado»** y centrado sobre él. Es lo
que hace falta cuando la grilla de party está en **horizontal** y querés las celdas arriba o
abajo: anclando al conjunto, todas las filas terminan amontonadas sobre el primer jugador.

Desmarcarlo vuelve al comportamiento de bloque único, donde la grilla entera se pega al
contenedor y las filas se encadenan según **«Orientación de jugadores»**. Sirve si el frame
elegido no expone hijos con `unit`, o si preferís la grilla como una tira aparte.

`/cpg diag` imprime `anclajePorJugador`, `lado`, `crecimiento` y `marcosPorUnidad`. Si
`marcosPorUnidad` es 0 con la opción activada, ninguna unidad encontró su marco y la grilla
cae al bloque encadenado: el problema es el frame objetivo, no el lado ni el crecimiento.

## Asignación y seguridad

- Arrastrar un hechizo del libro sobre una celda lo asigna a toda esa columna.
- Arrastrar una celda hacia otra columna mueve la asignación.
- En `/cpg` y en Opciones cada columna tiene una caja de texto: escribí el **nombre exacto
  o el ID** del hechizo. Vacío limpia la columna.
- Clic izquierdo castea al soltar (`useOnKeyDown=false`).
- No usa ClickCast templates ni se registra en Clique.
- Ninguna opción, atributo, tamaño o ancla segura se cambia en combate.
- Cooldowns/cargas usan las APIs de duration objects y guards de valores secretos 12.x.
- La geometría de marcos ajenos también se lee con esos guards: un marco marcado con
  secretos (los resaltes de aura de ElvUI, cualquier barra de vida) devuelve medidas
  ilegibles, así que se tratan como desconocidas y no se baja por esa rama del árbol.

## Columnas de ciclo

Una columna marcada como **Ciclo** publica además un botón seguro con nombre global
propio. Copiá su línea a una macro:

    /click ch-cl-NombreDelHechizo

Cada pulsación lanza el hechizo sobre el **siguiente jugador incluido** en el ciclo, y
funciona en combate porque el recorrido lo hace un snippet seguro.

- Fuera de combate, **clic derecho** sobre una celda incluye o excluye a ese jugador.
- Los excluidos se ven apagados; el tooltip indica el estado.
- El orden de la secuencia es el orden en que se fueron prendiendo.
- Dos columnas de ciclo no pueden compartir hechizo: el nombre global sería el mismo.
- `/cpg` muestra la macro y la lista de unidades de cada ciclo; `/cpg diag` también.

## Masque

Masque es opcional. El grupo propio es **Chukie PartyGrid → PartyGrid**.

## Coexistencia con Chukie UI

Los globals, SavedVariables, comandos y grupo Masque tienen nombres separados, por lo que
ambos addons pueden cargar juntos. Para evitar dos grillas visibles, desactivar PartyGrid
en Chukie UI o en este standalone.

La excepción son las **acciones de ciclo**: `ch-cl-<Hechizo>` es el mismo nombre en los
dos addons, a propósito, para que las macros ya escritas sigan funcionando al pasar de la
versión integrada a esta. Justamente por eso no conviene tener las dos con ciclos activos
al mismo tiempo: el primero en cargar conserva la acción y el segundo avisa sin pisarla.

Datos guardados: `ChukiePartyGridDB` (perfil único). Las columnas de ciclo crean globals
`ch-cl-<Hechizo>`; si otro addon ya usa ese nombre, PartyGrid lo avisa y no lo pisa.
