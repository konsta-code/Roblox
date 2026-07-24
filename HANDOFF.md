# HANDOFF — Übergabe-Kontext

> Zum Weiterarbeiten (z. B. für Grok): als ersten Kontext geben. Beschreibt, wie
> das Projekt tickt, was zuletzt gebaut wurde, die Architektur und die Regeln.

Du übernimmst die Weiterentwicklung eines Roblox-Spiels: ein **Tribes-artiger
Team-CTF-Shooter** (Ski + Jetpack Movement, Spinfusor + Chaingun + Fähigkeiten +
Granaten, 9 Klassen, Bots, Flaggen/Generatoren/Basen). Repo:
`github.com/konsta-code/Roblox` (Branch `main`, ein **Rojo**-Projekt:
`default.project.json` mappt Dateien auf Roblox-Instanzen). Sprache: **Luau**.

## Zielbild (langfristig)

Publish auf Roblox + Monetarisierung (Lobby, Mode-Auswahl, Händler, Kisten,
Soft-Currency + Robux). Zuerst Core stabil und fun machen, dann Lobby-Layer.

## Setup / wichtig

- Es gibt **ZWEI Klone**. Das LIVE-Spiel läuft aus
  `C:\\Users\\konst\\Downloads\\Roblox-Recovered` (dort läuft
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
  in der PostMatch-Phase, baut die Gewinner-Map beim Runden-Übergang.
  `MapMenu.client` = PostMatch-Podium + Voting-Screen.
- **HARDCORE COMBAT-FEEL**: Gegner-Knockback vom Spinfusor (Direkt punt't entlang
  Flugrichtung, Splash punt't weg; Tuning `ENEMY_`/`DIRECT_KNOCKBACK_MULT` in
  `WeaponConstants`). Mid-Air-Direkttreffer = One-Shot (`MIDAIR_DIRECT_MULT`).
  `CameraShake.client` (Trauma-Shake). Kill-Juice (Award-Eskalation + eigene Kills
  im Killfeed hervorgehoben) in `HudController`.
- **ANFANGS-SPAWN-FIX**: `MapDirector` hebt frisch gespawnte Charaktere während
  des Bauens nach oben (sonst spawnt man an der alten Basisposition und wird vom
  Terrain begraben) und teleportiert danach auf den gesetzten Spawn.
- **TEMPO (Phase 1, 2026-07-24)**:
  - `MatchConstants`: Warmup 6 s (vorher 10), Overtime 90 s (vorher 120), PostMatch 18 s (vorher 25)
  - `Players.RespawnTime = 3.5` (gesetzt in `SpawnManager.server.lua`)
- **SKI-AUDIO + POSEN-SYNC (2026-07-24)**: Lokaler Ski-Rutsch-Loop (Hiss+Rumble,
  speed-gesteuert, still in der Luft), Default-Footsteps beim Skiing gemutet.
  Neues RemoteEvent `MovementStateSync` (dynamisch in `MovementGuard`): Client
  meldet Ski/Jet, Server spiegelt als **Character-Attribut** (repliziert) ->
  Fremd-Charaktere zeigen echte Ski-Posen + raeumlichen `SkiSlideLoop`
  (`CharacterMotion`). SkiController unangetastet.
- **LOBBY-PHASE (2026-07-24)**: Journey jetzt Lobby (Klassenwahl+Ready im
  LoadoutMenu) -> Warmup -> Match -> PostMatch -> Lobby. `MatchManager`-Phase
  "Lobby": endet ab 60% Ready (`LOBBY_READY_FRACTION`) sofort, sonst nach 45 s
  (`LOBBY_DURATION`). RemoteEvent `MatchReady` (dynamisch), Ready als Spieler-
  Attribut `MatchReady`. Klassenwahl greift in Lobby/Warmup SOFORT (LoadoutManager,
  kampffreie Phasen). HUD-Label vorhanden. Waffen-MVP-Check: Thumper-Bogen
  (`gravity`), Shotgun (`pellets`), Nitron-Flag-Drop (`causesFlagFumble`) und
  Homing (`homingStrength`) existieren bereits in `ClassKitConstants`.
- **EXPLOSIONS-WUMMS (2026-07-24)**: Disc-Impact hat jetzt weiss-heissen
  Kern-Blitz, hellere PointLight, Splitter-Funken, Schockwellen-Ring entlang der
  Aufprall-Normalen und einen runtergepitchten Sub-Bass-Soundlayer
  (`showExplosion` in `ProjectileWeapon.server`). Neues RemoteEvent
  `ExplosionFeedback` wird **dynamisch in `CombatService` erzeugt** (bewusst
  NICHT in default.project.json -> kein rojo-Neustart noetig);
  `CombatService.BroadcastExplosion(pos, radius)` -> `CameraShake.client`
  schuettelt abstandsabhaengig bei JEDER nahen Explosion (auch Granaten).
  Tuning: `EXPLOSION_TRAUMA` / `EXPLOSION_FALLOFF_MULT` in `CameraShake.client`.

## Status

Alles obige ist implementiert + `stylua`-parse-geprüft. **Smoke-Test in Studio
(2026-07-24, automatisiert) bestanden:** frischer Boot startet in der Lobby,
LoadoutMenu öffnet automatisch mit BEREIT-Button (0/1), Klassenwahl greift
sofort (Waffenleiste wechselte live Sentinel -> Pathfinder), Ready startet
Warmup -> Match, Menü schließt beim Rundenstart. Punkt-blank-Disc: Selbst-Splash
100 -> 71 HP + massiver Disc-Jump-Knockback. `SkiSlideHiss`/`SkiSlideRumble`
existieren in SoundService, `MatchReady`/`MovementStateSync`/`ExplosionFeedback`
in ReplicatedStorage. Kein einziger Script-Error im Output (inkl. Bot-Kämpfen).
**Noch offen (braucht Ohren/Gefühl):** Sound-Lautstärken, Shake-Stärke,
Ski-Sound-Charakter — über die MULT-/Target-Konstanten justieren.
Bekannte kleine Altlasten: "Hello world!"-Print von einem Stray-Script (nur in
der Place-Datei, nicht im Rojo-Tree) + orange Warnung
`GuiService.SelectedObject to invalid GuiObject` beim Menü-Auto-Open (kosmetisch).

## Harte Regel (hat uns eingeholt)

**NIEMALS den Charakter-Spawn-Fluss anfassen, um Spawn-Probleme zu lösen** —
insbesondere NICHT `Players.CharacterAutoLoads = false` / Charaktere gaten. Das
hat schon Modell-Laden + Jetpack zerschossen. Spawn-Probleme **nur über Position**
lösen (Teleport/Anheben), nie über das Laden. Immer **inkrementell + einzeln
getestet** arbeiten, kein Big-Bang.

## Nächste offene Schritte

**Sofort (Core-Polish):**
1. Combat-Feel + Spawn-Fix + Map-Voting + neues Tempo + Explosions-Wumms im Play-Modus testen und `MULT`s / Shake justieren.
2. Balance / Bot-KI-Feinschliff (playtest-getrieben).

**Danach (Monetarisierung-Track):**
4. Lobby-Grundgerüst (separate Place empfohlen) – Spieler treffen, Mode wählen, Queue.
5. Economy: Soft-Currency + Händler + Kisten (Robux + Soft).
6. Progression (XP/Rang auf Career-Score).
