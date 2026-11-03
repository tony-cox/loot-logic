local _, ns, h = ...

return {
    ["a missing key returns its own name"] = function()
        h.Equal(ns.L.noSuchKey, "noSuchKey", "missing key value")
        h.Nil(rawget(ns.L, "noSuchKey"), "missing key is not stored")
    end,

    ["a defined key returns its string and formats"] = function()
        ns.L.itemDoesNotExist = "Item %d does not exist."
        h.Equal(ns.L.itemDoesNotExist, "Item %d does not exist.", "defined key value")
        h.Equal(
            string.format(ns.L.itemDoesNotExist, 42),
            "Item 42 does not exist.",
            "formatted text"
        )
    end,
}
