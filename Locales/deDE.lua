-- Soul Shard Forever (SSF). MIT, see LICENSE.
-- German strings. Blizzard terms from the deDE client: Seelensplitter (item 6265),
-- Seelentasche (the soul bag container type). Registered at the bottom through
-- Locales\Register.lua.

local _, NS = ...
local L = {}

L["Soul Shard Forever"] = "Soul Shard Forever"
L["SSF"] = "SSF"
L["Soul Shard Forever (SSF) v%s by %s. Type /ssf for options."] = "Soul Shard Forever (SSF) v%s von %s. /ssf eingeben für die Optionen."
L["Deleted a Soul Shard."] = "Ein Seelensplitter wurde gelöscht."
L["ON"] = "AN"
L["OFF"] = "AUS"
L["Use: /ssf %s on|off"] = "Verwendung: /ssf %s on|off"
L["Use: /ssf %s %d-%d"] = "Verwendung: /ssf %s %d-%d"
L["Soul Shards: %s (cap %s)"] = "Seelensplitter: %s (Limit %s)"
L["(in bags: %s)"] = "(in den Taschen: %s)"
L["%s (cap %d)"] = "%s (Limit %d)"
L["Match soul bag size (no soul bag)"] = "An Seelentasche anpassen (keine angelegt)"

-- Options
L["Started as a fork of SoulSort by Anilusion."] = "Begann als Fork von SoulSort von Anilusion."
L["Soul shard cap"] = "Seelensplitter-Limit"
L["Delete Shard"] = "Splitter löschen"
L["Delete one Soul Shard if you are over the cap. In a macro, put /ssf delete on the line before the ability."] = "Löscht einen Seelensplitter, wenn du über dem Limit bist. In einem Makro steht /ssf delete in der Zeile vor der Fähigkeit."
L["Shards to keep"] = "Splitter behalten"
L["The cap. Shards over this number are deleted one per press."] = "Das Limit. Splitter über dieser Zahl werden pro Tastendruck einzeln gelöscht."
L["Match soul bag size"] = "An Seelentasche anpassen"
L["While a soul bag is equipped, the cap is its slot count. Without one, the slider rules."] = "Mit angelegter Seelentasche ist das Limit ihre Platzzahl. Ohne Tasche gilt der Schieberegler."
L["Show shard count on bag bar"] = "Splitterzahl auf der Taschenleiste"
L["Shards in bag count"] = "Splitterzähler"
L["Low shard glow"] = "Leuchten bei wenigen Splittern"
L["Other settings"] = "Weitere Einstellungen"
L["Colorize bag count"] = "Zähler einfärben"
L["Glow bag button when low"] = "Taschenknopf leuchten lassen"
L["Low shard warn"] = "Warnschwelle"
L["Bag counter font"] = "Schriftart des Zählers"
L["Announce deletions in chat"] = "Löschungen im Chat melden"
L["One chat line per deleted shard, for addons that watch chat."] = "Eine Chatzeile pro gelöschtem Splitter, für Addons, die den Chat auswerten."
L["SoulSort legacy method"] = "Klassische SoulSort-Methode"
L["Sort shards the way SoulSort does: other items in the way swap places with them. Normal or Reverse is set in the options window."] = "Sortiert Splitter wie SoulSort: andere Gegenstände im Weg tauschen mit ihnen den Platz. Normal oder Umgekehrt wird im Optionsfenster eingestellt."
L["SoulSort fill order"] = "SoulSort-Füllreihenfolge"
L["Normal (top to bottom)"] = "Normal (oben nach unten)"
L["Reverse (bottom to top)"] = "Umgekehrt (unten nach oben)"
L["Minimap button"] = "Minikartensymbol"
L["Language"] = "Sprache"
L["Auto"] = "Automatisch"
L["Open options"] = "Optionen öffnen"
L["Open the options window."] = "Öffnet das Optionsfenster."
L["Same as options."] = "Wie options."
L["Close"] = "Schließen"
L["Full"] = "Voll"

-- Broker
L["Soul Shards"] = "Seelensplitter"
L["Cap"] = "Limit"
L["Over by"] = "Zu viel"

NS.RegisterLocale("deDE", "Deutsch", L)
