# minecraft-turtle-scripts

Lua scripts for CC: Tweaked (ComputerCraft) turtles and computers in
Minecraft. This is a code/reference repo, not a Minecraft mod — scripts get
copied/pulled onto in-game turtles.

## Structure

Scripts are organized by turtle role, one top-level folder per role:
`mining/`, `farming/`, `tree-farm/`, `building/`, `item-sorter/`. Shared
helper code (movement/navigation, inventory management, fuel handling, etc.)
goes in `lib/` and is pulled in with `require`, not copy-pasted between
scripts.

Each script must stay runnable by itself once copied onto a turtle's own
filesystem — don't assume a repo-relative path at runtime, only `require`
of modules that will also be present on the turtle (i.e. `lib/`).

## Environment

Target runtime is CC: Tweaked's Lua 5.1-based environment (turtle/computer
APIs: `turtle`, `fs`, `peripheral`, `rednet`, `textutils`, etc.), not
stock Lua or a later Lua version — avoid syntax/stdlib features these APIs
don't support.

## Testing

There's no in-game CI. Scripts are smoke-tested locally with
[CraftOS-PC](https://www.craftos-pc.cc/), a standalone CC: Tweaked emulator
(see README.md for setup). It emulates the core APIs faithfully but not
every mod-added peripheral or block interaction, so treat a clean CraftOS-PC
run as a logic/syntax check, not a guarantee it behaves identically in-game.

## Conventions

- No formatter/linter is configured yet (no `lua`/`luacheck` on this
  machine) — match the style of surrounding code in a file/folder rather
  than imposing a new convention.
- Prefer small, focused scripts per role over one large configurable script.
