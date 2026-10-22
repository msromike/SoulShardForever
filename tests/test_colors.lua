-- Soul Shards Forever (SSF). MIT, see LICENSE.
--
-- test_colors: a color is typed once as r, g, b and the hex its escape code takes is
-- derived from it, channel by channel; the over-cap yellow is its own color, not the
-- label gold; a state paints in the color the scale names.
-- Reads:   Colors.
-- Touches nothing else.

local Colors = SSF:GetModule("Colors")

local NAMES = { "RED", "GREEN", "YELLOW", "GOLD", "WHITE", "DIM", "ECHO", "BLUE", "CODE", "SLATE", "BLACK" }

test("every color's hex is its r, g, b in 255ths", function()
    for _, name in ipairs(NAMES) do
        local c = Colors[name]
        ok(type(c) == "table" and #c == 4, name .. " is { r, g, b, hex }")
        for channel = 1, 3 do
            local want = math.floor(c[channel] * 255 + 0.5)
            local got = tonumber(c[4]:sub(channel * 2 - 1, channel * 2), 16)
            eq(got, want, name .. " channel " .. channel)
        end
    end
end)

test("the over-cap yellow is not the label gold", function()
    ok(Colors.YELLOW[4] ~= Colors.GOLD[4], "two colors")
    eq(Colors:Gold("x"), Colors:Paint(Colors.GOLD, "x"), "Gold paints in the label gold")
    eq(Colors:PaintState("over", "x"), Colors:Paint(Colors.YELLOW, "x"), "over paints in the yellow")
end)

test("the state scale", function()
    eq(Colors:PaintState("low", "x"), Colors:Paint(Colors.RED, "x"), "low is red")
    eq(Colors:PaintState("ok", "x"), Colors:Paint(Colors.GREEN, "x"), "ok is green")
    eq(Colors:PaintState("paused", "x"), Colors:Paint(Colors.WHITE, "x"), "paused is white")
    eq(Colors:PaintState("quiet", "x"), Colors:Paint(Colors.WHITE, "x"), "quiet is white")
    local r, g, b, hex = Colors:ForState("over")
    eq(hex, Colors.YELLOW[4], "ForState hands back the same color")
    ok(r == Colors.YELLOW[1] and g == Colors.YELLOW[2] and b == Colors.YELLOW[3], "and its r, g, b")
end)
