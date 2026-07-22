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

`characters/class_armor_v01/CTFGame_ClassArmor_v01.blend` contains a modular
Light, Medium or Heavy armor set for every class. Each class has an FBX and
preview plus a validation entry in `class_armor_report.json`; every set is
below 10,000 triangles.

The game immediately displays lightweight server-replicated versions through
`CharacterPresentation.server.lua`. Imported meshes can replace those parts
later without changing gameplay or hitboxes.

## Rebuilding

Both packs are deterministic Blender scripts and can be regenerated headless:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python .\art_source\weapons\arsenal_v01\build_arsenal.py
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python .\art_source\characters\class_armor_v01\build_class_armor.py
```

FBX files must be uploaded/imported through Roblox Studio or Open Cloud before
they receive Roblox asset IDs. Local FBX paths cannot be loaded by a live
Roblox client. The procedural runtime presentation prevents that upload step
from blocking playtests.
