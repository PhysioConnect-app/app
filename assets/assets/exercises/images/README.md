# Exercise Images — Drop-in Convention

Place exercise photos in this folder named exactly as the `photo_filename` field in `exercises.json`.

Example: the entry with `"photo_filename": "cerv_01_cervical_flexion_extension.png"` expects:

```
assets/exercises/images/cerv_01_cervical_flexion_extension.png
```

**Supported formats:** PNG or JPG.

**No code changes needed.** The `ExerciseImage` widget resolves images by:
```
assets/exercises/images/{photo_filename}
```
Dropping a correctly-named file here makes it appear automatically in both the HEP builder and the patient view. Run `flutter pub get` once after adding files so the asset manifest is rebuilt.
