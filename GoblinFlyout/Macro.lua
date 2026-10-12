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
    index = ns.API.CreateMacro(kind.label, kind.icon, Macro.Body(kind))
    if not index then
        return nil, "failed"
    end
    return index
end

-- Puts the kind's button on the cursor. nil when it did; else what went wrong.
-- Out of combat only: the macro may have to be made first.
function Macro.PickUp(kind)
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
    ns.API.PickupMacro(index)
    return nil
end

return Macro
