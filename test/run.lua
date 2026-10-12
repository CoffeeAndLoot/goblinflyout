-- Run from the repository root through lupa (see CLAUDE.md).
local harness = dofile("test/harness.lua")

-- Same (addonName, ns) the client passes, loaded in TOC order into one ns.
-- API.lua, Window.lua and Core.lua touch Blizzard globals, so they are not loaded here.
-- A missing module is a hard failure: a suite that silently skips proves nothing.
local modules = {
    { "Kinds", "GoblinFlyout/Kinds.lua" },
    { "Professions", "GoblinFlyout/Professions.lua" },
    { "Items", "GoblinFlyout/Items.lua" },
    { "Options", "GoblinFlyout/Options.lua" },
    { "Macro", "GoblinFlyout/Macro.lua" },
    { "Bar", "GoblinFlyout/Bar.lua" },
    { "MinimapButton", "GoblinFlyout/MinimapButton.lua" },
}

local ns = {}
local loaded = { ns = ns }
for i = 1, #modules do
    local name, path = modules[i][1], modules[i][2]
    loaded[name] = assert(loadfile(path))("GoblinFlyout", ns)
end

local suites = {
    "test/test_professions.lua",
    "test/test_kinds.lua",
    "test/test_items.lua",
    "test/test_options.lua",
    "test/test_macro.lua",
    "test/test_bar.lua",
    "test/test_minimap.lua",
}

for i = 1, #suites do
    dofile(suites[i])(harness, loaded)
end

os.exit(harness.run())
