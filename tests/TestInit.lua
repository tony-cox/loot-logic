local _, ns, h = ...

return {
    ["the code's schema number is 1"] = function()
        h.Equal(ns.Init.schemaVersion, 1, "schema number")
    end,

    ["the version is the TOC's Version line"] = function()
        h.Stub.SetAddOnMetadata("LootLogic", "Version", "1.2.3")
        h.Stub.SetAddOnMetadata("SomeOtherAddon", "Version", "9.9.9")
        h.Equal(ns.Init.Version(), "1.2.3", "version")
    end,
}
