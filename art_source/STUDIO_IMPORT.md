# Roblox Studio asset import

The game runs without cloud meshes, but automatically replaces its procedural
fallbacks as soon as the Blender FBX assets are imported into the place.

## Weapons and grenades

1. In Studio, stop the playtest and open **3D Importer**.
2. Select all 27 FBX files from `art_source/weapons/arsenal_v01/export/`.
3. Keep the FBX filenames as the imported model names, leave **Add to
   Workspace** enabled and import all files.
4. Start **Play**. `ImportedAssetOrganizer` automatically moves recognized
   models into `ReplicatedStorage/WeaponAssets`. Switching class at an inventory
   station now rebuilds both first-person weapons immediately.

The runtime recursively searches `WeaponAssets`, so optional class subfolders
are allowed. These names must remain unchanged:

| Class | Disc / launcher | Automatic | Grenade |
| --- | --- | --- | --- |
| Pathfinder | `Pathfinder_LightSpinfusor` | `Pathfinder_LightAssaultRifle` | `Pathfinder_ImpactNitron` |
| Sentinel | `Sentinel_NovaBlaster` | `Sentinel_BXT1Rifle` | `Sentinel_GrenadeXL` |
| Infiltrator | `Infiltrator_StealthSpinfusor` | `Infiltrator_RhinoSMG` | `Infiltrator_StickyGrenade` |
| Soldier | `Soldier_Spinfusor` | `Soldier_AssaultRifle` | `Soldier_APGrenade` |
| Technician | `Technician_Thumper` | `Technician_TCN4SMG` | `Technician_TCNGrenade` |
| Raider | `Raider_ARXBuster` | `Raider_NJ5SMG` | `Raider_EMPGrenade` |
| Juggernaut | `Juggernaut_HeavySpinfusor` | `Juggernaut_X1LMG` | `Juggernaut_HeavyAPGrenade` |
| Brute | `Brute_BruteSpinfusor` | `Brute_AutoShotgun` | `Brute_FractalGrenade` |
| Doombringer | `Doombringer_SaberLauncher` | `Doombringer_Chaingun` | `Doombringer_FragGrenade` |

The previously imported `WeaponAssets/Spinfusor` remains a compatible fallback
for the disc slot until the class-specific models are uploaded.

## Character armor

The 18 FBX files in `art_source/characters/class_armor_v01/export/` contain a
blue Cryo-Revenant and red Ember-Brood variant for every class. The live game
currently uses the matching replicated, part-based presentation from
`CharacterPresentation.server.lua`; this preserves R15 animation and stable
hitboxes without requiring mesh IDs. Do not import these as a single static
character: they must be rigged/skinned to the R15 skeleton first.

## Environment

Import these eight files from
`art_source/environment/titan_alpine_v01/export/` together in the 3D Importer:

- `Titan_CoreRoute.fbx`
- `Titan_NorthFlank.fbx`
- `Titan_SouthFlank.fbx`
- `Titan_RedCitadel.fbx`
- `Titan_BlueCitadel.fbx`
- `Titan_WestGlacierVault.fbx`
- `Titan_EastGlacierVault.fbx`
- `Titan_CanyonBackdrop.fbx`

Keep their names unchanged and leave **Add to Workspace** enabled. On the next
**Play**, `ImportedMapLoader` detects the complete set directly in Workspace,
groups it under `Workspace/ImportedMap/TitanAlpine`, anchors every MeshPart,
disables mesh collision and puts all modules at the exact pivots stored in
`roblox_import_manifest.json`. Moving the models to
`ReplicatedStorage/MapAssets` beforehand is optional but keeps edit mode tidy.

Do not delete `MapBuilder.server.lua`: its invisible/simple ramps, stations,
generators, turrets, flags and tags remain gameplay-critical. If even one
Blender module is missing, the game intentionally keeps the complete native
art fallback instead of showing a half-imported map.

`CTFGame_TitanAlpine_v01.fbx` is the full-scene reference export and should
not be imported together with the eight segmented modules.

Local FBX files cannot be loaded by a running Roblox client. Studio creates the
cloud asset IDs during import; no IDs are hard-coded by this project.
