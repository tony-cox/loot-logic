"""Runs the offline tests in a real Lua 5.1 runtime through lupa.

Usage: python tests/run.py [filter]

The filter is a case-sensitive substring of "<file>: <case>". Each case gets a fresh
runtime: stubs/Wow.lua, then Harness.lua (which builds h), then the .lua lines of
LootLogic/LootLogic.toc in order (except Globals.lua), each called as
chunk("LootLogic", ns) with one shared ns, then the test file, then the one case.
TestPrices omits Prices/Auctionator.lua because it registers fake providers with
the same id; TestAuctionator loads and tests the built-in provider. See
docs/technical-findings.md section 17.1.
"""

import sys
from pathlib import Path

from lupa.lua51 import LuaError, LuaRuntime, lua_type

TESTS_DIR = Path(__file__).resolve().parent
ROOT = TESTS_DIR.parent
TOC_PATH = ROOT / "LootLogic" / "LootLogic.toc"
ADDON_NAME = "LootLogic"
SKIPPED_FILES = {"Globals.lua"}
TEST_FILE_SKIPPED_ADDON_FILES = {
    "TestPrices.lua": {"Prices/Auctionator.lua"},
}

LOADER = """
return function(source, name)
    local chunk, message = loadstring(source, "@" .. name)
    if not chunk then
        error(message, 0)
    end
    return chunk
end
"""

PROTECTED_CALL = """
return function(fn)
    local ok, message = pcall(fn)
    if ok then
        return true, ""
    end
    return false, tostring(message)
end
"""


def toc_lua_files(test_file=None):
    files = []
    skipped = TEST_FILE_SKIPPED_ADDON_FILES.get(test_file.name, set()) if test_file else set()
    for line in TOC_PATH.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or not line.endswith(".lua"):
            continue
        name = line.replace("\\", "/")
        if Path(name).name in SKIPPED_FILES or name in skipped:
            continue
        files.append(name)
    return files


def build_runtime(test_file):
    """Starts a fresh runtime with the stub, the addon files and one test file loaded.

    Returns (runtime, protected_call, cases) where cases is the Lua table the test file
    returned.
    """
    lua = LuaRuntime(unpack_returned_tuples=True)
    load = lua.execute(LOADER)

    def load_file(path, label):
        return load(Path(path).read_text(encoding="utf-8"), label)

    stub = load_file(TESTS_DIR / "stubs" / "Wow.lua", "tests/stubs/Wow.lua")()
    harness = load_file(TESTS_DIR / "Harness.lua", "tests/Harness.lua")(
        stub, TESTS_DIR.as_posix()
    )
    ns = lua.table()
    for name in toc_lua_files(test_file):
        load_file(ROOT / "LootLogic" / name, "LootLogic/" + name)(ADDON_NAME, ns)
    cases = load_file(test_file, "tests/" + test_file.name)(ADDON_NAME, ns, harness)
    if lua_type(cases) != "table":
        raise ValueError("the test file must return a table of cases")
    return lua.execute(PROTECTED_CALL), cases


def main(argv):
    pattern = argv[1] if len(argv) > 1 else ""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    passed = 0
    failed = 0
    for test_file in sorted(TESTS_DIR.glob("Test*.lua")):
        stem = test_file.stem
        try:
            _, cases = build_runtime(test_file)
            names = sorted(str(key) for key in cases.keys())
        except (LuaError, OSError, ValueError) as error:
            # The case names are unknown, so the filter cannot hide the failure.
            print("FAIL %s: loading: %s" % (stem, error))
            failed += 1
            continue
        for name in names:
            label = "%s: %s" % (stem, name)
            if pattern not in label:
                continue
            try:
                protected, cases = build_runtime(test_file)
                ok, message = protected(cases[name])
            except (LuaError, OSError, ValueError) as error:
                ok, message = False, str(error)
            if ok:
                print("PASS " + label)
                passed += 1
            else:
                print("FAIL %s: %s" % (label, message))
                failed += 1
    print("%d passed, %d failed" % (passed, failed))
    if passed + failed == 0:
        print("No case matched.")
        return 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
