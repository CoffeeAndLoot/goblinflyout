return function(h, loaded)
    local MinimapButton = loaded.ns.MinimapButton

    local function near(actual, expected, label)
        h.truthy(math.abs(actual - expected) < 1e-9, (label or "") .. " " .. actual .. " ~= " .. expected)
    end

    h.describe("MinimapButton.Position", function()
        h.it("0 degrees is straight right, 90 straight up", function()
            local x, y = MinimapButton.Position(0, 80)
            near(x, 80, "x")
            near(y, 0, "y")
            x, y = MinimapButton.Position(90, 80)
            near(x, 0, "x")
            near(y, 80, "y")
        end)
    end)

    h.describe("MinimapButton.Angle", function()
        h.it("reads the four directions as 0..360", function()
            near(MinimapButton.Angle(1, 0), 0)
            near(MinimapButton.Angle(0, 1), 90)
            near(MinimapButton.Angle(-1, 0), 180)
            near(MinimapButton.Angle(0, -1), 270)
        end)
        h.it("round-trips with Position", function()
            near(MinimapButton.Angle(MinimapButton.Position(225, 80)), 225)
        end)
    end)
end
