# CTFGame

Roblox-CTF mit Skiing, Jetpack, neun Klassen, zwei Waffen-Slots, Fähigkeiten,
Granaten, Base-Systemen und serverautoritativem Match-/Schadenssystem.

## Start

```powershell
rojo serve default.project.json
```

Danach Roblox Studio mit `localhost:34872` verbinden und **Play (F5)** starten.
Alternativ startet ein Doppelklick auf `Start-CTFGame.cmd` Rojo dauerhaft im
Hintergrund; das Startfenster darf danach geschlossen werden.
Die große Karte wird beim Serverstart von `MapBuilder.server.lua` erzeugt; im
reinen Edit-Modus kann deshalb zunächst nur die Baseplate sichtbar sein.

## Steuerung

- `WASD`: bewegen
- `Space`: Skiing
- `Shift` oder rechte Maustaste: Jetpack
- Linksklick / `R2`: feuern
- `1` / `2` oder `R1`: Waffe wechseln
- `G` / `L1`: Granate
- `F` / `R3`: Nahkampf
- `Q` / `X`: Klassenfähigkeit
- `C` / `L2`: Präzisionsvisier (falls die Klasse eines besitzt)
- `V` oder mittlere Maustaste: Team-Ping
- `Z` / `Y`: getragene Flagge punten
- `L`: Loadout-Menü
- `M`: taktische Karte
- `Tab`: Scoreboard
- `F3`: Bewegungs-Debuganzeige

## Spinfusor-Asset

Der importierte Viewmodel-Pfad in Studio ist:

`ReplicatedStorage/WeaponAssets/Spinfusor/WP_Spinfusor_LP`

- Mesh: `rbxassetid://72177953697579`
- ColorMap: `rbxassetid://88661755368381`
- NormalMap: `rbxassetid://99243358537851`

Die Quelldateien liegen unter `export/` und `art_source/weapons/spinfusor/`.
Falls das Studio-Asset in einem frischen Place noch nicht vorhanden ist, nutzt
das Viewmodel automatisch eine prozedurale Ersatzwaffe, statt abzustürzen.

## Komplettes Art-Paket

Zusätzlich zum finalen Spinfusor enthält `art_source/` jetzt:

- 27 Blender-Waffenmodelle für alle neun Klassen (Disc, Automatik, Granate),
- 27 Roblox-fertige FBX-Exporte und 27 gerenderte Vorschauen,
- neun modulare Blender-Klassenrüstungen mit FBX und Vorschau,
- die komplette Titan-Alpine-Karte als Blender-Datei, FBX und vier Ansichten,
- automatische Triangle-/Asset-Berichte und reproduzierbare Build-Skripte.

Die vollständige Zuordnung steht in `art_source/ASSET_MANIFEST.md`. Bis neue
Mesh-Uploads Roblox-Asset-IDs besitzen, zeigt das Spiel alle Klassen bereits
mit performanter replizierter Rüstung und Third-Person-Waffenmodell.

Die genaue Studio-Importreihenfolge steht in `art_source/STUDIO_IMPORT.md`.
Nach dem Import unter `ReplicatedStorage/WeaponAssets` erkennt das Spiel alle
18 Klassenwaffen und neun Granaten automatisch und baut das Viewmodel beim
Klassenwechsel neu auf. Die vorhandene `WeaponAssets/Spinfusor`-Waffe bleibt
als kompatibler Fallback erhalten.

## Release-Prüfung

```powershell
rojo build default.project.json -o CTFGame.rbxlx
```

Für Karriere-Persistenz muss das veröffentlichte Erlebnis API-Services nutzen
dürfen. In Studio ist Persistenz absichtlich deaktiviert, damit Testwerte keine
Live-Daten überschreiben.
