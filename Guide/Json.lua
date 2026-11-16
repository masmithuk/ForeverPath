--[[
    Questwalker - Guide/Json.lua

    A small, safe JSON encoder/decoder for guide import and export.

    * Decoding never runs code; it only builds tables, strings, numbers and
      booleans. Input size and nesting depth are capped, and errors report
      the line and column so players can find the problem.
    * Encoding pretty-prints with two-space indents. Object keys are written
      in a fixed order (see `keyOrder`) so exports are stable and diffable.
    * JSON null decodes to nil (so a null inside a list is dropped). Empty
      arrays and objects both decode to {}; the guide schema knows which.
]]

local _, ns = ...

local Json = {}
ns.Json = Json

Json.MAX_LENGTH = 200000
Json.MAX_DEPTH = 20

---------------------------------------------------------------------------
-- Encoding
---------------------------------------------------------------------------

local ESCAPES = {
    ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
    ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
}

local function encodeString(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        return ESCAPES[c] or ("\\u%04x"):format(c:byte())
    end) .. '"'
end

local function isArray(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then return false end
        n = n + 1
    end
    for i = 1, n do if t[i] == nil then return false end end
    return true
end

local function encodeNumber(n)
    if n ~= n or n == math.huge or n == -math.huge then
        error("can't encode " .. tostring(n) .. " as JSON")
    end
    if n == math.floor(n) and math.abs(n) < 1e15 then
        return ("%d"):format(n)
    end
    return ("%.14g"):format(n)
end

--- Whether a short array of scalars can go on one line.
local function inlineable(t)
    if #t > 12 then return false end
    for _, v in ipairs(t) do
        if type(v) == "table" then return false end
    end
    return true
end

local encodeValue

local function encodeTable(t, indent, keyOrder)
    local pad = ("  "):rep(indent)
    local inner = ("  "):rep(indent + 1)

    if isArray(t) then
        if #t == 0 then return "[]" end
        local parts = {}
        for i, v in ipairs(t) do parts[i] = encodeValue(v, indent + 1, keyOrder) end
        if inlineable(t) then return "[" .. table.concat(parts, ", ") .. "]" end
        return "[\n" .. inner .. table.concat(parts, ",\n" .. inner) .. "\n" .. pad .. "]"
    end

    local keys = {}
    for k in pairs(t) do
        if type(k) ~= "string" then error("JSON object keys must be strings") end
        keys[#keys + 1] = k
    end
    local rank = {}
    for i, k in ipairs(keyOrder or {}) do rank[k] = i end
    table.sort(keys, function(a, b)
        local ra, rb = rank[a] or math.huge, rank[b] or math.huge
        if ra ~= rb then return ra < rb end
        return a < b
    end)
    if #keys == 0 then return "{}" end

    local parts = {}
    for i, k in ipairs(keys) do
        parts[i] = encodeString(k) .. ": " .. encodeValue(t[k], indent + 1, keyOrder)
    end
    return "{\n" .. inner .. table.concat(parts, ",\n" .. inner) .. "\n" .. pad .. "}"
end

encodeValue = function(v, indent, keyOrder)
    local kind = type(v)
    if kind == "string" then return encodeString(v) end
    if kind == "number" then return encodeNumber(v) end
    if kind == "boolean" then return tostring(v) end
    if kind == "table" then return encodeTable(v, indent, keyOrder) end
    error("can't encode a " .. kind .. " as JSON")
end

--- Encode a value as pretty-printed JSON.
-- @param keyOrder optional list of keys to write first, in this order
function Json.Encode(value, keyOrder)
    return encodeValue(value, 0, keyOrder)
end

---------------------------------------------------------------------------
-- Decoding
---------------------------------------------------------------------------

local Decoder = {}
Decoder.__index = Decoder

function Decoder:fail(message)
    -- Work out line and column of the current position.
    local line, col = 1, 1
    for i = 1, math.min(self.pos - 1, #self.text) do
        if self.text:sub(i, i) == "\n" then line, col = line + 1, 1 else col = col + 1 end
    end
    error({ line = line, column = col, message = message }, 0)
end

function Decoder:skip()
    while true do
        local _, e = self.text:find("^[ \t\r\n]+", self.pos)
        if e then self.pos = e + 1 end
        -- Allow // line comments as a convenience for hand-written guides.
        if self.text:sub(self.pos, self.pos + 1) == "//" then
            local nl = self.text:find("\n", self.pos, true)
            self.pos = nl and nl + 1 or #self.text + 1
        else
            return
        end
    end
end

function Decoder:peek()
    self:skip()
    return self.text:sub(self.pos, self.pos)
end

function Decoder:expect(c)
    if self:peek() ~= c then
        self:fail(("expected '%s'"):format(c))
    end
    self.pos = self.pos + 1
end

local UNESCAPE = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }

local function utf8char(code)
    if code < 0x80 then return string.char(code) end
    if code < 0x800 then
        return string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64)
    end
    return string.char(0xE0 + math.floor(code / 4096), 0x80 + math.floor(code / 64) % 64, 0x80 + code % 64)
end

function Decoder:string()
    self.pos = self.pos + 1 -- opening quote
    local out = {}
    while true do
        local c = self.text:sub(self.pos, self.pos)
        if c == "" then self:fail("unterminated string") end
        if c == '"' then
            self.pos = self.pos + 1
            return table.concat(out)
        elseif c == "\\" then
            local e = self.text:sub(self.pos + 1, self.pos + 1)
            if UNESCAPE[e] then
                out[#out + 1] = UNESCAPE[e]
                self.pos = self.pos + 2
            elseif e == "u" then
                local hex = self.text:sub(self.pos + 2, self.pos + 5)
                if not hex:match("^%x%x%x%x$") then self:fail("bad \\u escape") end
                out[#out + 1] = utf8char(tonumber(hex, 16))
                self.pos = self.pos + 6
            else
                self:fail("bad escape \\" .. e)
            end
        elseif c == "\n" then
            self:fail("line break inside a string (use \\n)")
        else
            out[#out + 1] = c
            self.pos = self.pos + 1
        end
    end
end

function Decoder:number()
    local s, e = self.text:find("^-?%d+%.?%d*[eE]?[-+]?%d*", self.pos)
    if not s then self:fail("bad number") end
    local n = tonumber(self.text:sub(s, e))
    if not n then self:fail("bad number") end
    self.pos = e + 1
    return n
end

function Decoder:value(depth)
    if depth > Json.MAX_DEPTH then self:fail("nested too deeply") end
    local c = self:peek()
    if c == "{" then return self:object(depth) end
    if c == "[" then return self:array(depth) end
    if c == '"' then return self:string() end
    if c == "-" or c:match("%d") then return self:number() end
    for word, value in pairs({ ["true"] = true, ["false"] = false, ["null"] = false }) do
        if self.text:sub(self.pos, self.pos + #word - 1) == word then
            self.pos = self.pos + #word
            if word == "null" then return nil end
            return value
        end
    end
    if c == "" then self:fail("unexpected end of text") end
    self:fail(("unexpected '%s'"):format(c))
end

function Decoder:array(depth)
    self.pos = self.pos + 1
    local out = {}
    if self:peek() == "]" then self.pos = self.pos + 1; return out end
    while true do
        out[#out + 1] = self:value(depth + 1)
        local c = self:peek()
        if c == "]" then self.pos = self.pos + 1; return out end
        if c ~= "," then self:fail("expected ',' or ']'") end
        self.pos = self.pos + 1
        if self:peek() == "]" then self.pos = self.pos + 1; return out end -- trailing comma
    end
end

function Decoder:object(depth)
    self.pos = self.pos + 1
    local out = {}
    if self:peek() == "}" then self.pos = self.pos + 1; return out end
    while true do
        if self:peek() ~= '"' then self:fail("expected a \"key\"") end
        local key = self:string()
        self:expect(":")
        out[key] = self:value(depth + 1)
        local c = self:peek()
        if c == "}" then self.pos = self.pos + 1; return out end
        if c ~= "," then self:fail("expected ',' or '}'") end
        self.pos = self.pos + 1
        if self:peek() == "}" then self.pos = self.pos + 1; return out end -- trailing comma
    end
end

--- Decode JSON text.
-- @return value, or nil and an error { line, column, message }
function Json.Decode(text)
    if type(text) ~= "string" then
        return nil, { message = "nothing to read" }
    end
    if #text > Json.MAX_LENGTH then
        return nil, { message = "text is too long" }
    end
    local d = setmetatable({ text = text, pos = 1 }, Decoder)
    local ok, result = pcall(function()
        local v = d:value(1)
        if d:peek() ~= "" then d:fail("unexpected text after the end") end
        return v
    end)
    if ok then return result end
    if type(result) == "table" then return nil, result end
    return nil, { message = tostring(result) }
end
