--[[
    Test runner. From the repository root:

        lua5.1 tests/run.lua

    Exits non-zero if any test fails, so it can gate CI.
]]

package.path = "./tests/?.lua;" .. package.path

local mock = require("wow_mock")

local T = { passed = 0, failed = 0, failures = {} }

function T.eq(actual, expected, msg)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(msg or "eq", tostring(expected), tostring(actual)), 2)
    end
end

function T.truthy(value, msg)
    if not value then error((msg or "expected truthy value"), 2) end
end

function T.contains(haystack, needle, msg)
    if type(haystack) == "table" then
        for _, v in ipairs(haystack) do
            if v == needle then return end
        end
    elseif type(haystack) == "string" and haystack:find(needle, 1, true) then
        return
    end
    error(("%s: %q not found"):format(msg or "contains", tostring(needle)), 2)
end

--- Fresh client + addon for every test, so state never leaks between cases.
function T.fresh()
    mock.install()
    return T.reload()
end

--- Reload the addon but keep saved variables, like a /reload or relog.
function T.reload()
    local ns = mock.loadAddon(".", "ForeverPath")
    ns:FireEvent("ADDON_LOADED", "ForeverPath")
    return ns, mock
end

local function run(file)
    local cases = dofile(file)
    for _, case in ipairs(cases) do
        local ok, err = pcall(case[2], T)
        if ok then
            T.passed = T.passed + 1
        else
            T.failed = T.failed + 1
            T.failures[#T.failures + 1] = file .. " :: " .. case[1] .. "\n    " .. tostring(err)
        end
    end
end

local realPrint = print
run("tests/test_data.lua")
run("tests/test_character.lua")
run("tests/test_advisor.lua")
run("tests/test_ui.lua")
run("tests/test_planner.lua")
run("tests/test_questiedata.lua")
run("tests/test_engine.lua")
run("tests/test_browser.lua")
run("tests/test_modes.lua")

realPrint(("%d passed, %d failed"):format(T.passed, T.failed))
for _, f in ipairs(T.failures) do realPrint("FAIL " .. f) end
os.exit(T.failed == 0 and 0 or 1)
