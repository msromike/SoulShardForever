-- Soul Shard Forever (SSF). MIT, see LICENSE.
-- French strings. Blizzard terms from the frFR client: Fragment d'âme (item 6265),
-- Sac d'âme (the soul bag container type). Registered at the bottom through
-- Locales\Register.lua.

local _, NS = ...
local L = {}

L["Soul Shard Forever"] = "Soul Shard Forever"
L["SSF"] = "SSF"
L["Soul Shard Forever (SSF) v%s by %s. Type /ssf for options."] = "Soul Shard Forever (SSF) v%s par %s. Tapez /ssf pour les options."
L["Deleted a Soul Shard."] = "Un fragment d'âme a été supprimé."
L["ON"] = "ACTIVÉ"
L["OFF"] = "DÉSACTIVÉ"
L["Use: /ssf %s on|off"] = "Usage : /ssf %s on|off"
L["Use: /ssf %s %d-%d"] = "Usage : /ssf %s %d-%d"
L["Soul Shards: %s (cap %s)"] = "Fragments d'âme : %s (limite %s)"
L["(in bags: %s)"] = "(dans les sacs : %s)"
L["%s (cap %d)"] = "%s (limite %d)"
L["Match soul bag size (no soul bag)"] = "Suivre la taille du sac d'âme (aucun sac)"

-- Options
L["Started as a fork of SoulSort by Anilusion."] = "Né d'un fork de SoulSort par Anilusion."
L["Soul shard cap"] = "Limite de fragments d'âme"
L["Delete Shard"] = "Supprimer fragment"
L["Delete one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."] = "Supprime un fragment d'âme si vous dépassez la limite. Dans une macro, placez /ssf delete sur la ligne précédant le sort."
L["Shards to keep"] = "Fragments à garder"
L["The cap. Shards over this number are deleted one per press."] = "La limite. Les fragments au-delà de ce nombre sont supprimés un par pression."
L["Match soul bag size"] = "Suivre la taille du sac d'âme"
L["While a soul bag is equipped, the cap is its slot count. Without one, the slider rules."] = "Avec un sac d'âme équipé, la limite est son nombre d'emplacements. Sans sac, le curseur décide."
L["Show shard count on bag bar"] = "Compteur sur la barre des sacs"
L["Shards in bag count"] = "Compteur de fragments"
L["Low shard glow"] = "Lueur si peu de fragments"
L["Other settings"] = "Autres réglages"
L["Colorize bag count"] = "Colorer le compteur"
L["Glow bag button when low"] = "Faire luire le bouton de sac"
L["Low shard warn"] = "Seuil d'alerte"
L["Bag counter font"] = "Police du compteur"
L["Announce deletions in chat"] = "Annoncer les suppressions"
L["One chat line per deleted shard, for addons that watch chat."] = "Une ligne de chat par fragment supprimé, pour les addons qui lisent le chat."
L["Minimap button"] = "Bouton de minicarte"
L["Language"] = "Langue"
L["Auto"] = "Automatique"
L["Open options"] = "Ouvrir les options"
L["Open the options window."] = "Ouvre la fenêtre des options."
L["Same as options."] = "Identique à options."
L["Close"] = "Fermer"
L["Full"] = "Plein"

-- Broker
L["Soul Shards"] = "Fragments d'âme"
L["Cap"] = "Limite"
L["Over by"] = "Excédent"

NS.RegisterLocale("frFR", "Français", L)
