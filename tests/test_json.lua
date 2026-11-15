-- The JSON encoder/decoder.

return {
    { "decodes every JSON type", function(T)
        local ns = T.fresh()
        local v, err = ns.Json.Decode([[{"a": 1, "b": -2.5e1, "c": "x\"y\\né", "d": [true, false, null, 3],
            "e": {}, "f": []}]])
        T.truthy(v, err and err.message)
        T.eq(v.a, 1)
        T.eq(v.b, -25)
        T.eq(v.c, 'x"y\\n\195\169')
        T.eq(v.d[1], true)
        T.eq(v.d[2], false)
        T.eq(v.d[3], 3, "null inside a list is dropped")
        T.eq(next(v.e), nil)
    end },

    { "errors give line and column", function(T)
        local ns = T.fresh()
        local _, err = ns.Json.Decode('{\n  "a": 1,\n  "b" 2\n}')
        T.eq(err.line, 3)
        T.eq(err.column, 7)
        T.contains(err.message, "expected ':'")
    end },

    { "rejects broken input instead of guessing", function(T)
        local ns = T.fresh()
        for _, bad in ipairs({ '{"a": }', '[1, 2', '"open', '{"a": 1} extra', "{'a': 1}", "{a: 1}" }) do
            local v, err = ns.Json.Decode(bad)
            T.eq(v, nil, bad)
            T.truthy(err and err.message, "message for " .. bad)
        end
    end },

    { "is forgiving about trailing commas and // comments", function(T)
        local ns = T.fresh()
        local v = ns.Json.Decode('{\n  // my notes\n  "a": [1, 2,],\n}')
        T.eq(#v.a, 2)
    end },

    { "limits nesting depth and size", function(T)
        local ns = T.fresh()
        local _, err = ns.Json.Decode(("["):rep(50) .. ("]"):rep(50))
        T.contains(err.message, "nested too deeply")
        _, err = ns.Json.Decode('"' .. ("x"):rep(ns.Json.MAX_LENGTH) .. '"')
        T.contains(err.message, "too long")
    end },

    { "encode then decode round-trips", function(T)
        local ns = T.fresh()
        local value = { name = 'Say "hi"\n', list = { 1, 2, 3 }, nested = { { id = 7, ok = true } }, empty = {} }
        local back = ns.Json.Decode(ns.Json.Encode(value))
        T.eq(back.name, value.name)
        T.eq(back.list[3], 3)
        T.eq(back.nested[1].id, 7)
        T.eq(back.nested[1].ok, true)
    end },

    { "keys come out in the requested order", function(T)
        local ns = T.fresh()
        local text = ns.Json.Encode({ zebra = 1, name = "x", alpha = 2 }, { "name" })
        T.truthy(text:find('"name"') < text:find('"alpha"'), "name first")
        T.truthy(text:find('"alpha"') < text:find('"zebra"'), "then alphabetical")
    end },
}
