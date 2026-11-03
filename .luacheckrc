-- Written by hand for LootLogic. The WoW names are the ones the addon code and
-- tests/stubs/Wow.lua use; keep the list in step with the stub.
std = "lua51"
max_line_length = 100
max_comment_line_length = 80

-- The saved variable named in the TOC. Globals.lua adds the addon's other
-- globals in M1.
globals = {
    "LootLogicDB",
}

read_globals = {
    "AuctionDB",
    "C_AddOns",
    "C_Timer",
    "CreateFrame",
    "GetServerTime",
    "GetTime",
    "date",
    "issecretvalue",
    "strsplit",
    "strtrim",
    "time",
    "wipe",
}

-- Addon code may not reach os (the stub clock must be the only time source:
-- read GetServerTime), io or module loading (from memory, absent on the
-- client). Tests and the runner may.
files["LootLogic/"] = {
    not_globals = { "os", "io", "require", "package", "module", "loadfile", "dofile" },
}

-- The tests read the client names above and the chat frame the stub captures.
files["tests/"] = {
    read_globals = {
        "DEFAULT_CHAT_FRAME",
    },
}

-- The vendor price tests set the AuctionDB global that AHDB would create.
files["tests/TestVendor.lua"] = {
    globals = { "AuctionDB" },
}

-- The stub defines the client names, so it may assign them.
files["tests/stubs/Wow.lua"] = {
    globals = {
        "C_AddOns",
        "C_Timer",
        "CreateFrame",
        "DEFAULT_CHAT_FRAME",
        "GetServerTime",
        "GetTime",
        "date",
        "issecretvalue",
        "print",
        "strsplit",
        "strtrim",
        "time",
        "wipe",
    },
}
