# minecraft-turtle-scripts

Lua scripts for CC: Tweaked turtles and computers, organized by turtle role.

## Layout

- `mining/` — quarry/strip-mining/ore-detection scripts
- `farming/` — crop farming scripts
- `tree-farm/` — tree farming/lumberjack scripts
- `building/` — construction/schematic-placing scripts
- `item-sorter/` — computer + turtle scripts for sorting storage systems
- `lib/` — shared helper modules loaded by scripts in the folders above

Each script folder is meant to be pushed/pulled to an in-game turtle as-is
(e.g. via a disk drive, `wget`, or a Pastebin/GitHub pull script), so keep
scripts self-contained aside from loading modules from `lib/` with an
absolute path: `dofile("/lib/<name>.lua")`. (`require` resolves relative to
the calling script's own folder, which breaks for a script in `mining/`
loading a module from `lib/`, so it isn't used here.)

## Testing locally with CraftOS-PC

[CraftOS-PC](https://www.craftos-pc.cc/) is a standalone CC: Tweaked emulator
that runs the real `turtle`, `fs`, `peripheral`, etc. APIs outside of
Minecraft, so most scripts can be smoke-tested without loading the game.

1. Install it: `brew install --cask craftos-pc`
2. Point CraftOS-PC's computer-0 data folder directly at this repo's root, so
   the repo *is* the emulated computer's filesystem root. Scripts load shared
   modules by absolute path (`dofile("/lib/inventory.lua")`), so they only
   resolve if `lib/` sits at the emulated root — mounting the repo as a
   secondary drive instead makes those loads fail with
   `cannot open /lib/inventory.lua`.
3. Run a script from the CraftOS-PC shell, e.g.:
   ```
   cd mining
   strip-mine
   ```

Not everything is emulated (e.g. some block/peripheral interactions specific
to other mods), so treat CraftOS-PC as a fast logic/syntax check and still do
a final pass in-game before relying on a script.

## Running the quarry script (Deutsch / English)

### Deutsch

1. **Zwei Truhen aufstellen.** Stelle dich an die Stelle, wo die Turtle
   starten soll, mit Blick in die Richtung, in die der Steinbruch gehen
   soll. Stelle direkt **hinter** dir eine Truhe auf — das ist die
   Treibstoff-Truhe, dort hinein kommt Kohle o. ä. Stelle direkt **links**
   von dir eine zweite Truhe auf — das ist die Item-Truhe, dort landen die
   abgebauten Materialien.
2. **Turtle aufstellen und Skript installieren.** Stelle die Turtle genau
   an deine Position (mit derselben Blickrichtung) und gib in ihrem
   Terminal ein:
   ```
   wget run https://raw.githubusercontent.com/YOUR_GITHUB_USER/minecraft-turtle-scripts/main/install.lua quarry
   ```
   Das lädt das Skript und alles, was es braucht, einmalig herunter.
3. **Steinbruch starten.** Gib ein:
   ```
   quarry <Breite> <Länge> <Tiefe> <true|false>
   ```
   Zum Beispiel `quarry 8 8 64 true` gräbt ein 8×8 Feld 64 Blöcke tief
   und wirft dabei nutzlose Blöcke (Erde, Kies, Stein usw.) direkt weg,
   statt sie mitzuschleppen. Mit `false` statt `true` wird stattdessen
   alles behalten.
4. **Fertig warten lassen.** Die Turtle kehrt von selbst zur Oberfläche
   zurück, wenn Treibstoff oder Platz im Inventar knapp werden, tankt/leert
   sich an den beiden Truhen und macht danach automatisch weiter. Startet
   der Server neu oder die Turtle geht aus, reicht ein erneutes `quarry`
   ohne Argumente — sie merkt sich, wo sie war.
5. **Neu anfangen statt fortsetzen.** Solange die Fortschrittsdatei
   `/quarry_state.txt` auf der Turtle liegt, setzt `quarry` immer den alten
   Lauf fort und ignoriert neu angegebene Argumente. Wenn du einen neuen
   Steinbruch (oder andere Maße) starten willst — z. B. weil die Turtle auf
   Grundgestein gestoßen und stehen geblieben ist — lösche die Datei mit
   `delete /quarry_state.txt` und starte `quarry` danach wieder mit
   Argumenten.

### English

1. **Place two chests.** Stand where the turtle should start, facing the
   direction the quarry should dig into. Place a chest directly **behind**
   you — that's the fuel chest, put coal or similar fuel in it. Place a
   second chest directly to your **left** — that's the item chest, mined
   materials end up there.
2. **Place the turtle and install the script.** Put the turtle exactly at
   your position (facing the same way), and in its terminal type:
   ```
   wget run https://raw.githubusercontent.com/YOUR_GITHUB_USER/minecraft-turtle-scripts/main/install.lua quarry
   ```
   That downloads the script and everything it needs, once.
3. **Start the quarry.** Type:
   ```
   quarry <width> <length> <depth> <true|false>
   ```
   For example, `quarry 8 8 64 true` digs an 8×8 area 64 blocks deep,
   dropping useless blocks (dirt, gravel, stone, etc.) immediately instead
   of hauling them, rather than keeping everything if you pass `false`.
4. **Let it run.** The turtle returns to the surface on its own whenever
   fuel or inventory space runs low, refuels/empties itself at the two
   chests, then keeps going automatically. If the server restarts or the
   turtle loses power, just run `quarry` again with no arguments — it
   remembers where it left off.
5. **Starting over instead of resuming.** As long as the progress file
   `/quarry_state.txt` exists on the turtle, `quarry` always resumes the old
   run and ignores any freshly passed arguments. To start a new quarry (or
   use different dimensions) — for instance because the turtle hit bedrock
   and stopped — delete the file with `delete /quarry_state.txt`, then run
   `quarry` with arguments again.
