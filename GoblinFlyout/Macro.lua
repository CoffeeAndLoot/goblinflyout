local _, ns = ...

-- A kind's button (spec 2026-10-12-goblin-flyout-design.md): an account-wide
-- macro whose only line clicks the kind's toggle. Ours is found by its body,
-- never its name, so a player's own "Potions" macro is never touched. Body and
-- IsOurs are pure; the rest goes through ns.API when called.
local Macro = {}
ns.Macro = Macro

function Macro.Body(kind)
    return "/click " .. kind.toggle
end

function Macro.IsOurs(kind, body)
    if type(kind) ~= "table" or type(body) ~= "string" then
        return false
    end
    return string.match(body, "^%s*(.-)%s*$") == Macro.Body(kind)
end

function Macro.Index(kind)
    return ns.API.FindMacro(function(body)
        return Macro.IsOurs(kind, body)
    end)
end

-- The kind's macro index, made if missing; or nil and "full" / "failed".
function Macro.Ensure(kind)
    local index = Macro.Index(kind)
    if index then
        return index
    end
    if ns.API.AccountMacrosFull() then
        return nil, "full"
    end
    index = ns.API.CreateMacro(kind.macro, kind.icon, Macro.Body(kind))
    if not index then
        return nil, "failed"
    end
    return index
end

-- Gives the kind's macro, if made, its short name: the first builds named it
-- after the label, which the action bar cuts off. Body and icon stay. Out of
-- combat only (Core calls it at setup).
function Macro.Tidy(kind)
    local index = Macro.Index(kind)
    if index and ns.API.MacroName(index) ~= kind.macro then
        ns.API.RenameMacro(index, kind.macro)
    end
end

-- The kind's macro icon: the one the player picked in Blizzard's macro window,
-- else the kind's default (no macro yet, or it won't say).
function Macro.Icon(kind)
    local index = Macro.Index(kind)
    return index and ns.API.MacroIcon(index) or ("Interface\\Icons\\" .. kind.icon)
end

-- Runs act(index) on the kind's macro, made first if missing. nil when it ran;
-- else what went wrong. Out of combat only: CreateMacro may be needed.
local function withMacro(kind, act)
    if ns.API.InCombat() then
        return "Can't do that in combat."
    end
    local index, problem = Macro.Ensure(kind)
    if problem == "full" then
        return "Your account macros are full. Delete one and try again."
    end
    if not index then
        return "Couldn't make the " .. kind.label .. " macro."
    end
    act(index)
    return nil
end

-- Puts the kind's button on the cursor.
function Macro.PickUp(kind)
    return withMacro(kind, ns.API.PickupMacro)
end

-- Opens Blizzard's macro window on the kind's macro, its icon picker open.
function Macro.Edit(kind)
    return withMacro(kind, ns.API.OpenMacroEditor)
end

return Macro
