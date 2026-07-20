# Spinfusor MK-II — Asset & In-Game Integration

Pipeline output for the weapon model. Nothing here is live in the game until you do
the **Studio import** step below — Blender files and FBX/PNG on disk cannot enter a
Roblox place on their own.

## Files

| File | What it is |
|---|---|
| `WP_Spinfusor_Blockout_v01.blend` | Original blockout (3 788 tris) |
| `WP_Spinfusor_HP_v01.blend` | High-poly, all detail as geometry (7 608 tris) |
| `WP_Spinfusor_LP_v01.blend` | Low-poly game mesh (5 100 tris), UV-unwrapped |
| `export/WP_Spinfusor_HP.fbx` / `.obj` | High-poly export |
| `export/WP_Spinfusor_LP.fbx` | **Low-poly export — use this in Roblox** |
| `export/textures/SP_Color.png` | Baked colour (albedo × AO + emission) |
| `export/textures/SP_Normal.png` | Baked tangent normal map |
| `export/textures/SP_AO.png` | Ambient occlusion (already folded into Color) |
| `export/textures/SP_Emit.png` | Emission mask (orange energy areas) |
| `WeaponViewmodel.client.lua` | First-person viewmodel (with placeholder fallback) |

**HP vs LP:** the LP (5 100 tris) + normal map looks nearly identical to the HP and is
lighter. Use the LP FBX. The HP FBX is there if you ever want to re-bake at higher res.

## Step 1 — Import the mesh into Studio

1. Studio → **Home ▸ Import 3D** → pick `export/WP_Spinfusor_LP.fbx`.
2. In the import dialog leave "Use imported materials" off; accept. You get a `Model`
   (one or more `MeshPart`s).
3. It imports large (~5.5 studs) — that's fine, the viewmodel script rescales it.
4. Rename the Model to **`Spinfusor`**.

## Step 2 — Textures (SurfaceAppearance)

For each `MeshPart` under the model, add a **SurfaceAppearance** child and upload/assign:

- `ColorMap`  → `SP_Color.png`
- `NormalMap` → `SP_Normal.png`
- (MetalnessMap / RoughnessMap optional — leave blank for a uniform metal look, or set
  the MeshPart material to `Metal`.)

> Roblox `SurfaceAppearance` has **no emission channel**. The orange glow is baked into
> `SP_Color` as bright colour, which reads well. For an actual glow, add a thin `Neon`
> part (or a `Beam`/`Highlight`) over the energy core, or use `SP_Emit.png` as a mask on
> a Neon decal.

## Step 3 — Make it show in-game

The `WeaponViewmodel` client script (already wired into `default.project.json`) draws the
gun in first person. It looks for the mesh at:

```
ReplicatedStorage ▸ WeaponAssets ▸ Spinfusor      (preferred)
ReplicatedStorage ▸ Spinfusor                      (also accepted)
```

1. Create a `Folder` named **`WeaponAssets`** in `ReplicatedStorage`.
2. Drag your imported **`Spinfusor`** model into it.
3. Play. The viewmodel switches from the primitive placeholder to your mesh
   automatically (check the output for `viewmodel loaded (mesh)`).

**Until you import**, the script already shows a primitive placeholder Spinfusor with a
glowing core — so the weapon is visible immediately.

### Tuning (top of `WeaponViewmodel.client.lua`)

- `BASE_OFFSET` — gun position (right / down / forward from the camera).
- `MESH_ALIGN` — rotation for the imported mesh if its barrel faces the wrong way
  (start with the yaw; the mesh exports pointing down Blender −Y).
- `TARGET_LENGTH` — on-screen size in studs.

## Notes / possible follow-ups

- The bake used low samples; the orange core has slight speckle. Re-bake with more
  Cycles samples (`bake.py`, `scene.cycles.samples`) for a cleaner map if wanted.
- This is a **first-person** viewmodel only. If you want other players to see the weapon
  in the character's hand (third person), that's a separate weld-to-arm pass — ask and
  I'll add it.
- All Blender modifiers (Mirror / Bevel / Weighted Normal) are intact in the .blend
  files; the FBX/OBJ exports have them applied (baked into geometry).
