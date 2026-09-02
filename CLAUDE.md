# minecraft-turtle-scripts

Lua scripts for CC: Tweaked (ComputerCraft) turtles and computers in
Minecraft. This is a code/reference repo, not a Minecraft mod — scripts get
copied/pulled onto in-game turtles.

## Structure

Scripts are organized by turtle role, one top-level folder per role:
`mining/`, `farming/`, `tree-farm/`, `building/`, `item-sorter/`. Shared
helper code (movement/navigation, inventory management, fuel handling, etc.)
goes in `lib/` and is pulled in with an absolute-path
`dofile("/lib/<name>.lua")`, not `require` and not copy-pasted between
scripts. `require` resolves relative to the calling script's own folder, so
it breaks as soon as a script in `mining/` loads a module from `lib/`;
absolute `dofile` paths resolve identically in this repo, in CraftOS-PC
(with computer-0 pointed at the repo root), and on an installed turtle.

Each script must stay runnable by itself once copied onto a turtle's own
filesystem — don't assume a repo-relative path at runtime, only
`dofile("/lib/...")` of modules that will also be present on the turtle.

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

## Documentation language

User-facing tutorials and usage instructions (README.md, in-game/setup
walkthroughs) must be written in **both German and English** — some of
the people running these scripts have no programming background and are
more comfortable in German. Internal/technical docs (this file, design
specs under `docs/`) stay English-only; they're for coding-agent and
developer context, not end users.
