# LootLogic Lua style guide

Status: draft. The indentation, the tooling, the naming, privacy and file-name rules, and the additions from the comparison with two other guides are accepted. The remaining conventions are proposals until accepted.

The rules for the addon's Lua code. They follow the usual conventions for readable Lua and are fitted to a WoW addon (Lua 5.1 as the game embeds it; the Forever client's exact Lua version is unverified: live check L62). This guide is written for the project and is not copied from another guide. Doc and comment writing rules are in `CONTRIBUTING.md`.

## 1. Principles

- Be consistent. A rule applied everywhere beats a better rule applied sometimes, and it keeps review about behaviour, not taste.
- Write for the next reader, not the writer. Prefer the plain form even when a shorter one exists.
- Avoid clever features that hide how code can fail.
- Where the Lua community already has a settled idiom, use it.
- Let tools settle formatting. `StyLua` formats the code and its output is the style: do not argue with it or hand-format around it. This guide covers what a formatter cannot, and section 4 states the settings it is configured to enforce.

## 2. Files

- One module per file. File names follow the Blizzard and wider addon convention: `PascalCase`, named for the main thing the file holds (`ItemScoring.lua`, `BagCategories.lua`). An acronym keeps its capitals (`API.lua`, `DB.lua`, a `UI/` folder). Names the game or the TOC fixes keep their required form (`LootLogic.toc` matches the addon folder; `Bindings.xml`; locale files are named by the client's locale code, `enUS.lua`).
- Order within a file:
  1. A short comment saying what the file is for (no file name, author or date: the repository records those).
  2. Locals that cache globals and WoW API functions.
  3. Access to the shared addon namespace and other modules.
  4. Constants.
  5. Local state and local functions.
  6. The public functions.
  7. Event and slash command registration.
- Put every module lookup at the top, never inside a function that runs often. A file looks up only modules that load before it (the TOC order, technical findings section 14); to hear from a module that loads later, register a callback with the earlier one.
- Loading has no side effects beyond defining the file's own functions and registering its events. Work starts from an event or a call, not from the file being read.

## 3. The addon namespace and globals

- Every addon file receives the addon name and a shared table from the client (`local addonName, ns = ...`). Hang public pieces off `ns`; do not add globals.
- Add a global only when the client or another addon needs it by name and there is no clean way to structure the code without one. The expected cases are the saved variables named in the TOC, the one table other addons are meant to call (the public API, spec section on interop), the function the TOC names for the addon compartment, key binding names, and slash command fields. Each name contains `LootLogic` (`LOOTLOGIC` where the client needs upper case, as in `SLASH_LOOTLOGIC1` and `BINDING_NAME_LOOTLOGIC_*`). Only `Globals.lua` creates them: the last file in the TOC, wiring only, no logic. The one exception is the saved variable, which the client creates from the TOC and `Core/DB.lua` reads and fills. Everything else, including the functions that key bindings and slash commands call, stays under `ns` and is reached through the one `LootLogic` table. The linter configuration names exactly these globals (section 15).
- Cache WoW API functions and hot globals as locals at the top of a file when the file calls them in loops or per-frame handlers. Elsewhere, call them directly.
- Never write to a global by accident. Declare every variable `local`. Run a linter that flags global reads and writes (section 15).
- Never read or write another addon's globals except through its documented API (see `CONTRIBUTING.md` on researching other addons).
- A module may hold state (saved variables, caches, event state), since an addon is stateful. Keep that state in file-local variables and reach it through the module's functions.

## 4. Formatting

- Indent with four spaces. No tabs.
- Keep lines to 100 columns at most and comment lines to 80 at most.
- Use LF line endings. No trailing whitespace; end each file with one newline.
- One statement per line. No semicolons.
- One blank line between functions and between logical groups, none at the start or end of a block.
- A block may sit on one line only as `if ... then return ... end` or `if ... then break end`. Write every other body on its own lines, even when it is one statement.
- Do not line up `=` signs or comments across lines.
- Put a space around binary operators and after commas.
- Keep opening braces and `function (...)` bodies on the line that starts them.

## 5. Long expressions

- Split a long expression into named pieces before it reaches the column limit.
- When it must wrap, start the continuation line with the operator.
- Use a temporary local in preference to nested parentheses.
- A table with a few short entries may stay on one line. Otherwise put each entry on its own line, and end the table with a trailing comma.

## 6. Conditions

- No parentheses around the condition of `if`, `while` or `until`.
- Do not compare to `true`, `false` or `nil` explicitly: write `if found then`, `if not found then`. Compare to `nil` only when `false` is a valid value that must be told apart from it.
- Do not use `a and b or c` as a ternary: it returns `c` whenever `b` is `false` or `nil`. Use an `if` statement, or a small named helper.
- Break a long condition into well-named locals.
- Use early `return` or `break` to keep nesting shallow.
- Wrap a section of code in `do ... end` when that limits how long a temporary variable lives and a function would be overkill.

## 7. Strings, numbers and tables

- Write strings with double quotes. Use single quotes only to avoid escaping a double quote inside.
- Build long strings with `string.format` or `table.concat`, not a chain of `..`. A short join of two or three pieces with `..` is fine.
- Test for an empty string with `== ""`, and take its length with `#`.
- Convert with `tostring` and `tonumber`, not by relying on coercion.
- Write numbers plainly: `0.5`, not `.5`; `3`, not `3.0`. Write bit masks in hexadecimal and very large or small values in exponent form. Use `x ^ 2`, not `math.pow`.
- Fill a table in one constructor where the fields are known up front, instead of assigning them one by one afterwards.
- Write keys as plain names (`{ count = 1 }`). Use `["key"]` only when the key is not a valid name. Use `.` to read a known field and `[ ]` only for a variable key or a list index.
- Do not mix list entries and keyed entries in one table.
- Iterate lists with `ipairs` (or a numeric `for`) and keyed tables with `pairs`. Never rely on `pairs` order; sort the keys when order matters to output or tests.
- Use `#t` only on a table with no holes. Do not create holes by assigning `nil` into the middle of a list; use `table.remove`.
- In code that runs per frame or per bag update, avoid creating tables and closures. Reuse a table and clear it.

## 8. Functions

- Keep parameter lists short. After about three, pass a single options table.
- Always call with parentheses, including calls with one string or table argument.
- Write named functions as `local function Name()` or `function Module.Name()`, not `Name = function()`.
- A function is `local` unless another file needs it.
- In a table of functions, use `.` for functions that do not take the object and `:` for methods that do. Do not mix the two for the same function.
- Do work in small functions that do one thing; split a function that needs a section comment to be understood.
- A function with nothing to return returns nothing, not an explicit `nil`.
- Declare variables in the smallest scope that works. The wider the scope, the more descriptive the name. A single letter is for a short loop or a few-line block only; use `_` for a value that is deliberately ignored.

## 9. Objects and metatables

- Use metatables only for two things: simple prototype-style classes, and guarding a constants table against misspelt keys.
- A class sets `Class.__index = Class` and builds instances with a `Class.New(...)` constructor. Call methods with `:`.
- Do not use `__index` or `__newindex` to hide work that costs time, or to change behaviour of tables other code owns.
- Prefer a plain table and functions to a class when there is no per-instance state.
- An object that holds something to release (a frame, a registered event, a timer) gets an explicit method to release it (`Close` or `Release`). Do not rely on `__gc`.

## 10. Privacy

- Privacy comes from file scope. A `local` variable or function is private to its file; only what a file puts on its module table or on `ns` is public.
- Do not mark private members with a leading underscore, in names or in fields. A name that starts or ends with an underscore is not used (a lone `_` for an ignored value is the exception).
- When an object needs hidden per-instance data, keep it in a file-local table keyed by the instance, or in a closure, not in a field other files could reach.

## 11. Comments

- Explain why, not what. If a comment restates the line below it, delete it.
- Write comments as sentences: start with a capital letter, end with a full stop, and put a space after `--`.
- Avoid trailing comments. When one is short and worth keeping, put two spaces before the `--`.
- Document a public function in a doc comment (LDoc style) above it, with the type of each parameter and return value. Prefer that to scattered notes in the body.
- Mark unfinished work with `TODO` and known problems with `FIXME`, each with a reason.
- Comment every workaround for a game quirk with what the quirk is and how it was seen. Mark anything not observed on a live client with its confidence label (`CONTRIBUTING.md`).
- Do not use banner or section-divider comments. A file that needs them should be split.
- Use `--` for notes, `---` for doc comments and `--[[ ]]` for the file's top comment.

## 12. Naming

- Spell names out. Allow only well-known abbreviations (for example `id`, `db`, `ui`); write `itemLevel`, not `ilvl`.
- `camelCase`: local variables, parameters and table fields.
- `PascalCase`: functions (local and public), methods, classes and module tables.
- `UPPER_SNAKE_CASE`: constants that never change after load, and the members of a closed, named set of keys, as enum members are (the canonical stat keys `STR`, `SP_SHADOW`, `HIT` defined in the spec). A key belongs to such a set only if the spec defines the set; every other table field is `camelCase`.
- An acronym in a name keeps its capitals: `GetAPI`, `UpdateUI`, `itemID`, `spellID`, `bagUI`. A `camelCase` name starting with one is written in lower case (`apiVersion`, `uiScale`).
- A function that returns a boolean reads as a question: `IsEquippable`, `HasBonus`.
- Names the game defines (API functions, events, frame fields) keep the game's spelling, even where it breaks these rules.
- Colour components are `r`, `g`, `b` and `a`, as the game names them.
- File names are `PascalCase` too (section 2).
- This split follows what most WoW addons and Blizzard's own UI do: `PascalCase` functions, `camelCase` variables. A table of data keyed by names from another source (spell names, API keys) keeps that source's spelling.

## 13. Errors and protected code

- Return a failure instead of raising one when the caller can reasonably expect it (`return nil, "reason"`). Reserve `error` for programming mistakes, such as a state that cannot happen.
- Do not check argument types at run time. The cost is paid on every call; tests cover what callers pass instead (every public function has a case for its normal arguments and for nil or not-yet-loaded input where the spec allows it).
- Wrap a call in `pcall` only when it can fail for reasons outside the addon's control (another addon's API, saved data from an older version). Say in a comment which failure is expected.
- Never swallow an error silently. Log it where the player or a developer can see it.
- Do not change protected frames or secure state during combat lockdown; queue the work for after combat. Check the lockdown state with the game's API before touching them.
- Validate saved variables when loading and fill in missing fields from defaults; saved data can come from an older version or be hand-edited.

