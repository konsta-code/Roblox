# HANDOFF — Übergabe-Kontext

> Zum Weiterarbeiten (z. B. für Grok): als ersten Kontext geben. Beschreibt, wie
> das Projekt tickt, was zuletzt gebaut wurde, die Architektur und die Regeln.

Du übernimmst die Weiterentwicklung eines Roblox-Spiels: ein **Tribes-artiger
Team-CTF-Shooter** (Ski + Jetpack Movement, Spinfusor + Chaingun + Fähigkeiten +
Granaten, 9 Klassen, Bots, Flaggen/Generatoren/Basen). Repo:
`github.com/konsta-code/Roblox` (Branch `main`, ein **Rojo**-Projekt:
`default.project.json` mappt Dateien auf Roblox-Instanzen). Sprache: **Luau**.

## Setup / wichtig

- Es gibt **ZWEI Klone**. Das LIVE-Spiel läuft aus
  `C:\Users\konst\Downloads\Roblox-Recovered` (dort läuft
  `rojo serve default.project.json --port 34872`, Studio synct von dort, die
  Place-Datei `CTFGame.rbxlx` liegt dort). Der GitHub-Repo-Inhalt entspricht dem
  Live-Stand (Runtime-Code identisch; einzelne Art-Binaries unter `art_source/`
  können abweichen, sind aber nicht runtime-relevant).
- **Server-Scripts laufen NUR im Play-Modus**, nicht im Edit-Modus.
- Änderungen, die im Spiel sichtbar sein sollen, müssen im **LIVE-Ordner** landen
  (bearbeiten oder rüberkopieren) + bei NEUEN `$path`-Einträgen / Struktur-
  Änderungen `rojo serve` **neu starten** (frischer Snapshot), dann Rojo-Plugin
  neu verbinden. Nach jeder Lua-Änderung: mit `stylua --check <datei>` auf
  Parse-Fehler prüfen. Push nach `main`.

## Was das Spiel kann

- **CTF**: Flaggen, Captures, Generatoren, Basen. **Movement**: Ski + Jetpack,
  `Gravity=0` (custom, `MovementConstants`). **Waffen**: Spinfusor
  (`ProjectileWeapon`), Chaingun, Fähigkeiten (`Ability`), Granaten/Melee
  (`Equipment`). Tuning: `ClassKitConstants` (9 Klassen) + `WeaponConstants`.
- **HUD** (`HudController`): Radar/Flag-Marker, Base-Status, Killfeed,
  Award-Medals, Hitmarker, Speed. **Match-Loop** (`MatchManager`):
  Warmup → InProgress (600 s / 10 min) → Overtime → PostMatch. **Bots**
  (`BotManager`). **Loadouts** (`LoadoutManager` / `LoadoutMenu`).
  **Persistenz**: `PlayerData.server` speichert Career-Stats via DataStore.

## Architektur-Fakten

- Schaden läuft zentral über `CombatService.Damage` (**Friendly Fire IST
  abgesichert**: Team-Check zentral + zusätzlich in jeder Waffe). Nur in
  `InProgress`/`Overtime`.
- Movement ist **CLIENT-AUTORITATIV** (`SkiController.client`). Knockback/Impulse
  werden über das RemoteEvent `MovementImpulse` an den Client gefeuert (der wendet
  ihn an); reine Server-Velocity wird vom client-eigenen Character überschrieben.
- Relevante Attribute — **Workspace**: `UseTribesWorld`, `TribesWorldReady`,
  `SelectedMapId`/`ForceMapId`, `CurrentMapId`/`Name`/`Theme`. **ReplicatedStorage**:
  `MatchPhase`, `MatchTop1..3`, `MatchWinner`/`MVP`. **Spieler**: `LoadoutMenuOpen`
  sperrt Combat-Input + gibt die Maus frei (nutzen alle Menüs, damit man trotz
  LockFirstPerson klicken kann).

## Diese Session neu gebaut (aktueller Stand)

- **MAP-POOL**: `MapPoolConstants` (Themes grass/snow/desert + 6 Map-Defs mit
  Seed/Layout), `WorldGen` (parametrischer, optimierter Terrain-Generator),
  `MapDirector` (wählt beim Start Standard-Map `grass_ridgeline` via
  `SelectedMapId`, baut, seatet Basen per Raycast auf die echte Oberfläche,
  Live-Switch via `_G.RequestMapSwitch`), `WorldEnvironment.lua` + `Dressing.lua`
  (Theme-Licht/Deko). `TribesWorld`/`TribesSunset`/`WorldEnvironment.server` sind
  **stillgelegt** (Stubs, unregistriert).
- **MAP-VOTING am Rundenende**: `MatchManager` broadcastet Top-3, zählt `MapVote`
  in der PostMatch-Phase (25 s), baut die Gewinner-Map beim Runden-Übergang.
  `MapMenu.client` = PostMatch-Podium + Voting-Screen.
- **HARDCORE COMBAT-FEEL**: Gegner-Knockback vom Spinfusor (Direkt punt't entlang
  Flugrichtung, Splash punt't weg; Tuning `ENEMY_`/`DIRECT_KNOCKBACK_MULT` in
  `WeaponConstants`). Mid-Air-Direkttreffer = One-Shot (`MIDAIR_DIRECT_MULT`).
  `CameraShake.client` (Trauma-Shake). Kill-Juice (Award-Eskalation + eigene Kills
  im Killfeed hervorgehoben) in `HudController`.
- **ANFANGS-SPAWN-FIX**: `MapDirector` hebt frisch gespawnte Charaktere während
  des Bauens nach oben (sonst spawnt man an der alten Basisposition und wird vom
  Terrain begraben) und teleportiert danach auf den gesetzten Spawn.

## Status

Alles obige ist implementiert + `stylua`-parse-geprüft, aber **noch nicht
vollständig in Studio playgetestet**. Bitte im Play-Modus verifizieren.
Combat-Werte sind über die `MULT`-Konstanten leicht justierbar (playtest-getrieben).

## Harte Regel (hat uns eingeholt)

**NIEMALS den Charakter-Spawn-Fluss anfassen, um Spawn-Probleme zu lösen** —
insbesondere NICHT `Players.CharacterAutoLoads = false` / Charaktere gaten. Das
hat schon Modell-Laden + Jetpack zerschossen. Spawn-Probleme **nur über Position**
lösen (Teleport/Anheben), nie über das Laden. Immer **inkrementell + einzeln
getestet** arbeiten, kein Big-Bang.

## Nächste offene Schritte (Track „hardcore fun shooter")

1. **Tempo**: kürzere Respawn-Zeit + kürzeres Warmup.
2. **Explosions-Wumms**: größerer Blitz/Shockwave + fetterer Sound bei Disc-Impact.
3. **Balance / Bot-KI**-Feinschliff (playtest-getrieben).
4. Optional **Progression**: XP/Rang auf dem persistenten Career-Score (`PlayerData`).

Zuerst aber: Combat-Feel + Spawn-Fix + Map-Voting gegentesten und die `MULT`s /
Shake nach Gefühl justieren.
