local _, ns, h = ...

local function Bag(fields, setup, slotFields)
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    h.Stub.FireEvent("PLAYER_LOGIN")
    if setup then
        setup()
    end
    local item = {
        name = "Example",
        quality = 1,
        classID = 7,
        subclassID = 5,
        sellPrice = 10,
    }
    for key, value in pairs(fields) do
        item[key] = value
    end
    h.Stub.SetItem(99901, item)
    h.Stub.SetTooltipLines("item:99901", {})
    h.Stub.SetBagSize(0, 1)
    local slot = { itemID = 99901, link = "item:99901", count = 1, quality = item.quality }
    for key, value in pairs(slotFields or {}) do
        slot[key] = value
    end
    h.Stub.SetBagItem(0, 1, slot)
    return ns.Classify.BagSlot(0, 1)
end

return {
    ["quest reason uses the locale string"] = function()
        h.Equal(Bag({ classID = 12 }).reasonText, ns.L.reasonQuest, "quest")
    end,

    ["refundable bag results add the locale suffix"] = function()
        local result = Bag({ classID = 0 }, nil, { refundSeconds = 3000 })
        h.Equal(result.reasonText, ns.L.reasonClassstay .. ns.L.reasonRefundable, "refund")
    end,

    ["no provider and no vendor value use both locale strings"] = function()
        local result = Bag({}, nil, { hasNoValue = true })
        h.Equal(result.reasonText, ns.L.reasonNoprovider .. ns.L.reasonNoVendorValue, "no value")
    end,

    ["whole-class want names the class"] = function()
        local result = Bag({}, function()
            LootLogicDB.characters[ns.Roster.HereKey()].asks = {
                types = { ["7:*"] = {} },
                items = {},
            }
        end)
        h.Equal(result.reasonText, string.format(ns.L.reasonWantedhere, "Trade Goods"), "class")
    end,

    ["bound vendor reason names the price"] = function()
        local result = Bag({ bindType = 1 }, nil, { bound = true })
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonVendorbound, ns.Util.FormatMoney(10)),
            "bound vendor"
        )
    end,

    ["a bound item with no value gives the no-value text"] = function()
        local result = Bag({ bindType = 1, sellPrice = 0 }, nil, { bound = true })
        h.Equal(result.reasonText, ns.L.reasonNovalue, "no value")
    end,

    ["no provider is named when a vendor value exists"] = function()
        h.Equal(Bag({}).reasonText, ns.L.reasonNoprovider, "no provider")
    end,

    ["stale price displays the provider label and age"] = function()
        local result = Bag({}, function()
            ns.Prices.Register({
                id = "fake",
                label = "Market",
                IsAvailable = function()
                    return true
                end,
                GetPrice = function()
                    return { unit = 1000, ageDays = 9 }
                end,
                HasData = function()
                    return true
                end,
                OnUpdate = function() end,
            })
        end)
        local expected = string.format(
            ns.L.reasonStale,
            string.format(ns.L.reasonAgeDays, 9),
            7,
            ns.Util.FormatMoney(1000),
            "Market"
        )
        h.Equal(result.reasonText, expected, "stale price")
    end,

    ["AH reason names a price read today as today, not 0 d"] = function()
        local result = Bag({}, function()
            ns.Prices.Register({
                id = "fake",
                label = "Market",
                IsAvailable = function()
                    return true
                end,
                GetPrice = function()
                    return { unit = 1000, ageDays = 0 }
                end,
                OnUpdate = function() end,
            })
        end)
        local expected = string.format(
            ns.L.reasonAh,
            ns.Util.FormatMoney(1000),
            ns.Util.FormatMoney(940),
            5,
            "Market",
            ns.L.reasonAgeToday
        )
        h.Equal(result.reasonText, expected, "AH text")
    end,

    ["AH reason displays per-unit gain, cut, provider and age"] = function()
        local result = Bag({}, function()
            ns.Prices.Register({
                id = "fake",
                label = "Market",
                IsAvailable = function()
                    return true
                end,
                GetPrice = function()
                    return { unit = 1000, ageDays = 2 }
                end,
                OnUpdate = function() end,
            })
        end)
        local expected = string.format(
            ns.L.reasonAh,
            ns.Util.FormatMoney(1000),
            ns.Util.FormatMoney(940),
            5,
            "Market",
            string.format(ns.L.reasonAgeDays, 2)
        )
        h.Equal(result.reasonText, expected, "AH text")
    end,

    ["unknown price age uses the over-21-days wording"] = function()
        local result = Bag({}, function()
            ns.Prices.Register({
                id = "fake",
                label = "Market",
                IsAvailable = function()
                    return true
                end,
                GetPrice = function()
                    return { unit = 1000 }
                end,
                OnUpdate = function() end,
            })
        end)
        h.Equal(
            result.reasonText,
            string.format(
                ns.L.reasonStale,
                ns.L.reasonAgeOver,
                7,
                ns.Util.FormatMoney(1000),
                "Market"
            ),
            "unknown age"
        )
    end,

    ["grey reason uses the locale string and money format"] = function()
        local grey = Bag({ quality = 0 })
        h.Equal(grey.reasonText, string.format(ns.L.reasonGrey, ns.Util.FormatMoney(10)), "grey")
    end,

    ["an include want names the item before the type"] = function()
        local function Want(types, items)
            return function()
                LootLogicDB.characters[ns.Roster.HereKey()].asks = { types = types, items = items }
            end
        end
        local exact = Bag({}, Want({ ["7:5"] = {} }, { [99901] = "include" }))
        h.Equal(exact.reasonText, string.format(ns.L.reasonWantedhere, "Example"), "include")
    end,

    ["a subclass want uses the qualified client name"] = function()
        local result = Bag({}, function()
            LootLogicDB.characters[ns.Roster.HereKey()].asks = {
                types = { ["7:5"] = {} },
                items = {},
            }
        end)
        local name = string.format(ns.L.typeQualified, "Trade Goods", "Cloth")
        h.Equal(result.reasonText, string.format(ns.L.reasonWantedhere, name), "subclass")
    end,

    ["link-only wants add the location suffix"] = function()
        Bag({}, function()
            LootLogicDB.characters[ns.Roster.HereKey()].asks = {
                types = {},
                items = { [99901] = "include" },
            }
        end)
        local result = ns.Classify.Link("item:99901")
        h.Equal(result.reasonCode, "wantedhere", "reason")
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonWantedhere, "Example") .. ns.L.reasonNotInBags,
            "link suffix"
        )
    end,

    ["link-only nobody retains its own wording once"] = function()
        Bag({})
        local result = ns.Classify.Link("item:99901")
        h.Equal(result.reasonCode, "nobody", "reason")
        h.Equal(result.reasonText, ns.L.reasonNobody, "nobody wording")
    end,

    ["type names include names after gaps and qualify duplicates"] = function()
        local classes = { [4] = "Armor", [7] = "Trade Goods", [20] = "Other" }
        local subclasses = {
            [4] = { [1] = "Cloth", [20] = "Unique" },
            [7] = { [5] = "Cloth", [7] = "Metal and Stone", [12] = "Trade Goods" },
        }
        h.Stub.SetItemTypeNames(classes, subclasses)
        h.Equal(ns.Util.TypeName(4), "Armor", "whole class")
        h.Equal(
            ns.Util.TypeName(4, 1),
            string.format(ns.L.typeQualified, "Armor", "Cloth"),
            "duplicate subclass"
        )
        h.Equal(
            ns.Util.TypeName(7, 12),
            string.format(ns.L.typeQualified, "Trade Goods", "Trade Goods"),
            "class duplicate"
        )
        h.Equal(ns.Util.TypeName(7, 7), "Metal and Stone", "unique subclass")
        h.Equal(ns.Util.TypeName(4, 20), "Unique", "after gap")
    end,
}
