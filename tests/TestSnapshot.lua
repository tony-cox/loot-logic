local _, ns, h = ...

local Generations = ns.Generations
local Snapshot = ns.Snapshot

local HERE = "Zugar Soulsour-Region"
local OTHER = "Boneset Hallowine-Region"

local CHEST = 100
local SWORD = 200
local SHIRT = 300
local COSMETIC = 400
local POTION = 500
local BAG = 600
local RING = 700

local function Link(itemID)
    return string.format("|cffffffff|Hitem:%d:0:0:0:0:0:0:0:60|h[Item %d]|h|r", itemID, itemID)
end

local function DefineItems()
    h.Stub.SetItemInstant(CHEST, { equipLoc = "INVTYPE_CHEST", classID = 4, subclassID = 2 })
    h.Stub.SetItemInstant(SWORD, { equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 7 })
    h.Stub.SetItemInstant(SHIRT, { equipLoc = "INVTYPE_BODY", classID = 4, subclassID = 0 })
    h.Stub.SetItemInstant(COSMETIC, { equipLoc = "INVTYPE_CLOAK", classID = 4, subclassID = 5 })
    h.Stub.SetItemInstant(POTION, { equipLoc = "", classID = 0, subclassID = 1 })
    h.Stub.SetItemInstant(BAG, { equipLoc = "INVTYPE_BAG", classID = 1, subclassID = 0 })
    h.Stub.SetItemInstant(RING, { equipLoc = "INVTYPE_FINGER", classID = 4, subclassID = 0 })
end

-- A fresh database; the current character logs in. Returns its saved entry.
local function Login()
    DefineItems()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    h.Stub.FireEvent("PLAYER_LOGIN")
    return LootLogicDB.characters[HERE]
end

-- As Login, with a second character of the same region on the roster.
local function LoginWithOther()
    DefineItems()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    LootLogicDB.characters[OTHER] = { first = "Boneset", last = "Hallowine", region = "Region" }
    LootLogicDB.order[1] = OTHER
    h.Stub.FireEvent("PLAYER_LOGIN")
    return LootLogicDB.characters[HERE], LootLogicDB.characters[OTHER]
end

local function Put(bag, slot, itemID, count)
    h.Stub.SetBagItem(bag, slot, { itemID = itemID, link = Link(itemID), count = count })
end

local function Bumps(name)
    return Generations.Get(name)
end