## 14. Events and timing

- Register for the fewest events needed and unregister when no longer needed.
- Keep event handlers short; they should record what changed and hand off to a function that does the work.
- Do not do heavy work in a single frame. Spread long loops over several frames with a timer or a work queue.
- Do not poll when an event exists.
- Remember that item data can be unavailable at first request and arrive later by event. Code that needs it must handle the "not yet" case.

## 15. Tools

Accepted:

- **Formatter: `StyLua`.** Set to the layout rules in sections 4 to 8 that it can enforce (four-space indent, 100-column lines, LF line endings, double quotes, parentheses on every call, Lua 5.1 syntax). Run it over every Lua file before a pull request; a file it would change is not ready. Where it and this guide disagree on layout, the formatter wins and the guide is corrected.
- **Linter: `luacheck`.** Configured with the WoW API globals and the addon's own globals (section 3), so it flags accidental globals, unused variables and shadowing. It must pass with no warnings before a pull request.
- Both run in CI once CI exists. Their configuration files (`stylua.toml`, `.luacheckrc`) sit at the repository root and are added with the first code (what they cover and how the globals list is built: technical findings section 14, Tools), and the formatter options are checked against the installed version then. A `.gitattributes` fixes LF line endings for Lua files so Windows checkouts do not change them.

Unit tests for pure logic outside the game live in `tests/` and run through lupa (technical findings section 17); `docs/TESTING.md` holds the in-game checks.

## 16. Examples in the docs

Lua blocks in the spec and technical findings follow this guide like code: four-space indent, no aligned `=`, a space around operators, one entry per line in a multi-key table with a trailing comma, and names as in section 12. A block that shows only a shape may leave out values with `...` or `<placeholder>`, and may show a function as a signature with no body. Names of the game's and other addons' API keep their own spelling.
