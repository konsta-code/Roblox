# CTFGame Art Source

All models in this directory are original project assets generated for CTFGame.
They do not copy or redistribute meshes or textures from Tribes: Ascend.

## Complete arsenal

`weapons/arsenal_v01/CTFGame_Arsenal_v01.blend` contains 27 editable models:

- nine class-specific disc/launcher weapons;
- nine class-specific automatic weapons;
- nine class-specific grenades.

Each model has a Roblox-ready FBX under `weapons/arsenal_v01/export/` and a
render under `weapons/arsenal_v01/previews/`. `arsenal_report.json` verifies
the object and triangle counts. Every asset is below 12,000 triangles.

## Character armor

`characters/class_armor_v01/CTFGame_ClassArmor_v01.blend` contains 18 modular
sets: a skeletal Cryo Revenant for every blue-team class and an organic Ember
Brood alien for every red-team class. Both factions keep readable Light,
Medium and Heavy silhouettes. Every set has its own FBX and validation entry
in `class_armor_report.json` and remains below 10,000 triangles.

The game immediately displays faction-matched, lightweight server-replicated
versions through `CharacterPresentation.server.lua`; Studio bots use the same
visual language. Imported meshes can later replace those parts without
changing gameplay, R15 animation or hitboxes.

## Titan Alpine environment

`environment/titan_alpine_v01/CTFGame_TitanAlpine_v01.blend` is the editable
environment source for the mirrored CTF arena. It includes seamless ski
ribbons, two flank lanes, highland rims, both citadels, glacier vaults, the
Titan reactor, canyon silhouettes and navigation beacons. The complete visual
pack is also exported as eight Roblox-ready FBX modules with local origin
markers and exact placement pivots in `roblox_import_manifest.json`.

The live game keeps `MapBuilder.server.lua` as the collision and gameplay-tag
source. `ImportedMapLoader.server.lua` automatically activates all eight
Blender modules after they are imported under `ReplicatedStorage/MapAssets`;
otherwise the native `MapArt.server.lua` fallback remains active.

## Rebuilding

All packs are deterministic Blender scripts. Rebuild everything with:

```powershell
powershell -ExecutionPolicy Bypass -File .\art_source\BUILD_ALL_BLENDER.ps1
```

Or run the generators individually:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python .\art_source\weapons\arsenal_v01\build_arsenal.py
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python .\art_source\characters\class_armor_v01\build_class_armor.py
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python .\art_source\environment\titan_alpine_v01\build_titan_alpine.py
```

FBX files must be uploaded/imported through Roblox Studio or Open Cloud before
they receive Roblox asset IDs. Local FBX paths cannot be loaded by a live
Roblox client. The procedural runtime presentation prevents that upload step
from blocking playtests.
