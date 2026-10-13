local _, ns = ...

-- Glue (spec 2026-10-12-goblin-flyout-design.md): the SavedVariable, setup,
-- events and /gf. Every handler runs behind guard(), so an error is one chat
-- line, said once per label, never a raise.
local API, Bar, Kinds, Macro, MinimapButton, Options, Professions, Window =
    ns.API, ns.Bar, ns.Kinds, ns.Macro, ns.MinimapButton, ns.Options, ns.Professions, ns.Window
local Core = {}
ns.Core = Core

local function say(text)
    print("|cffffd100Goblin Flyout|r " .. text)
end
Core.Say = say

local said = {}
local function guard(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not said[label] then
        said[label] = true
        say(label .. " error: " .. tostring(err) .. " (said once; tell Claude).")
    end
    return ok
end

-- Looked up lazily: SavedVariables load after this file runs.
local function db()
    GoblinFlyoutDB = Options.Init(GoblinFlyoutDB)
    return GoblinFlyoutDB
end

function Core.Layout(key)
    return db().layouts[key] or Options.DEFAULT_LAYOUT
end

function Core.SetLayout(key, layout)
    local kind = Kinds.ByKey(key)
    if kind and Options.LABELS[layout] then
        db().layouts[key] = layout
        Bar.Close(kind)
        Window.Refresh(Core)
    end
end

function Core.Angle()
    return db().minimap.angle
end

function Core.SetAngle(angle)
    if type(angle) == "number" then
        db().minimap.angle = angle
    end
end

function Core.MinimapShown()
    return not db().minimap.hide
end

function Core.SetMinimapShown(shown)
    db().minimap.hide = not shown
    MinimapButton.SetShown(shown)
    Window.Refresh(Core)
end

function Core.Window()
    return db().window
end

function Core.SaveWindow(point, relativePoint, x, y)
    if type(point) == "string" and type(relativePoint) == "string" and type(x) == "number" and type(y) == "number" then
        db().window = { point = point, relativePoint = relativePoint, x = x, y = y }
    end
end

function Core.ToggleWindow()
    guard("Window", Window.Toggle, Core)
end

-- Puts the kind's button on the cursor; says why when it can't. True when it's there.
function Core.PickUp(kind)
    local placed = false
    guard("Pick up", function()
        local message = Macro.PickUp(kind)
        if message then
            say(message)
        else
            placed = true
        end
    end)
    return placed
end

-- Opens Blizzard's macro window on the kind's macro to change its icon.
function Core.EditIcon(kind)
    guard("Change icon", function()
        local message = Macro.Edit(kind)
        if message then
            say(message)
        end
    end)
end

-- The kind's macro icon, for the window's row.
function Core.Icon(kind)
    return Macro.Icon(kind)
end

local snippets  -- whether secure snippets ran at setup; nil until then

-- /gf <word> [rest] -> handler(rest)
local commands = {}
local HELP = "Commands: /gf, /gf <kind>, /gf layout <kind>, /gf minimap, /gf probe. Kinds: "
    .. table.concat(Kinds.KEYS, ", ") .. "."

commands[""] = function()
    Core.ToggleWindow()
end
commands.options = commands[""]

function commands.layout(rest)
    local kind = Kinds.ByKey(rest)
    if not kind then
        say("Which one? /gf layout <" .. table.concat(Kinds.KEYS, "|") .. ">")
        return
    end
    Core.SetLayout(kind.key, Options.Other(Core.Layout(kind.key)))
    say(kind.label .. " layout: " .. Options.LABELS[Core.Layout(kind.key)] .. ".")
end

function commands.minimap()
    Core.SetMinimapShown(not Core.MinimapShown())
    if Core.MinimapShown() then
        say("Minimap button shown.")
    else
        say("Minimap button hidden; /gf opens the window.")
    end
end

-- What detection sees, to settle in-game unknowns.
function commands.probe()
    for _, raw in ipairs(API.RawProfessions()) do
        local spells = {}
        for _, spell in ipairs(raw.spells) do
            spells[#spells + 1] = string.format("%d %s [window:%s passive:%s]", spell.spellID,
                tostring(spell.name), tostring(spell.craftingUI), tostring(spell.isPassive))
        end
        local pick = Professions.Pick(raw)
        say(string.format("Probe: %s (skillLine %s): %s -> %s", raw.name, tostring(raw.skillLine),
            #spells > 0 and table.concat(spells, ", ") or "no spells",
            pick and (tostring(pick.name) .. " " .. pick.spellID) or "no entry"))
    end
    local names = API.FoodDrinkNames()
    say("Probe: food spell " .. tostring(names.food) .. ", drink spell " .. tostring(names.drink) .. ".")
    for _, item in ipairs(API.BagItems()) do
        if item.classID == Kinds.CONSUMABLE then
            local keys = Kinds.Matching(item, names)
            say(string.format("Probe: %d %s ilvl %s req %s sub %s spell %s -> %s", item.itemID,
                tostring(item.name), tostring(item.itemLevel), tostring(item.minLevel), tostring(item.subclassID),
                tostring(item.spellName), #keys > 0 and table.concat(keys, ", ") or "none"))
        end
    end
    for _, kind in ipairs(Kinds.LIST) do
        local index = Macro.Index(kind)
        if index then
            say("Probe: " .. kind.label .. " macro #" .. index .. " is in " .. #API.MacroButtons(index)
                .. " visible slot(s).")
        else
            say("Probe: " .. kind.label .. " macro isn't made yet.")
        end
    end
    local state = snippets == nil and "not checked yet" or (snippets and "work" or "don't work")
    say("Probe: secure snippets " .. state .. ".")
    local trips, Travel = {}, ns.Travel
    for _, entry in ipairs(Travel.Entries(API.KnownSpells(Travel.SpellIDs()), API.Carried(Travel.ItemIDs()))) do
        trips[#trips + 1] = tostring(entry.spellID or entry.itemID) .. " " .. tostring(entry.name)
    end
    say("Probe: travel -> " .. (#trips > 0 and table.concat(trips, ", ") or "nothing known"))
    for name, message in pairs(API.Errors()) do
        say("Probe: " .. name .. " threw: " .. message)
    end
end

for _, kind in ipairs(Kinds.LIST) do
    commands[kind.key] = function()
        if Core.PickUp(kind) then
            say("Click an action bar slot to place the " .. kind.label .. " button.")
        end
    end
end

local function slash(msg)
    local word, rest = string.match(msg or "", "^%s*(%S*)%s*(.-)%s*$")
    local command = commands[string.lower(word or "")]
    if command then
        command(string.lower(rest or ""))
    else
        say(HELP)
    end
end

-- Makes every toggle, the options page and the minimap button. Secure frames
-- can't be made in combat, so after a /reload in combat this waits for the
-- fight to end.
local function setup()
    snippets = API.SnippetsWork()
    for _, kind in ipairs(Kinds.LIST) do
        Macro.Tidy(kind)  -- the short name, for a macro the first builds named after the label
        if kind.secure and snippets then
            Bar.MakeSecureToggle(kind, function()
                guard("Open", function()
                    local message = Bar.BeforeSecureClick(kind, Core.Layout(kind.key))
                    if message then
                        say(message)
                    end
                end)
            end)
        else
            Bar.MakePlainToggle(kind, function()
                guard("Open", function()
                    local message = Bar.TogglePlain(kind, Core.Layout(kind.key))
                    if message then
                        say(message)
                    end
                end)
            end)
        end
    end
    Bar.LinkSecure()
    Bar.SetEscape(true)
    if not snippets then
        say("Secure snippets don't work on this client build, so potions, elixirs, bandages and scrolls "
            .. "open out of combat only.")
    end
    if not Options.Register(Core.ToggleWindow) then
        say("Couldn't add the options page; /gf still opens the window.")
    end
    MinimapButton.Create(Core)
end

local ready = false
local function trySetup()
    if ready or API.InCombat() then
        return
    end
    ready = true
    guard("Setup", setup)
end

API.OnEvents({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED" }, trySetup)

API.OnEvents({ "GLOBAL_MOUSE_DOWN" }, function()
    guard("Close on click", Bar.CloseUnlessMouseOver)
end)

API.OnEvents({ "ACTIONBAR_PAGE_CHANGED" }, function()
    guard("Close", Bar.CloseAll)
end)

API.OnEvents({ "PLAYER_REGEN_DISABLED" }, function()
    guard("Combat", Bar.EnterCombat, Core.Layout)
end)

API.OnEvents({ "PLAYER_REGEN_ENABLED" }, function()
    guard("Combat", Bar.LeaveCombat, Core.Layout)
end)

-- A macro changed (an icon picked in Blizzard's macro window): the rows follow.
API.OnEvents({ "UPDATE_MACROS" }, function()
    guard("Window", Window.Refresh, Core)
end)

API.OnEvents({ "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN" }, function()
    guard("Counts", Bar.Refresh)
end)

SLASH_GOBLINFLYOUT1 = "/gf"
SLASH_GOBLINFLYOUT2 = "/goblinflyout"
SlashCmdList.GOBLINFLYOUT = function(msg) guard("Slash", slash, msg) end

return Core
