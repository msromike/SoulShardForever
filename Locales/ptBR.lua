-- Soul Shard Forever (SSF). MIT, see LICENSE.
-- Brazilian Portuguese strings. Blizzard terms from the ptBR client: Estilhaço de Alma
-- (item 6265), Bolsa de Almas (the soul bag container type). Registered at the bottom
-- through Locales\Register.lua.

local _, NS = ...
local L = {}

L["Soul Shard Forever"] = "Soul Shard Forever"
L["SSF"] = "SSF"
L["Soul Shard Forever (SSF) v%s by %s. Type /ssf for options."] = "Soul Shard Forever (SSF) v%s por %s. Digite /ssf para ver as opções."
L["Deleted a Soul Shard."] = "Um Estilhaço de Alma foi excluído."
L["ON"] = "LIGADO"
L["OFF"] = "DESLIGADO"
L["Use: /ssf %s on|off"] = "Uso: /ssf %s on|off"
L["Use: /ssf %s %d-%d"] = "Uso: /ssf %s %d-%d"
L["Soul Shards: %s (cap %s)"] = "Estilhaços de Alma: %s (limite %s)"
L["(in bags: %s)"] = "(nas bolsas: %s)"
L["%s (cap %d)"] = "%s (limite %d)"
L["Match soul bag size (no soul bag)"] = "Igual à Bolsa de Almas (sem bolsa)"

-- Options
L["Started as a fork of SoulSort by Anilusion."] = "Começou como um fork do SoulSort de Anilusion."
L["Soul shard cap"] = "Limite de Estilhaços de Alma"
L["Delete Shard"] = "Excluir estilhaço"
L["Delete one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."] = "Exclui um Estilhaço de Alma se você estiver acima do limite. Em uma macro, coloque /ssf delete na linha antes da habilidade."
L["Shards to keep"] = "Estilhaços a manter"
L["The cap. Shards over this number are deleted one per press."] = "O limite. Estilhaços acima deste número são excluídos um a cada uso."
L["Match soul bag size"] = "Igual à Bolsa de Almas"
L["While a soul bag is equipped, the cap is its slot count. Without one, the slider rules."] = "Com uma Bolsa de Almas equipada, o limite é o número de espaços dela. Sem ela, vale o controle deslizante."
L["Show shard count on bag bar"] = "Contador na barra de bolsas"
L["Show on soul bag when equipped"] = "Na Bolsa de Almas, se equipada"
L["Pause SSF"] = "Pausar SSF"
L["Pause all SSF actions"] = "Pausar todas as ações do SSF"
L["Stop every press from moving or deleting shards, until you turn it off."] = "Nenhum toque move nem exclui estilhaços até você desativar."
L["All SSF actions paused"] = "Todas as ações do SSF pausadas"
L["SSF actions"] = "Ações do SSF"
L["Type /ssf help for commands."] = "Digite /ssf help para ver os comandos."
L['Unknown command "%s".'] = 'Comando desconhecido "%s".'
L["Play pause sound"] = "Tocar som de pausa"
L["Log pause to chat"] = "Avisar a pausa no bate-papo"
L["Full volume"] = "Máximo"
L["Loud"] = "Alto"
L["Medium"] = "Médio"
L["Quiet"] = "Baixo"
L["Soul shard counter"] = "Contador de Estilhaços de Alma"
L["Soul shard warning"] = "Aviso de Estilhaços de Alma"
L["Other settings"] = "Outras configurações"
L["Colorize bag count"] = "Colorir o contador"
L["Glow bag button when low"] = "Iluminar o botão da bolsa"
L["Low shard warn"] = "Limiar de aviso"
L["Bag counter font"] = "Fonte do contador"
L["Announce deletions in chat"] = "Anunciar exclusões no bate-papo"
L["One chat line per deleted shard, for addons that watch chat."] = "Uma linha no bate-papo por estilhaço excluído, para addons que leem o bate-papo."
L["How shards move"] = "Como os estilhaços se movem"
L["SSF Mode"] = "Modo SSF"
L["SoulSort Normal"] = "SoulSort Normal"
L["SoulSort Reverse"] = "SoulSort Invertido"
L["Shards move to soul bag. SSF does not sort."] = "Os estilhaços vão para a Bolsa de Almas. O SSF não organiza."
L["Shards move to soul bag. Shards sort top down."] = "Os estilhaços vão para a Bolsa de Almas. Os estilhaços são organizados de cima para baixo."
L["Shards move to soul bag. Shards sort bottom up."] = "Os estilhaços vão para a Bolsa de Almas. Os estilhaços são organizados de baixo para cima."
L["Show minimap icon"] = "Mostrar ícone do minimapa"
L["Language"] = "Idioma"
L["Open options"] = "Abrir opções"
L["Open the options window."] = "Abre a janela de opções."
L["Same as options."] = "Igual a options."
L["Close"] = "Fechar"
L["Full"] = "Cheio"

-- Broker
L["Soul Shards"] = "Estilhaços de Alma"
L["Cap"] = "Limite"
L["Over by"] = "Excesso"

NS.RegisterLocale("ptBR", "Português", L)