local function LastLog()
    local log = LootLogicDB.debug.log
    return log[#log]
end

local function Contains(text, part)
    return string.find(text, part, 1, true) ~= nil
end

return {
    ["Snapshot: gear takes the worn links of slots 1 to 19 and bumps gearHere once"] = function()
        local entry = Login()
        h.Stub.SetWornLink(1, Link(CHEST))
        h.Stub.SetWornLink(16, Link(SWORD))
        h.Stub.SetWornLink(4, Link(SHIRT))
        h.Stub.FireEvent("PLAYER_EQUIPMENT_CHANGED", 16, false)
        h.DeepEqual(entry.gear, {
            updatedAt = GetServerTime(),
            slots = { [1] = Link(CHEST), [4] = Link(SHIRT), [16] = Link(SWORD) },
        }, "gear")
        h.Equal(Bumps("gearHere"), 1, "one bump")
    end,

    ["Snapshot: an emptied slot is gone from the next gear snapshot"] = function()
        local entry = Login()
        h.Stub.SetWornLink(1, Link(CHEST))
        h.Stub.FireEvent("PLAYER_EQUIPMENT_CHANGED", 1, false)
        h.Stub.SetWornLink(1, nil)
        h.Stub.FireEvent("PLAYER_EQUIPMENT_CHANGED", 1, true)
        h.DeepEqual(entry.gear.slots, {}, "slots")
        h.Equal(Bumps("gearHere"), 2, "two changes, two bumps")
    end,

    ["Snapshot: proficiency keeps the known spells only"] = function()
        local entry = Login()
        h.Stub.SetKnownSpells({ 9077, 198, 12345 })
        h.Stub.FireEvent("SPELLS_CHANGED")
        h.DeepEqual(entry.proficiency, {
            updatedAt = GetServerTime(),
            spells = { [9077] = true, [198] = true },
        }, "proficiency")
        h.Equal(Bumps("gearHere"), 1, "one bump")
    end,

    ["Snapshot: the equipment event also takes the proficiency"] = function()
        local entry = Login()
        h.Stub.SetKnownSpells({ 750 })
        h.Stub.FireEvent("PLAYER_EQUIPMENT_CHANGED", 1, false)
        h.DeepEqual(entry.proficiency.spells, { [750] = true }, "spells")
    end,

    ["Snapshot: entering the world at initial login takes one debounced full snapshot"] = function()
        local entry = Login()
        h.Stub.SetWornLink(1, Link(CHEST))
        h.Stub.SetKnownSpells({ 9077 })
        Put(0, 1, SWORD, 1)
        h.Stub.SetBagSize(0, 1)
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD", true, false)
        h.Stub.Advance(Snapshot.DEBOUNCE_SECONDS / 2)
        h.Nil(entry.gear, "not yet")
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD", true, false)
        h.Stub.Advance(Snapshot.DEBOUNCE_SECONDS / 2)
        h.Nil(entry.gear, "the second event restarted the wait")
        h.Stub.Advance(Snapshot.DEBOUNCE_SECONDS)
        h.DeepEqual(entry.gear.slots, { [1] = Link(CHEST) }, "gear")
        h.DeepEqual(entry.proficiency.spells, { [9077] = true }, "proficiency")
        h.DeepEqual(entry.bags.gear, { Link(SWORD) }, "bags")
        h.Equal(Bumps("gearHere"), 1, "one bump for the whole snapshot")
    end,

    ["Snapshot: entering the world after a reload takes the snapshot"] = function()
        local entry = Login()
        h.Stub.SetWornLink(1, Link(CHEST))
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD", false, true)
        h.Stub.Advance(Snapshot.DEBOUNCE_SECONDS)
        h.DeepEqual(entry.gear.slots, { [1] = Link(CHEST) }, "gear")
    end,

    ["Snapshot: entering the world on a zone change takes no snapshot"] = function()
        local entry = Login()
        h.Stub.SetWornLink(1, Link(CHEST))
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD", false, false)
        h.Stub.Advance(60)
        h.Nil(entry.gear, "gear")
        h.Nil(entry.bags, "bags")
        h.Equal(Bumps("gearHere"), 0, "no bump")
    end,

    ["Snapshot: the level comes from the event argument"] = function()
        local entry = Login()
        h.Stub.SetPlayer({ level = 23 })
        h.Stub.SetWornLink(1, Link(CHEST))
        h.Stub.FireEvent("PLAYER_LEVEL_UP", 24)
        h.Equal(entry.level, 24, "level")
        h.DeepEqual(entry.gear.slots, { [1] = Link(CHEST) }, "gear")
        h.True(entry.proficiency, "proficiency")
        h.Equal(Bumps("gearHere"), 1, "one bump")
    end,

    ["Snapshot: a level event without a number leaves the level"] = function()
        local entry = Login()
        local before = entry.level
        h.Stub.FireEvent("PLAYER_LEVEL_UP", nil)
        h.Equal(entry.level, before, "level")
    end,

    ["Snapshot: bags take equippable links and counts of bags 0 to 5"] = function()
        local entry = Login()
        h.Stub.SetBagSize(0, 4)
        h.Stub.SetBagSize(5, 2)
        h.Stub.SetBagSize(6, 2)
        Put(0, 1, CHEST, 1)
        Put(0, 2, POTION, 5)
        Put(0, 3, POTION, 3)
        Put(5, 1, RING, 1)
        Put(6, 1, SWORD, 1)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.DeepEqual(entry.bags, {
            updatedAt = GetServerTime(),
            gear = { Link(CHEST), Link(RING) },
            ids = { [CHEST] = 1, [POTION] = 8, [RING] = 1 },
        }, "bags")
        h.Nil(entry.bank, "bank tab 6 is not a bag")
    end,

    ["Snapshot: shirts, bags and cosmetic armour are not equippable gear"] = function()
        local entry = Login()
        h.Stub.SetBagSize(0, 3)
        Put(0, 1, SHIRT, 1)
        Put(0, 2, BAG, 1)
        Put(0, 3, COSMETIC, 1)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.DeepEqual(entry.bags.gear, {}, "gear")
        h.DeepEqual(entry.bags.ids, { [SHIRT] = 1, [BAG] = 1, [COSMETIC] = 1 }, "ids")
        h.Equal(Bumps("gearHere"), 0, "no equippable change, no bump")
    end,

    ["Snapshot: a bag slot with a secret link is left out"] = function()
        local entry = Login()
        h.Stub.SetBagSize(0, 2)
        h.Stub.SetBagItem(0, 1, { itemID = CHEST, link = h.Stub.MakeSecret(), count = 1 })
        Put(0, 2, RING, 1)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.DeepEqual(entry.bags.gear, { Link(RING) }, "gear")
    end,

    ["Snapshot: bags bump gearHere when an equippable item enters, leaves or moves"] = function()
        Login()
        h.Stub.SetBagSize(0, 3)
        h.Stub.SetBagSize(1, 3)
        Put(0, 1, CHEST, 1)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.Equal(Bumps("gearHere"), 1, "entered")
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.Equal(Bumps("gearHere"), 1, "nothing changed")
        Put(0, 2, POTION, 4)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.Equal(Bumps("gearHere"), 1, "a potion is not gear")
        h.Stub.SetBagItem(0, 1, nil)
        Put(1, 2, CHEST, 1)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.Equal(Bumps("gearHere"), 2, "moved to another bag")
        h.Stub.SetBagItem(1, 2, nil)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.Equal(Bumps("gearHere"), 3, "left")
    end,

    ["Snapshot: the bank is read only while it is open"] = function()
        local entry = Login()
        h.Stub.SetBagSize(6, 2)
        Put(6, 1, SWORD, 1)
        Put(6, 2, POTION, 7)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.Nil(entry.bank, "closed bank not read")
        h.Equal(Snapshot.IsBankOpen(), false, "starts closed")
        h.Stub.OpenBank()
        h.Equal(Snapshot.IsBankOpen(), true, "open")
        h.DeepEqual(entry.bank, {
            updatedAt = GetServerTime(),
            gear = { Link(SWORD) },
            ids = { [SWORD] = 1, [POTION] = 7 },
        }, "bank")
        h.Equal(Bumps("gearHere"), 1, "the open snapshot bumps once")
    end,

    ["Snapshot: a bank tab with no slots is skipped"] = function()
        local entry = Login()
        h.Stub.SetBagSize(6, 1)
        h.Stub.SetBagSize(8, 1)
        Put(6, 1, CHEST, 1)
        Put(8, 1, RING, 1)
        h.Stub.OpenBank()
        h.DeepEqual(entry.bank.gear, { Link(CHEST), Link(RING) }, "tabs 1 and 3 only")
    end,

    ["Snapshot: bank IDs come from Enum.BagIndex"] = function()
        local entry = Login()
        h.Stub.SetBagIndex("CharacterBankTab_1", 20)
        h.Stub.SetBagSize(20, 1)
        h.Stub.SetBagSize(6, 1)
        Put(20, 1, CHEST, 1)
        Put(6, 1, RING, 1)
        h.Stub.OpenBank()
        h.DeepEqual(entry.bank.gear, { Link(CHEST) }, "tab 1 is bag 20, bag 6 is no longer a tab")
    end,

    ["Snapshot: the bank is re-read while open and its snapshot stays after close"] = function()
        local entry = Login()
        h.Stub.SetBagSize(6, 2)
        Put(6, 1, SWORD, 1)
        h.Stub.OpenBank()
        Put(6, 2, RING, 1)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.DeepEqual(entry.bank.gear, { Link(SWORD), Link(RING) }, "re-read while open")
        h.Stub.CloseBank()
        h.Equal(Snapshot.IsBankOpen(), false, "closed")
        h.Stub.SetBagItem(6, 1, nil)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.DeepEqual(entry.bank.gear, { Link(SWORD), Link(RING) }, "kept after close")
        h.Equal(Snapshot.TakeBank(), nil, "no manual bank snapshot while closed")
    end,

    ["Snapshot: a reload starts with the bank closed and keeps its snapshot"] = function()
        local entry = Login()
        entry.bank = { updatedAt = 5, gear = { Link(SWORD) }, ids = { [SWORD] = 1 } }
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD", false, true)
        h.Stub.Advance(Snapshot.DEBOUNCE_SECONDS)
        h.Equal(Snapshot.IsBankOpen(), false, "closed")
        h.DeepEqual(entry.bank, {
            updatedAt = 5,
            gear = { Link(SWORD) },
            ids = { [SWORD] = 1 },
        }, "bank kept")
    end,

    ["Snapshot: bags and bank in one event bump gearHere once"] = function()
        Login()
        h.Stub.SetBagSize(0, 1)
        h.Stub.SetBagSize(6, 1)
        h.Stub.OpenBank()
        local before = Bumps("gearHere")
        Put(0, 1, CHEST, 1)
        Put(6, 1, RING, 1)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.Equal(Bumps("gearHere"), before + 1, "one bump")
    end,

    ["Snapshot: the inbox takes the attachments of every mail"] = function()
        local entry = Login()
        h.Stub.SetInbox({
            { items = { { link = Link(CHEST), count = 1 }, { link = Link(POTION), count = 5 } } },
            { items = { { link = Link(POTION), count = 2 } } },
            { items = {} },
        })
        h.Stub.FireEvent("MAIL_SHOW")
        h.DeepEqual(entry.inbox, {
            updatedAt = GetServerTime(),
            gear = { Link(CHEST) },
            ids = { [CHEST] = 1, [POTION] = 7 },
        }, "inbox")
        h.Equal(Bumps("gearHere"), 1, "MAIL_SHOW bumps once")
        h.Stub.FireEvent("MAIL_INBOX_UPDATE")
        h.Equal(Bumps("gearHere"), 2, "MAIL_INBOX_UPDATE bumps once")
    end,

    ["Snapshot: an inbound entry is cleared by a matching attachment"] = function()
        local entry = Login()
        entry.inbound = {
            { sentAt = GetServerTime(), from = OTHER, id = CHEST, link = Link(CHEST), count = 1 },
            { sentAt = GetServerTime(), from = OTHER, id = POTION, link = Link(POTION), count = 5 },
        }
        h.Stub.SetInbox({ { items = { { link = Link(CHEST), count = 1 } } } })
        h.Stub.FireEvent("MAIL_INBOX_UPDATE")
        h.Equal(#entry.inbound, 1, "one left")
        h.Equal(entry.inbound[1].id, POTION, "the one still in transit")
    end,

    ["Snapshot: an attachment with another count does not clear the entry"] = function()
        local entry = Login()
        entry.inbound = {
            { sentAt = GetServerTime(), from = OTHER, id = POTION, link = Link(POTION), count = 5 },
        }
        h.Stub.SetInbox({ { items = { { link = Link(POTION), count = 4 } } } })
        h.Stub.FireEvent("MAIL_INBOX_UPDATE")
        h.Equal(#entry.inbound, 1, "kept")
    end,

    ["Snapshot: one attachment clears one entry"] = function()
        local entry = Login()
        local item = { sentAt = GetServerTime(), from = OTHER, id = POTION, count = 5 }
        entry.inbound = { item, { sentAt = item.sentAt, from = OTHER, id = POTION, count = 5 } }
        h.Stub.SetInbox({ { items = { { link = Link(POTION), count = 5 } } } })
        h.Stub.FireEvent("MAIL_INBOX_UPDATE")
        h.Equal(#entry.inbound, 1, "one cleared")
    end,

    ["Snapshot: an unchanged attachment does not clear a second identical entry"] = function()
        local entry = Login()
        local item = { sentAt = GetServerTime(), from = OTHER, id = POTION, count = 5 }
        entry.inbound = { item, { sentAt = item.sentAt, from = OTHER, id = POTION, count = 5 } }
        h.Stub.SetInbox({ { items = { { link = Link(POTION), count = 5 } } } })
        h.Stub.FireEvent("MAIL_SHOW")
        h.Stub.FireEvent("MAIL_INBOX_UPDATE")
        h.Equal(#entry.inbound, 1, "still one in transit")
    end,

    ["Snapshot: an inbound entry older than 30 days is cleared, a newer one kept"] = function()
        local entry = Login()
        local now = GetServerTime()
        local day = 24 * 60 * 60
        entry.inbound = {
            { sentAt = now - 31 * day, from = OTHER, id = CHEST, link = Link(CHEST), count = 1 },
            { sentAt = now - 29 * day, from = OTHER, id = RING, link = Link(RING), count = 1 },
        }
        h.Stub.FireEvent("MAIL_SHOW")
        h.Equal(#entry.inbound, 1, "one left")
        h.Equal(entry.inbound[1].id, RING, "the newer one")
    end,

    ["Snapshot: each cleared inbound entry writes a mail debug line"] = function()
        local entry = Login()
        LootLogicDB.debug.enabled = true
        local now = GetServerTime()
        entry.inbound = {
            { sentAt = now, from = OTHER, id = CHEST, link = Link(CHEST), count = 1 },
            { sentAt = now - 40 * 24 * 60 * 60, from = OTHER, id = RING, count = 1 },
        }
        h.Stub.SetInbox({ { items = { { link = Link(CHEST), count = 1 } } } })
        h.Stub.FireEvent("MAIL_INBOX_UPDATE")
        local seen = 0
        local old = 0
        for _, line in ipairs(LootLogicDB.debug.log) do
            if Contains(line, "mail: inbound entry cleared, seen in the inbox: item 100 x1") then
                seen = seen + 1
            end
            if Contains(line, "mail: inbound entry cleared, older than 30 days: item 700 x1") then
                old = old + 1
            end
        end
        h.Equal(seen, 1, "seen line")
        h.Equal(old, 1, "old line")
    end,

    ["Snapshot: a sent mail to a roster character adds inbound entries on success"] = function()
        local here, other = LoginWithOther()
        h.Stub.SetSendMailItems({
            { link = Link(CHEST), count = 1 },
            { link = Link(POTION), count = 3 },
        })
        SendMail("boneset HALLOWINE", "subject", "body")
        h.Nil(other.inbound, "nothing before success")
        h.Stub.FireEvent("MAIL_SEND_SUCCESS")
        local now = GetServerTime()
        h.DeepEqual(other.inbound, {
            { sentAt = now, from = HERE, id = CHEST, link = Link(CHEST), count = 1 },
            { sentAt = now, from = HERE, id = POTION, link = Link(POTION), count = 3 },
        }, "inbound")
        h.Equal(Bumps("gearOthers"), 1, "one gearOthers bump")
        h.Equal(Bumps("gearHere"), 0, "no gearHere bump")
        h.Nil(here.inbound, "here has none")
    end,

    ["Snapshot: a sent mail is recorded once"] = function()
        local _, other = LoginWithOther()
        h.Stub.SetSendMailItems({ { link = Link(CHEST), count = 1 } })
        SendMail("Boneset Hallowine", "s", "b")
        h.Stub.FireEvent("MAIL_SEND_SUCCESS")
        h.Stub.FireEvent("MAIL_SEND_SUCCESS")
        h.Equal(#other.inbound, 1, "one entry")
    end,

    ["Snapshot: a sent mail to a stranger adds nothing"] = function()
        local here, other = LoginWithOther()
        h.Stub.SetSendMailItems({ { link = Link(CHEST), count = 1 } })
        SendMail("Nobody Known", "s", "b")
        h.Stub.FireEvent("MAIL_SEND_SUCCESS")
        h.Nil(other.inbound, "other")
        h.Nil(here.inbound, "here")
        h.Equal(Bumps("gearOthers"), 0, "no bump")
    end,

    ["Snapshot: a roster character of another region is not a recipient"] = function()
        local _, other = LoginWithOther()
        other.region = "Elsewhere"
        h.Stub.SetSendMailItems({ { link = Link(CHEST), count = 1 } })
        SendMail("Boneset Hallowine", "s", "b")
        h.Stub.FireEvent("MAIL_SEND_SUCCESS")
        h.Nil(other.inbound, "other")
    end,

    ["Snapshot: a failed mail drops the capture"] = function()
        local _, other = LoginWithOther()
        h.Stub.SetSendMailItems({ { link = Link(CHEST), count = 1 } })
        SendMail("Boneset Hallowine", "s", "b")
        h.Stub.FireEvent("MAIL_FAILED")
        h.Stub.FireEvent("MAIL_SEND_SUCCESS")
        h.Nil(other.inbound, "nothing recorded")
        h.Equal(Bumps("gearOthers"), 0, "no bump")
    end,

    ["Snapshot: a success with no captured mail adds nothing"] = function()
        local _, other = LoginWithOther()
        h.Stub.FireEvent("MAIL_SEND_SUCCESS")
        h.Nil(other.inbound, "nothing recorded")
    end,

    ["Snapshot: a mail with no attachments adds nothing and bumps nothing"] = function()
        local _, other = LoginWithOther()
        SendMail("Boneset Hallowine", "s", "b")
        h.Stub.FireEvent("MAIL_SEND_SUCCESS")
        h.DeepEqual(other.inbound or {}, {}, "nothing recorded")
        h.Equal(Bumps("gearOthers"), 0, "no bump")
    end,

    ["Snapshot: the mail debug lines show the capture, the entry and a failure"] = function()
        LoginWithOther()
        LootLogicDB.debug.enabled = true
        h.Stub.SetSendMailItems({ { link = Link(CHEST), count = 2 } })
        SendMail("Boneset Hallowine", "s", "b")
        h.True(
            Contains(LastLog(), "mail: SendMail to Boneset Hallowine: " .. Link(CHEST) .. " x2"),
            LastLog()
        )
        h.Stub.FireEvent("MAIL_SEND_SUCCESS")
        h.True(
            Contains(LastLog(), "mail: MAIL_SEND_SUCCESS: inbound entry added for " .. OTHER),
            LastLog()
        )
        SendMail("Boneset Hallowine", "s", "b")
        h.Stub.FireEvent("MAIL_FAILED")
        h.True(Contains(LastLog(), "mail: MAIL_FAILED: capture dropped"), LastLog())
    end,

    ["Snapshot: each snapshot writes a debug line with its count"] = function()
        Login()
        LootLogicDB.debug.enabled = true
        h.Stub.SetWornLink(1, Link(CHEST))
        h.Stub.SetWornLink(2, Link(RING))
        h.Stub.SetKnownSpells({ 9077 })
        h.Stub.SetBagSize(0, 2)
        Put(0, 1, CHEST, 1)
        Put(0, 2, POTION, 4)
        h.Stub.FireEvent("PLAYER_EQUIPMENT_CHANGED", 1, false)
        local text = table.concat(LootLogicDB.debug.log, "\n")
        h.True(Contains(text, "snapshot: gear: 2 links"), text)
        h.True(Contains(text, "snapshot: proficiency: 1 spells known"), text)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.True(Contains(LastLog(), "snapshot: bags: 1 gear links, 2 item IDs"), LastLog())
        h.Stub.SetBagSize(6, 1)
        Put(6, 1, RING, 1)
        h.Stub.OpenBank()
        -- Classify writes its own bank line after this one.
        text = table.concat(LootLogicDB.debug.log, "\n")
        h.True(Contains(text, "snapshot: bank: 1 gear links, 1 item IDs"), text)
        h.Stub.SetInbox({ { items = { { link = Link(SWORD), count = 1 } } } })
        h.Stub.FireEvent("MAIL_SHOW")
        h.True(Contains(LastLog(), "snapshot: inbox: 1 gear links, 1 item IDs"), LastLog())
    end,

    ["Snapshot: logout writes the counts line and captures nothing"] = function()
        local entry = Login()
        LootLogicDB.debug.enabled = true
        h.Stub.SetWornLink(1, Link(CHEST))
        h.Stub.SetWornLink(2, Link(RING))
        h.Stub.SetBagSize(0, 3)
        Put(0, 1, CHEST, 1)
        Put(0, 3, POTION, 2)
        h.Stub.FireEvent("PLAYER_LOGOUT")
        h.True(
            Contains(
                LastLog(),
                "logout: equipped slots with a link: 2, bag slots holding an item: 2"
            ),
            LastLog()
        )
        h.Nil(entry.gear, "gear not stored")
        h.Nil(entry.bags, "bags not stored")
        h.Nil(entry.proficiency, "proficiency not stored")
        h.Equal(Bumps("gearHere"), 0, "no bump")
    end,

    ["Snapshot: a bag slot with a secret item ID or count is left out"] = function()
        local entry = Login()
        h.Stub.SetBagSize(0, 3)
        h.Stub.SetBagItem(0, 1, { itemID = h.Stub.MakeSecret(), link = Link(CHEST), count = 1 })
        h.Stub.SetBagItem(0, 2, { itemID = RING, link = Link(RING), count = h.Stub.MakeSecret() })
        Put(0, 3, POTION, 2)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.DeepEqual(entry.bags.gear, {}, "gear")
        h.DeepEqual(entry.bags.ids, { [POTION] = 2 }, "ids")
    end,

    ["Snapshot: an inbox attachment with a secret link or count is left out"] = function()
        local entry = Login()
        h.Stub.SetInbox({
            {
                items = {
                    { link = h.Stub.MakeSecret(), count = 1 },
                    { link = Link(CHEST), count = h.Stub.MakeSecret() },
                    { link = Link(POTION), count = 2 },
                },
            },
        })
        h.Stub.FireEvent("MAIL_SHOW")
        h.DeepEqual(entry.inbox.ids, { [POTION] = 2 }, "ids")
        h.DeepEqual(entry.inbox.gear, {}, "gear")
    end,

    ["Snapshot: a send mail attachment with a secret link or count is left out"] = function()
        local _, other = LoginWithOther()
        h.Stub.SetSendMailItems({
            { link = h.Stub.MakeSecret(), count = 1 },
            { link = Link(CHEST), count = h.Stub.MakeSecret() },
            { link = Link(POTION), count = 2 },
        })
        SendMail("Boneset Hallowine", "s", "b")
        h.Stub.FireEvent("MAIL_SEND_SUCCESS")
        h.Equal(#other.inbound, 1, "one entry")
        h.Equal(other.inbound[1].id, POTION, "the readable one")
    end,

    ["Snapshot: logout with debug off writes no line"] = function()
        Login()
        h.Stub.SetWornLink(1, Link(CHEST))
        h.Stub.FireEvent("PLAYER_LOGOUT")
        h.DeepEqual(LootLogicDB.debug.log, {}, "log")
    end,

    ["Snapshot: a read-only session takes no snapshot and writes nothing"] = function()
        DefineItems()
        LootLogicDB = { schema = 99 }
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Stub.SetWornLink(1, Link(CHEST))
        h.Stub.SetBagSize(0, 1)
        h.Stub.SetBagSize(6, 1)
        Put(0, 1, CHEST, 1)
        Put(6, 1, RING, 1)
        h.Stub.SetInbox({ { items = { { link = Link(CHEST), count = 1 } } } })
        h.Stub.SetSendMailItems({ { link = Link(CHEST), count = 1 } })
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD", true, false)
        h.Stub.Advance(Snapshot.DEBOUNCE_SECONDS)
        h.Stub.FireEvent("PLAYER_EQUIPMENT_CHANGED", 1, false)
        h.Stub.FireEvent("SPELLS_CHANGED")
        h.Stub.FireEvent("PLAYER_LEVEL_UP", 30)
        h.Stub.FireEvent("BAG_UPDATE_DELAYED")
        h.Stub.OpenBank()
        h.Stub.FireEvent("MAIL_SHOW")
        SendMail("Anyone Here", "s", "b")
        h.Stub.FireEvent("MAIL_SEND_SUCCESS")
        h.Stub.FireEvent("PLAYER_LOGOUT")
        h.DeepEqual(LootLogicDB, { schema = 99 }, "saved data unchanged")
        h.Equal(Bumps("gearHere"), 0, "no gearHere bump")
        h.Equal(Bumps("gearOthers"), 0, "no gearOthers bump")
        local result, reason = Snapshot.TakeAll()
        h.Nil(result, "TakeAll result")
        h.Equal(reason, "readonly", "TakeAll reason")
    end,

    ["Snapshot: a snapshot before the character has an entry is refused"] = function()
        DefineItems()
        LootLogicDB = nil
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
        local result, reason = Snapshot.TakeGear()
        h.Nil(result, "result")
        h.Equal(reason, "unknown", "reason")
    end,
}
