-- A saved table with a schema newer than the code's, a key the code does not
-- know and most settings missing.
return {
    schema = 99,
    futureKey = { 1, 2, 3 },
    ui = { lastTab = "status" },
    debug = { enabled = true, log = { "old" }, maxLog = 50 },
}
