-- Soul Shard Forever (SSF). MIT, see LICENSE.
-- Latin American Spanish strings. Blizzard terms from the Spanish client: Fragmento de alma
-- (item 6265), Bolsa de almas (the soul bag container type). Registered at the bottom through
-- Locales\Register.lua.

local _, NS = ...
local L = {}

L["Soul Shard Forever"] = "Soul Shard Forever"
L["SSF"] = "SSF"
L["Soul Shard Forever (SSF) v%s by %s. Type /ssf for options."] = "Soul Shard Forever (SSF) v%s por %s. Escribe /ssf para las opciones."
L["Deleted a Soul Shard."] = "Se eliminó un fragmento de alma."
L["ON"] = "ACTIVADO"
L["OFF"] = "DESACTIVADO"
L["Use: /ssf %s on|off"] = "Uso: /ssf %s on|off"
L["Use: /ssf %s %d-%d"] = "Uso: /ssf %s %d-%d"
L["Soul Shards: %s (cap %s)"] = "Fragmentos de alma: %s (límite %s)"
L["(in bags: %s)"] = "(en las bolsas: %s)"
L["%s (cap %d)"] = "%s (límite %d)"
L["Match soul bag size (no soul bag)"] = "Según la bolsa de almas (sin bolsa)"

-- Options
L["Started as a fork of SoulSort by Anilusion."] = "Nació como un fork de SoulSort de Anilusion."
L["Soul shard cap"] = "Límite de fragmentos de alma"
L["Delete Shard"] = "Eliminar fragmento"
L["Delete one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."] = "Elimina un fragmento de alma si superas el límite. En un macro, pon /ssf delete en la línea anterior a la habilidad."
L["Shards to keep"] = "Fragmentos a conservar"
L["The cap. Shards over this number are deleted one per press."] = "El límite. Los fragmentos por encima de este número se eliminan uno cada vez que presionas."
L["Match soul bag size"] = "Según la bolsa de almas"
L["While a soul bag is equipped, the cap is its slot count. Without one, the slider rules."] = "Con una bolsa de almas equipada, el límite es su número de casillas. Sin ella, manda el control deslizante."
L["Show shard count on bag bar"] = "Contador en la barra de bolsas"
L["Show on soul bag when equipped"] = "En la bolsa de almas si está equipada"
L["Pause SSF"] = "Pausar SSF"
L["Pause all SSF actions"] = "Pausar todas las acciones de SSF"
L["Stop every press from moving or deleting shards, until you turn it off."] = "Ninguna pulsación mueve ni elimina fragmentos hasta que lo desactives."
L["All SSF actions paused"] = "Todas las acciones de SSF en pausa"
L["SSF actions"] = "Acciones de SSF"
L["Type /ssf help for commands."] = "Escribe /ssf help para ver los comandos."
L['Unknown command "%s".'] = 'Comando desconocido "%s".'
L["Play pause sound"] = "Reproducir sonido de pausa"
L["Log pause to chat"] = "Avisar la pausa en el chat"
L["Full volume"] = "Máximo"
L["Loud"] = "Alto"
L["Medium"] = "Medio"
L["Quiet"] = "Bajo"
L["Soul shard counter"] = "Contador de fragmentos de alma"
L["Soul shard warning"] = "Aviso de fragmentos de alma"
L["Other settings"] = "Otros ajustes"
L["Colorize bag count"] = "Colorear el contador"
L["Glow bag button when low"] = "Iluminar el botón de bolsa"
L["Low shard warn"] = "Umbral de aviso"
L["Bag counter font"] = "Fuente del contador"
L["Announce deletions in chat"] = "Anunciar eliminaciones en el chat"
L["One chat line per deleted shard, for addons that watch chat."] = "Una línea de chat por fragmento eliminado, para addons que leen el chat."
L["How shards move"] = "Cómo se mueven los fragmentos"
L["SSF Mode"] = "Modo SSF"
L["SoulSort Normal"] = "SoulSort Normal"
L["SoulSort Reverse"] = "SoulSort Invertido"
L["Shards move to soul bag. SSF does not sort."] = "Los fragmentos van a la bolsa de almas. SSF no ordena."
L["Shards move to soul bag. Shards sort top down."] = "Los fragmentos van a la bolsa de almas. Los fragmentos se ordenan de arriba abajo."
L["Shards move to soul bag. Shards sort bottom up."] = "Los fragmentos van a la bolsa de almas. Los fragmentos se ordenan de abajo arriba."
L["Show minimap icon"] = "Mostrar icono del minimapa"
L["Language"] = "Idioma"
L["Open options"] = "Abrir opciones"
L["Open the options window."] = "Abre la ventana de opciones."
L["Same as options."] = "Igual que options."
L["Close"] = "Cerrar"
L["Full"] = "Lleno"

-- Broker
L["Soul Shards"] = "Fragmentos de alma"
L["Cap"] = "Límite"
L["Over by"] = "Exceso"

NS.RegisterLocale("esMX", "Español", L)
